// Standalone CLI compilation deliberately uses relative imports and no Flutter dependencies.
// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import '../../lib/music/score.dart';
import '../../lib/music/transport.dart';
import '../../lib/music/voice_recipes.dart';
import '../../lib/music/web_audio_backend.dart';

@JSExport()
class MusicPreview {
  final backend = WebAudioMusicBackend();
  MusicTransport? transport;
  Map<String, dynamic>? data;
  String message = 'Choose a score and press Play.';
  int _generation = 0;
  bool _starting = false;

  String get status => _starting
      ? 'Starting audio…'
      : '$message | ${transport?.state.name ?? 'stopped'} | '
            'beat ${(transport?.positionBeats ?? 0).toStringAsFixed(1)} | '
            'tier ${transport?.currentTier ?? 0}';
  void load(String json) {
    _generation++;
    _starting = false;
    transport?.stop();
    data = jsonDecode(json) as Map<String, dynamic>;
    backend.leadShape = switch (data!['id']) {
      'garden_mojo' => 'sawtooth',
      'crowd_duende' => 'sine',
      'restroom_nerve' => 'square',
      'vip_presence' => 'sawtooth',
      _ => 'triangle',
    };
    transport = MusicTransport(MusicScore.fromJson(data!), backend);
    message = data!['title'] as String;
  }

  void play() {
    final generation = _generation;
    _starting = true;
    backend
        .activate()
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw StateError(
              'Audio device unavailable. Enable browser audio and press Play again.',
            );
          },
        )
        .then((_) {
          _starting = false;
          if (generation != _generation) return;
          if (transport?.state == TransportState.paused) {
            final bpm = transport!.score.tempos[transport!.currentTier];
            transport!.resume(leadSeconds: 4 * 60 / bpm);
            message = 'One bar to breathe; then the phrase resumes';
          } else {
            transport?.start();
          }
        })
        .catchError((Object error) {
          _starting = false;
          message = 'Audio could not start: $error';
        });
  }

  void pump() {
    transport?.pump();
  }

  void pause() {
    transport?.pause();
  }

  void stop() {
    _generation++;
    transport?.stop();
  }

  void tier(int value) {
    if (transport?.state != TransportState.playing) return;
    final boundary = transport!.requestTier(value);
    message = 'Tier $value enters at beat ${boundary.toInt()}';
  }

  /// Comma-separated recipe voices, for the audition buttons.
  String get voiceNames => voiceRecipes.keys.join(',');

  /// A short figure on one recipe voice, independent of the loaded score.
  void audition(String voice) {
    backend.activate().then((_) {
      final bass = voice == 'subDrone' || voice == 'chugGuitar';
      final root = bass ? 40 : 60;
      final start = backend.nowSeconds + .05;
      const steps = [0, 4, 7, 12];
      for (var i = 0; i < steps.length; i++) {
        backend.schedule(
          ScoreNote(
            track: 'audition',
            beat: 0,
            pitch: root + steps[i],
            duration: 1,
            velocity: 90,
            voice: voice,
          ),
          start + i * .32,
          .3,
        );
      }
      message = 'Voice: $voice';
    });
  }

  void flourish(String id) {
    if (transport?.state != TransportState.playing || !backend.ready) return;
    if ((data!['adornments'] as List).isEmpty) return;
    final adornment = (data!['adornments'] as List).firstWhere(
      (a) => a['id'] == id,
    );
    final beat = (transport!.positionBeats * 4 + 1).ceil() / 4;
    for (final event in adornment['events'] as List) {
      final note = ScoreNote.fromJson(event as Map<String, dynamic>);
      final when = transport!.secondsAt(beat + note.beat);
      final end = transport!.secondsAt(beat + note.beat + note.duration);
      backend.schedule(note, when, end - when);
    }
  }
}

void main() {
  globalContext.setProperty(
    'kumbiaMusic'.toJS,
    createJSInteropWrapper(MusicPreview()),
  );
}
