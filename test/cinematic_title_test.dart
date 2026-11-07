import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/exit_shot.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/music/accent_voice.dart';
import 'package:kumbia_kombat/music/rendered_music.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transition_conductor.dart';
import 'package:kumbia_kombat/music/transport.dart';

LevelRegistry _shipping() => LevelRegistry.parse(
  File('levels/index.json').readAsStringSync(),
  (id) => File('levels/$id.json').readAsStringSync(),
);

MusicScore _score(String id) => MusicScore.fromJson(
  jsonDecode(File('assets/music/scores/$id.json').readAsStringSync())
      as Map<String, dynamic>,
);

class _Backend implements MusicAudioBackend {
  @override
  double nowSeconds = 0;
  @override
  bool ready = true;
  final heard = <({ScoreNote note, double at})>[];
  @override
  void silence() {}
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) =>
      heard.add((note: note, at: atSeconds));
}

/// A level's exit from start to finish on the real conductor and transports,
/// pumped as the page pumps them. Returns what reached the backend.
({_Backend backend, double Function(double shotBeat) secondsAt}) _playExit(
  LevelStep step,
) {
  final shot = step.level.exitShot!;
  final backend = _Backend();
  final room = MusicTransport(
    _score(step.level.music.score),
    backend,
    loop: true,
    lookaheadSeconds: .3,
  )..start();
  while (backend.nowSeconds < .5) {
    backend.nowSeconds += .02;
    room.pump();
  }
  final conductor = TransitionConductor(backend, lookaheadSeconds: .6);
  final successScore = _score(step.level.music.successScore);
  final success = shot.mixCue(successScore, 0);
  late final double Function(double) secondsAt;
  late final double end;
  if (step.next != null) {
    final bridgeScore = _score(step.bridgeToNext!);
    final handoff = conductor.handoff(
      source: room,
      success: success,
      bridge: shot.mixCue(bridgeScore, successScore.lengthBeats),
      nextScore: _score(step.next!.music.score),
    );
    secondsAt = (beat) => beat < successScore.lengthBeats
        ? handoff.success.secondsAt(beat)
        : handoff.bridge.secondsAt(beat - successScore.lengthBeats);
    end = handoff.nextAtSeconds;
  } else {
    final finish = conductor.finish(source: room, success: success);
    secondsAt = finish.success.secondsAt;
    end = finish.endAtSeconds;
  }
  while (backend.nowSeconds < end) {
    backend.nowSeconds += .02;
    conductor.pump();
  }
  return (backend: backend, secondsAt: secondsAt);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final levels = _shipping();
  LevelStep step(String id) =>
      levels.campaign.firstWhere((step) => step.level.id == id);

  group('the two big words', () {
    test('each room has its own, from the party and music theme', () {
      expect(step('garden').level.copy.titleWords, ['MUCHO', 'MOJO']);
      expect(step('bar').level.copy.titleWords, ['MUY', 'SUAVE']);
      expect(step('pool-garden').level.copy.titleWords, ['QUÉ', 'FINO']);
    });

    test('they land on the contact, not before, and hold long enough', () {
      for (final id in ['garden', 'bar', 'pool-garden']) {
        final shot = step(id).level.exitShot!;
        expect(
          shot.titleAt(shot.contactBeat - .01, reducedMotion: false),
          isNull,
        );
        final hit = shot.titleAt(shot.contactBeat, reducedMotion: false)!;
        expect(hit.scale, greaterThan(1));
        expect(hit.opacity, 1);
        final settled = shot.titleAt(
          shot.contactBeat + 1,
          reducedMotion: false,
        )!;
        expect(settled.scale, 1);
        expect(settled.opacity, 1);
        // A fist lands in an instant, but two words take a moment to read.
        expect(shot.titleUntil - shot.contactBeat, greaterThanOrEqualTo(3));
        expect(shot.titleAt(shot.titleUntil, reducedMotion: false), isNull);
      }
    });

    test('calm camera shows them still, for the same beats', () {
      final shot = step('garden').level.exitShot!;
      for (
        var beat = shot.contactBeat;
        beat < shot.titleUntil;
        beat += .1
      ) {
        final pose = shot.titleAt(beat, reducedMotion: true)!;
        expect(pose.scale, 1);
        expect(pose.opacity, 1);
      }
      expect(
        shot.titleAt(shot.contactBeat - .1, reducedMotion: true),
        isNull,
      );
      expect(shot.titleAt(shot.titleUntil, reducedMotion: true), isNull);
    });

    testWidgets('the game font draws every title, É included', (tester) async {
      Future<Uint8List> ink(String text) async {
        final builder =
            ui.ParagraphBuilder(
                ui.ParagraphStyle(fontFamily: 'Kumbia', fontSize: 64),
              )
              ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFFFFFFF)))
              ..addText(text);
        final paragraph = builder.build()
          ..layout(const ui.ParagraphConstraints(width: 400));
        final recorder = ui.PictureRecorder();
        // Room above the text, so a clipped accent would show up as missing ink.
        ui.Canvas(recorder).drawParagraph(paragraph, const ui.Offset(10, 20));
        final image = await recorder.endRecording().toImage(420, 140);
        final bytes = await image.toByteData();
        return bytes!.buffer.asUint8List();
      }

      int firstInkRow(Uint8List rgba) {
        for (var i = 3; i < rgba.length; i += 4) {
          if (rgba[i] > 64) return (i ~/ 4) ~/ 420;
        }
        return -1;
      }

      // Real file and engine work, which the test's fake clock would never finish.
      await tester.runAsync(() async {
        final font = await File('assets/fonts/Cantarell-VF.otf').readAsBytes();
        await (FontLoader(
          'Kumbia',
        )..addFont(Future.value(ByteData.sublistView(font)))).load();
        final plain = await ink('E');
        final accented = await ink('É');
        final missing = await ink('\u{F0000}');
        expect(firstInkRow(plain), greaterThanOrEqualTo(0));
        // The accent is real ink, above the letter, and not the missing-glyph box.
        expect(firstInkRow(accented), lessThan(firstInkRow(plain) - 4));
        expect(accented, isNot(equals(missing)));
        for (final step in levels.campaign) {
          for (final rune in step.level.copy.clearedTitle.runes) {
            if (rune == 10) continue;
            final char = String.fromCharCode(rune);
            expect(await ink(char), isNot(equals(missing)), reason: char);
          }
        }
      });
    });
  });

  group('the accents', () {
    test('every cue reaches the backend at the device time of its beat', () {
      for (final id in ['garden', 'bar']) {
        final shot = step(id).level.exitShot!;
        final play = _playExit(step(id));
        for (final hit in shot.cue) {
          final arrivals = play.backend.heard.where(
            (entry) =>
                entry.note.track == hit.track &&
                entry.note.pitch == hit.pitch &&
                (entry.at - play.secondsAt(hit.beat)).abs() < 1e-6,
          );
          expect(arrivals, hasLength(1), reason: '$id beat ${hit.beat}');
        }
      }
    });

    test('the fist bump lands on contact, the gulp on its beats', () {
      final garden = step('garden').level.exitShot!;
      expect(garden.cue.single.track, 'bump');
      expect(garden.cue.single.beat, garden.contactBeat);

      final bar = step('bar').level.exitShot!;
      final glugs = bar.cue.where((hit) => hit.track == 'glug').toList();
      expect(bar.cue.first.track, 'clink');
      expect(bar.cue.first.beat, bar.contactBeat);
      expect(glugs.length, greaterThanOrEqualTo(3));
      for (final glug in glugs) {
        expect(glug.beat, greaterThan(bar.contactBeat));
        // Inside the pull: from taking the glass to the drained drawing.
        expect(glug.beat, lessThanOrEqualTo(bar.contactBeat + bar.impactBeats));
      }
    });

    test('a last level, with no bridge, still hears its cue', () {
      final last = levels.campaign.last;
      expect(last.next, isNull);
      final json =
          jsonDecode(File('levels/bar.json').readAsStringSync())
              as Map<String, dynamic>;
      final shot = LevelDefinition.fromJson(json).exitShot!;
      final early = ExitShot(
        plate: shot.plate,
        celebrateUntil: 1,
        walkFrom: 1,
        walkTo: 2,
        heroStep: shot.heroStep,
        closeupFrom: 3,
        contactBeat: 5,
        closeupTo: 7,
        contactPoint: shot.contactPoint,
        actors: shot.actors,
        cue: const [ExitShotCue(5, 'bump', 60, 127)],
      );
      final score = _score(last.level.music.successScore);
      final mixed = early.mixCue(score, 0);
      expect(mixed.notes.where((note) => note.track == 'bump'), hasLength(1));
    });

    test('a hit on a score\'s last moment is clipped, never refused', () {
      final shot = step('garden').level.exitShot!;
      final tight = ExitShot(
        plate: shot.plate,
        celebrateUntil: 1,
        walkFrom: 1,
        walkTo: 2,
        heroStep: shot.heroStep,
        closeupFrom: 3,
        contactBeat: 5,
        closeupTo: 7,
        contactPoint: shot.contactPoint,
        actors: shot.actors,
        cue: const [ExitShotCue(7.9, 'glug', 60, 127)],
      );
      final score = _score('garden_mojo_success');
      expect(score.lengthBeats, 8);
      final hit = tight
          .mixCue(score, 0)
          .notes
          .singleWhere((note) => note.track == 'glug');
      expect(hit.beat + hit.duration, lessThanOrEqualTo(score.lengthBeats));
    });

    test('the cue adds sounds and moves nothing in the music', () {
      final shot = step('bar').level.exitShot!;
      final score = _score('bar_to_pool');
      final mixed = shot.mixCue(score, 8);
      expect(mixed.tempos, score.tempos);
      expect(mixed.lengthBeats, score.lengthBeats);
      expect(mixed.notes.length, score.notes.length + shot.cue.length);
      final kept = mixed.notes.where((note) => !isAccentTrack(note.track));
      expect(
        kept.map((note) => (note.track, note.beat, note.pitch, note.velocity)),
        unorderedEquals(
          score.notes.map(
            (note) => (note.track, note.beat, note.pitch, note.velocity),
          ),
        ),
      );
    });

    test('every shipped shot fits inside the music that plays it', () {
      for (final step in levels.campaign) {
        final shot = step.level.exitShot;
        if (shot == null) continue;
        final success = _score(step.level.music.successScore).lengthBeats;
        final bridge = step.bridgeToNext == null
            ? 0.0
            : _score(step.bridgeToNext!).lengthBeats;
        final end = success + bridge;
        final id = step.level.id;
        // On a last level, music stops the beat clock: a close-up past it would
        // never close, and a hit past it would never sound.
        expect(shot.closeupTo, lessThanOrEqualTo(end), reason: id);
        expect(shot.titleUntil, lessThanOrEqualTo(end), reason: id);
        // The room dissolves as the bridge ends. It should clear the room, not a
        // close-up, so the wide shot comes back with beats to spare.
        if (step.bridgeToNext != null) {
          expect(shot.closeupTo, lessThanOrEqualTo(end - 4), reason: id);
        }
        for (final hit in shot.cue) {
          expect(hit.beat, lessThan(end), reason: '$id beat ${hit.beat}');
        }
      }
    });

    test('every shot fits inside the rendered music that plays it too', () {
      final manifest = RenderedManifest.fromJson(
        jsonDecode(
          File('assets/music/rendered/manifest.json').readAsStringSync(),
        ),
      );
      for (final step in levels.campaign) {
        final shot = step.level.exitShot;
        final music = manifest.levels[step.level.id];
        if (shot == null || music == null) continue;
        final id = step.level.id;
        final success = music.success?.lengthBeats ??
            _score(step.level.music.successScore).lengthBeats;
        final bridge = step.bridgeToNext == null
            ? 0.0
            : music.bridge?.lengthBeats ?? _score(step.bridgeToNext!).lengthBeats;
        final end = success + bridge;
        expect(shot.closeupTo, lessThanOrEqualTo(end), reason: id);
        expect(shot.titleUntil, lessThanOrEqualTo(end), reason: id);
        for (final hit in shot.cue) {
          expect(hit.beat, lessThan(end), reason: '$id beat ${hit.beat}');
        }
        if (step.next != null && music.bridge != null) {
          expect(music.bridgeTo, step.next!.id, reason: id);
        }
      }
    });

    test('they stand clear of the music they land on, without clipping', () {
      // What the synth gives a note before filters: enough for a comparison.
      double level(ScoreNote note) =>
          note.velocity / 127 * musicVoiceGain * musicMasterGain * 1.3;
      for (final id in ['garden', 'bar']) {
        final shot = step(id).level.exitShot!;
        final success = _score(step(id).level.music.successScore);
        final bridgeId = step(id).bridgeToNext;
        for (final hit in shot.cue.where((hit) => hit.beat == shot.contactBeat)) {
          // A last level has no bridge: its long success score plays under the hit.
          final inSuccess = hit.beat < success.lengthBeats;
          final score = inSuccess ? success : _score(bridgeId!);
          final beat = inSuccess ? hit.beat : hit.beat - success.lengthBeats;
          final under = score.notes
              .where((note) => note.beat == beat)
              .fold(0.0, (sum, note) => sum + level(note));
          expect(
            accentPeak(hit.track, hit.velocity),
            greaterThan(under * 2),
            reason: '$id ${hit.track} over $under',
          );
        }
      }
      for (final track in accentPatches.keys) {
        expect(accentPeak(track, 127), lessThan(.8), reason: track);
      }
    });

    test('a phone speaker can play every one of them', () {
      for (final entry in accentPatches.entries) {
        expect(
          entry.value.any(
            (layer) =>
                layer.noise || layer.fromHz >= 300 || layer.toHz >= 300,
          ),
          isTrue,
          reason: entry.key,
        );
      }
    });

    test('the glugs climb as the glass empties', () {
      final glugs = step('bar').level.exitShot!.cue
          .where((hit) => hit.track == 'glug')
          .map((hit) => accentTranspose(hit.pitch))
          .toList();
      for (var i = 1; i < glugs.length; i++) {
        expect(glugs[i], greaterThan(glugs[i - 1]));
      }
    });
  });
}
