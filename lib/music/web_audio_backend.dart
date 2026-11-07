// Web-only adapter. Import conditionally when integrating native targets.
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'accent_voice.dart';
import 'rendered_music.dart';
import 'score.dart';
import 'game_audio_contract.dart';

@JS('AudioContext')
extension type _Context._(JSObject _) implements JSObject {
  external factory _Context();
  external double get currentTime;
  external String get state;
  external double get sampleRate;
  external JSObject get destination;
  external JSPromise<JSAny?> resume();
  external JSPromise<JSAny?> close();
  external _Gain createGain();
  external _Oscillator createOscillator();
  external _Filter createBiquadFilter();
  external _Buffer createBuffer(int channels, int length, double sampleRate);
  external _BufferSource createBufferSource();
  external JSPromise<_Buffer> decodeAudioData(JSArrayBuffer data);
}

@JS('document.createElement')
external _AudioElement _createElement(String tag);

extension type _AudioElement._(JSObject _) implements JSObject {
  external String canPlayType(String type);
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
  external int get length;
  external int get numberOfChannels;
}

extension type _BufferSource._(JSObject _) implements _Source {
  external set buffer(_Buffer value);
  external set loop(bool value);
  external set loopStart(double value);
  external set loopEnd(double value);
  @JS('start')
  external void startAt(double time, double offset);
}

class _Voice {
  _Voice(this.source, this.envelope, this.nodes, this.end);
  final _Source source;
  final _Gain envelope;
  final List<_Node> nodes;
  final double end;
}

class _ClipVoice implements ClipVoice {
  _ClipVoice(this.owner, this.clip, this.source, this.trim, this.envelope);
  final WebAudioMusicBackend owner;
  final RenderedClip clip;
  final _BufferSource source;
  final _Gain trim;
  final _Gain envelope;

  @override
  void stopAt(double atSeconds, {double fadeSeconds = .01}) {
    if (!owner._clipVoices.contains(this)) return;
    final at = math.max(atSeconds, owner.nowSeconds);
    envelope.gain.cancelScheduledValues(at);
    envelope.gain.setValueAtTime(1, at);
    envelope.gain.linearRampToValueAtTime(.0001, at + fadeSeconds);
    source.stop(at + fadeSeconds + .005);
  }
}

/// A subtractive synth for the original scores, plus decoded buffers for the
/// rendered music. Percussion noise is generated in memory.
class WebAudioMusicBackend implements GameAudio, MusicFader, RenderedAudio {
  WebAudioMusicBackend({this.leadShape = 'triangle'});
  @override
  String leadShape;
  _Context? _context;
  /// The mixer's top, then the resume swell. Each bus sets its own level, so a
  /// slider and a fade can't overwrite one another.
  _Gain? _fader;
  _Gain? _masterBus;
  _Gain? _clipBus;
  _Gain? _master;
  _Gain? _accents;
  _Gain? _rewards;
  _Buffer? _noise;
  RenderedMix _mix = const RenderedMix();
  final List<_Voice> _voices = [];
  final _clipVoices = <_ClipVoice>{};
  final _compressed = <String, ({String format, Uint8List bytes})>{};
  final _decoded = <String, ({_Buffer buffer, String format})>{};
  final _decoding = SingleFlight();
  int stolenVoices = 0;
  bool _disposed = false;

  /// Where a resume's swell starts, as a share of full volume.
  static const _fadeFloor = .12;

