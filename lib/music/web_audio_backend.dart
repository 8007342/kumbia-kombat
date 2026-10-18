// Web-only adapter. Import conditionally when integrating native targets.
import 'dart:js_interop';
import 'dart:math' as math;
import 'score.dart';
import 'transport.dart';

@JS('AudioContext')
extension type _Context._(JSObject _) implements JSObject {
  external factory _Context();
  external double get currentTime;
  external String get state;
  external double get sampleRate;
  external JSObject get destination;
  external JSPromise<JSAny?> resume();
  external _Gain createGain();
  external _Oscillator createOscillator();
  external _Filter createBiquadFilter();
  external _Buffer createBuffer(int channels, int length, double sampleRate);
  external _BufferSource createBufferSource();
}

extension type _Param._(JSObject _) implements JSObject {
  external set value(double value);
  external void setValueAtTime(double value, double time);
  external void exponentialRampToValueAtTime(double value, double time);
  external void linearRampToValueAtTime(double value, double time);
  external void cancelScheduledValues(double time);
  external void setTargetAtTime(double target, double time, double constant);
}

extension type _Node._(JSObject _) implements JSObject {
  external void connect(JSObject destination);
  external void disconnect();
}

extension type _Gain._(JSObject _) implements _Node {
  external _Param get gain;
}

extension type _Filter._(JSObject _) implements _Node {
  external set type(String value);
  external _Param get frequency;
  external _Param get Q;
}

extension type _Source._(JSObject _) implements _Node {
  external set onended(JSFunction callback);
  external void start(double time);
  external void stop(double time);
}

extension type _Oscillator._(JSObject _) implements _Source {
  external set type(String value);
  external _Param get frequency;
}

extension type _Buffer._(JSObject _) implements JSObject {
  external JSFloat32Array getChannelData(int channel);
}

extension type _BufferSource._(JSObject _) implements _Source {
  external set buffer(_Buffer value);
  external set loop(bool value);
}

class _Voice {
  _Voice(this.source, this.envelope, this.nodes, this.end);
  final _Source source;
  final _Gain envelope;
  final List<_Node> nodes;
  final double end;
}

/// Sample-free subtractive synth for the original scores. Percussion noise is
/// generated in memory; no recorded stems or third-party soundfonts are loaded.
class WebAudioMusicBackend implements MusicAudioBackend {
  WebAudioMusicBackend({this.leadShape = 'triangle'});
  String leadShape;
  _Context? _context;
  _Gain? _master;
  _Buffer? _noise;
  final List<_Voice> _voices = [];
  int stolenVoices = 0;

  /// Invoke from a user gesture. Keep one AudioContext for this backend's life.
  Future<void> activate() async {
    if (_context == null) {
      final context = _context = _Context();
      _master = context.createGain()..gain.value = .32;
      _master!.connect(context.destination);
      final noise = _noise = context.createBuffer(
        1,
        context.sampleRate.toInt(),
        context.sampleRate,
      );
      final samples = noise.getChannelData(0).toDart;
      var seed = 7301;
      for (var i = 0; i < samples.length; i++) {
        seed = (seed * 1664525 + 1013904223) & 0xffffffff;
        samples[i] = (seed / 0xffffffff) * 2 - 1;
      }
    }
    await _context!.resume().toDart;
  }

  @override
  double get nowSeconds => _context?.currentTime ?? 0;
  @override
  bool get ready => _context?.state == 'running';

  void _collect() {
    final expired = _voices.where((voice) => voice.end < nowSeconds).toList();
    for (final voice in expired) {
      for (final node in voice.nodes) {
        node.disconnect();
      }
      _voices.remove(voice);
    }
  }

  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {
    if (!ready) throw StateError('Activate audio from a user gesture first');
    _collect();
    if (_voices.length >= 96) {
      stolenVoices++;
      return;
    }
    final context = _context!;
    final when = math.max(atSeconds, nowSeconds);
    final envelope = context.createGain();
    final filter = context.createBiquadFilter()..type = 'lowpass';
    filter.Q.value = .7;
    final drum = note.track == 'pulse';
    final noisy = drum && [38, 73, 75].contains(note.pitch);
    late _Source source;
    var length = math.max(.025, durationSeconds);
    var gain = note.velocity / 127 * .18;
    if (noisy) {
      final noise = context.createBufferSource()
        ..buffer = _noise!
        ..loop = true;
      source = noise;
      filter.type = 'bandpass';
      filter.frequency.value = note.pitch == 38 ? 1500 : 5200;
      filter.Q.value = note.pitch == 73 ? 2 : .6;
      gain *= note.pitch == 73 ? .45 : .7;
      length = math.min(length, .13);
    } else {
      final oscillator = context.createOscillator();
      source = oscillator;
      oscillator.type = drum
          ? 'sine'
          : switch (note.track) {
              'bass' => 'triangle',
              'guitar' => 'sawtooth',
              'brass' => 'sawtooth',
              'lead' => leadShape,
              _ => 'sine',
            };
      final frequency = drum
          ? (note.pitch == 36 ? 110.0 : 160 + (note.pitch - 60) * 24.0)
          : 440 * math.pow(2, (note.pitch - 69) / 12).toDouble();
      oscillator.frequency.setValueAtTime(frequency, when);
      if (drum) {
        oscillator.frequency.exponentialRampToValueAtTime(
          frequency * .45,
          when + .09,
        );
      }
      filter.frequency.value = switch (note.track) {
        'bass' => 700,
        'guitar' => 1700,
        'brass' => 2200,
        _ => 4200,
      };
      if (note.track == 'bass') gain *= 1.3;
      if (note.track == 'guitar' || note.track == 'brass') gain *= .65;
    }
    final end = when + length + .04;
    envelope.gain.setValueAtTime(.0001, when);
    envelope.gain.linearRampToValueAtTime(gain, when + .006);
    envelope.gain.exponentialRampToValueAtTime(
      math.max(.0002, gain * .35),
      when + length,
    );
    envelope.gain.exponentialRampToValueAtTime(.0001, end);
    source.connect(filter);
    filter.connect(envelope);
    envelope.connect(_master!);
    source.onended = (() {
      source.disconnect();
      filter.disconnect();
      envelope.disconnect();
    }).toJS;
    source.start(when);
    source.stop(end);
    _voices.add(_Voice(source, envelope, [source, filter, envelope], end));
  }

  @override
  void silence() {
    if (_context == null) return;
    final now = nowSeconds;
    for (final voice in _voices) {
      voice.envelope.gain.cancelScheduledValues(now);
      voice.envelope.gain.setTargetAtTime(.0001, now, .0015);
      voice.source.stop(now + .005);
      // onended disconnects the graph after the clickless release.
    }
    _voices.clear();
  }
}