  /// Invoke from a user gesture. Keep one AudioContext for this backend's life.
  @override
  Future<void> activate() async {
    if (_disposed) throw StateError('Audio backend has been disposed');
    if (_context == null) {
      final context = _context = _Context();
      _fader = context.createGain()..gain.value = 1;
      _fader!.connect(context.destination);
      _masterBus = context.createGain()..gain.value = dbToGain(_mix.masterDb);
      _masterBus!.connect(_fader!);
      _clipBus = context.createGain()..gain.value = dbToGain(_mix.musicDb);
      _clipBus!.connect(_masterBus!);
      // The synth keeps its own trim, as music, so a fallback follows the slider.
      _master = context.createGain()
        ..gain.value = musicMasterGain * dbToGain(_mix.musicDb);
      _master!.connect(_masterBus!);
      _accents = context.createGain()
        ..gain.value = accentBusGain * dbToGain(_mix.accentsDb);
      _accents!.connect(_masterBus!);
      _rewards = context.createGain()
        ..gain.value = musicMasterGain * dbToGain(_mix.rewardsDb);
      _rewards!.connect(_masterBus!);
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
    if (_disposed) throw StateError('Audio backend has been disposed');
  }

  @override
  double get nowSeconds => _context?.currentTime ?? 0;
  @override
  bool get ready => !_disposed && _context?.state == 'running';

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    silence();
    final context = _context;
    _context = null;
    for (final node in [
      _master,
      _accents,
      _rewards,
      _clipBus,
      _masterBus,
      _fader,
    ]) {
      node?.disconnect();
    }
    _master = _accents = _rewards = _clipBus = _masterBus = _fader = null;
    _noise = null;
    _decoded.clear();
    _compressed.clear();
    if (context != null) await context.close().toDart;
  }

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
    final accent = accentPatches[note.track];
    if (accent != null) {
      _playAccent(accent, note, math.max(atSeconds, nowSeconds));
      return;
    }
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
    var gain = note.velocity / 127 * musicVoiceGain;
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
    // A move's answer is a reward, with its own slider; the rest is the song.
    envelope.connect(note.track == 'answer' ? _rewards! : _master!);
    source.onended = (() {
      source.disconnect();
      filter.disconnect();
      envelope.disconnect();
    }).toJS;
    source.start(when);
    source.stop(end);
    _voices.add(_Voice(source, envelope, [source, filter, envelope], end));
  }

  /// A cinematic hit: never stolen by the song, and its length is its own, so
  /// the end of a score can't cut it short. Bounded by the shot's short cue list.
  void _playAccent(List<AccentLayer> layers, ScoreNote note, double when) {
    final context = _context!;
    final transpose = accentTranspose(note.pitch);
    for (final layer in layers) {
      late _Source source;
      if (layer.noise) {
        source = context.createBufferSource()
          ..buffer = _noise!
          ..loop = true;
      } else {
        final oscillator = context.createOscillator()..type = layer.shape;
        oscillator.frequency.setValueAtTime(layer.fromHz * transpose, when);
        oscillator.frequency.exponentialRampToValueAtTime(
          layer.toHz * transpose,
          when + layer.sweep,
        );
        source = oscillator;
      }
      final filter = context.createBiquadFilter()..type = layer.filter;
      filter.frequency.value = layer.filterHz;
      filter.Q.value = layer.q;
      final envelope = context.createGain();
      final gain = layer.gain * note.velocity / 127;
      final end = when + layer.seconds;
      envelope.gain.setValueAtTime(.0001, when);
      envelope.gain.linearRampToValueAtTime(gain, when + .002);
      envelope.gain.exponentialRampToValueAtTime(.0001, end);
      source.connect(filter);
      filter.connect(envelope);
      envelope.connect(_accents!);
      source.onended = (() {
        source.disconnect();
        filter.disconnect();
        envelope.disconnect();
      }).toJS;
      source.start(when);
      source.stop(end);
      _voices.add(_Voice(source, envelope, [source, filter, envelope], end));
    }
  }

  @override
  void fadeMusicIn({required double atSeconds, required double seconds}) {
    final gain = _fader?.gain;
    if (gain == null) return;
    final now = nowSeconds;
    final at = math.max(now, atSeconds);
    gain.cancelScheduledValues(now);
    gain.setValueAtTime(1, now);
    gain.setValueAtTime(_fadeFloor, at);
    gain.linearRampToValueAtTime(1, at + seconds);
  }

  // Rendered music.

  static const _formatTypes = {
    'opus': 'audio/ogg; codecs="opus"',
    'aac': 'audio/mp4; codecs="mp4a.40.2"',
  };
  static final _probe = _createElement('audio');
  static bool _canPlay(String format) {
    final type = _formatTypes[format];
    return type != null && _probe.canPlayType(type).isNotEmpty;
  }

  /// Formats this browser claims, in the manifest's order. A claim isn't proof,
  /// so a decode that fails moves on to the next.
  Iterable<MapEntry<String, String>> _candidates(RenderedClip clip) =>
      clip.files.entries.where((file) => _canPlay(file.key));

  @override
  Future<void> fetchClip(RenderedClip clip) async {
    if (_compressed.containsKey(clip.id) || _decoded.containsKey(clip.id)) {
      return;
    }
    final file = _candidates(clip).firstOrNull;
    if (file == null) throw StateError('No playable format for ${clip.id}');
    final data = await rootBundle.load(file.value);
    _compressed[clip.id] = (
      format: file.key,
      bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  @override
  Future<void> decodeClip(RenderedClip clip) {
    if (_decoded.containsKey(clip.id)) return Future.value();
    return _decoding.run(clip.id, () => _decode(clip));
  }

  Future<void> _decode(RenderedClip clip) async {
    final context = _context;
    if (context == null) throw StateError('Activate audio first');
    Object? failure;
    for (final file in _candidates(clip)) {
      try {
        var held = _compressed[clip.id];
        if (held == null || held.format != file.key) {
          final data = await rootBundle.load(file.value);
          held = (
            format: file.key,
            bytes: data.buffer.asUint8List(
              data.offsetInBytes,
              data.lengthInBytes,
            ),
          );
          _compressed[clip.id] = held;
        }
        // decodeAudioData takes its buffer away, so it gets a copy.
        final copy = Uint8List.fromList(held.bytes).buffer.toJS;
        final buffer = await context.decodeAudioData(copy).toDart;
        if (_disposed) return;
        _decoded[clip.id] = (buffer: buffer, format: file.key);
        return;
      } catch (error) {
        failure = error;
      }
    }
    throw StateError('Could not decode ${clip.id}: $failure');
  }

  @override
  void releaseClip(RenderedClip clip) {
    _decoded.remove(clip.id);
  }

  @override
  bool clipReady(RenderedClip clip) => _decoded.containsKey(clip.id);

  @override
  ClipVoice playClip(
    RenderedClip clip, {
    required double atSeconds,
    required double offsetSeconds,
    double fadeInSeconds = RenderedLevel.defaultJoinSeconds,
  }) {
    final context = _context!;
    final decoded = _decoded[clip.id]!;
    final at = math.max(atSeconds, nowSeconds);
    final shift = clip.decodeOffsetSeconds(decoded.format);
    final source = context.createBufferSource()..buffer = decoded.buffer;
    if (clip.loops) {
      source
        ..loop = true
        ..loopStart = clip.startSeconds + shift
        ..loopEnd = clip.loopEndSeconds! + shift;
    }
    final trim = context.createGain()..gain.value = dbToGain(clip.gainDb);
    final envelope = context.createGain();
    if (fadeInSeconds > 0) {
      envelope.gain.setValueAtTime(.0001, at);
      envelope.gain.linearRampToValueAtTime(1, at + fadeInSeconds);
    }
    source.connect(trim);
    trim.connect(envelope);
    envelope.connect(_clipBus!);
    final voice = _ClipVoice(this, clip, source, trim, envelope);
    _clipVoices.add(voice);
    source.onended = (() {
      _clipVoices.remove(voice);
      source.disconnect();
      trim.disconnect();
      envelope.disconnect();
    }).toJS;
    source.startAt(at, offsetSeconds + shift);
    final end = clip.endSeconds;
    if (!clip.loops && end != null) {
      voice.stopAt(at + end - offsetSeconds, fadeSeconds: .02);
    }
    return voice;
  }

  @override
  void setMix(RenderedMix mix) {
    _mix = mix;
    final context = _context;
    if (context == null) return;
    final now = context.currentTime;
    for (final (bus, gain) in [
      (_masterBus, dbToGain(mix.masterDb)),
      (_clipBus, dbToGain(mix.musicDb)),
      (_master, musicMasterGain * dbToGain(mix.musicDb)),
      (_accents, accentBusGain * dbToGain(mix.accentsDb)),
      (_rewards, musicMasterGain * dbToGain(mix.rewardsDb)),
    ]) {
      bus?.gain.setTargetAtTime(gain, now, .02);
    }
  }

  @override
  void clipGainChanged(RenderedClip clip) {
    final now = nowSeconds;
    for (final voice in _clipVoices) {
      if (voice.clip.id == clip.id) {
        voice.trim.gain.setTargetAtTime(dbToGain(clip.gainDb), now, .02);
      }
    }
  }

  @override
  int get decodedBytes => _decoded.values.fold(
    0,
    (sum, held) =>
        sum + held.buffer.length * held.buffer.numberOfChannels * 4,
  );

  @override
  int get compressedBytes =>
      _compressed.values.fold(0, (sum, held) => sum + held.bytes.length);

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
    for (final voice in _clipVoices.toList()) {
      voice.envelope.gain.cancelScheduledValues(now);
      voice.envelope.gain.setTargetAtTime(.0001, now, .0015);
      voice.source.stop(now + .008);
    }
    _clipVoices.clear();
  }
}
