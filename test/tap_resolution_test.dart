import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/cue_path.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/gameplay/party_autoplay.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';
import 'package:kumbia_kombat/gameplay/tap_resolution.dart';
import 'package:kumbia_kombat/gameplay/thumb_layout.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transport.dart';

const _screens = [
  (320.0, 454.0),
  (320.0, 568.0),
  (360.0, 640.0),
  (375.0, 667.0),
  (390.0, 664.0),
  (390.0, 844.0),
  (412.0, 915.0),
  (430.0, 932.0),
  (500.0, 700.0),
  (500.0, 1000.0),
];

/// The tallest notch a supported phone reports, for the header's position.
const _worstTopPadding = 59.0;

class _Audio implements MusicAudioBackend {
  @override
  double nowSeconds = 0;
  @override
  bool ready = true;
  @override
  void silence() {}
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {}
}

List<LevelDefinition> _levels() => LevelRegistry.parse(
  File('levels/index.json').readAsStringSync(),
  (id) => File('levels/$id.json').readAsStringSync(),
).levels.toList();

MusicTransport _music(LevelDefinition level, _Audio audio) => MusicTransport(
  MusicScore.fromJson(
    jsonDecode(
      File('assets/music/scores/${level.music.score}.json').readAsStringSync(),
    ) as Map<String, dynamic>,
  ),
  audio,
  loop: true,
  lookaheadSeconds: .3,
);

/// Plays a whole room with the demo, every tap made by touching the ring through
/// the real resolver. Returns the notes it saw, and how the room ended.
({GardenPhase phase, Map<String, GardenCue> notes}) _clearByTouch(
  LevelDefinition level, {
  required (double, double) screen,
  required bool reducedMotion,
}) {
  final (width, height) = screen;
  final audio = _Audio();
  final session = level.newSession(_music(level, audio), audio)..start();
  final demo = PartyAutoplay()..enabled = true;
  final notes = <String, GardenCue>{};

  NotePoint landingOf(GardenCue cue) => cuePath(
    limb: cue.limb,
    beat: cue.beat,
    id: cue.id,
    width: width,
    height: height,
    reducedMotion: reducedMotion,
  ).landing;

  TapResult touch(Limb limb) {
    final nowMs = (audio.nowSeconds * 1000).round();
    final candidates = openTapCandidates(
      cues: session.visibleCues,
      nowMs: nowMs,
      secondsAt: session.transport.secondsAt,
      landing: landingOf,
    );
    final own = candidates
        .where((c) => c.limb == limb)
        .reduce((a, b) => a.timingOffMs <= b.timingOffMs ? a : b);
    final hit = resolveTap(
      x: own.landing.x,
      y: own.landing.y,
      radius: tapAreaRadius(width),
      candidates: candidates,
    );
    expect(hit?.limb, limb, reason: '${level.id} $screen');
    return session.tap(hit!.limb);
  }

  final deadline = 400.0;
  while (session.phase != GardenPhase.cleared && audio.nowSeconds < deadline) {
    audio.nowSeconds += .02;
    session.transport.pump();
    session.advance();
    for (final cue in session.visibleCues) {
      if (!cue.demo) notes['${cue.id}@${cue.beat}'] = cue;
    }
    demo.pump(session, onTap: touch);
  }
  return (phase: session.phase, notes: notes);
}

void main() {
  const ringA = TapCandidate(Limb.leftHand, NotePoint(100, 600), 40);
  const ringB = TapCandidate(Limb.rightHand, NotePoint(220, 600), 10);

  group('which ring a tap belongs to', () {
    Limb? at(double x, double y, [List<TapCandidate>? rings]) => resolveTap(
      x: x,
      y: y,
      radius: 72,
      candidates: rings ?? const [ringA, ringB],
    )?.limb;

    test('the nearest ring wins, not the one closer in time', () {
      expect(at(110, 600), Limb.leftHand);
      expect(at(210, 600), Limb.rightHand);
    });

    test('areas overlap, and the overlap splits at the midpoint', () {
      // 160 is exactly between them, and in both areas.
      expect(at(159, 600), Limb.leftHand);
      expect(at(161, 600), Limb.rightHand);
    });

    test('equal distances go to the note closer in time', () {
      expect(at(160, 600), Limb.rightHand);
      expect(
        at(160, 600, const [
          TapCandidate(Limb.leftHand, NotePoint(100, 600), 5),
          ringB,
        ]),
        Limb.leftHand,
      );
    });

    test('the edge of the area counts, and past it nothing does', () {
      expect(at(100 - 72, 600), Limb.leftHand);
      expect(at(100 - 72.01, 600), isNull);
      expect(at(160, 300), isNull);
    });

    test('no open note, or a bad point, is a stray tap', () {
      expect(at(100, 600, const []), isNull);
      expect(at(double.nan, 600), isNull);
      expect(at(100, double.infinity), isNull);
    });
  });

  group('which notes are open', () {
    GardenCue cue(String id, double beat, {bool demo = false}) => GardenCue(
      id: id,
      limb: Limb.leftHand,
      beat: beat,
      progress: 1,
      demonstration: demo,
    );
    // One beat is one second here.
    List<TapCandidate> open(List<GardenCue> cues, int nowMs) =>
        openTapCandidates(
          cues: cues,
          nowMs: nowMs,
          secondsAt: (beat) => beat,
          landing: (_) => const NotePoint(0, 0),
        );

    test('exactly the judge\'s Good window, either way', () {
      final note = [cue('a', 10)];
      expect(open(note, 10000 - RhythmJudge.goodWindowMs), hasLength(1));
      expect(open(note, 10000 - RhythmJudge.goodWindowMs - 1), isEmpty);
      expect(open(note, 10000 + RhythmJudge.goodWindowMs), hasLength(1));
      expect(open(note, 10000 + RhythmJudge.goodWindowMs + 1), isEmpty);
      expect(open(note, 10050).single.timingOffMs, 50);
    });

    test('a demonstration is never a tap target', () {
      expect(open([cue('a', 10, demo: true)], 10000), isEmpty);
    });
  });

  test('the radius has a floor for small phones, and grows with the pad', () {
    // Well above the 48 logical pixels across of published touch guidance.
    expect(tapAreaRadiusFloor * 2, greaterThanOrEqualTo(3 * 48));
    expect(tapAreaRadius(320), tapAreaRadiusFloor);
    expect(tapAreaRadius(360), tapAreaRadiusFloor);
    expect(tapAreaRadius(390), closeTo(78, 1e-9));
    expect(tapAreaRadius(500), closeTo(100, 1e-9));
    // A thumb on a limb's resting spot always reaches the ring, however it strays.
    for (final (w, h) in _screens) {
      final reach = math.sqrt(
        math.pow(cueLandingJitterX * w, 2) + math.pow(cueLandingJitterY * h, 2),
      );
      expect(reach, lessThan(tapAreaRadius(w) - cueRingRadius));
      expect(tapAreaRadius(w), greaterThan(cueRingRadius * 2));
    }
  });

  group('every real chart, on every phone', () {
    for (final level in _levels()) {
      test('${level.id}: the demo clears it by touching the rings', () {
        for (final reduced in [false, true]) {
          for (final screen in [
            (320.0, 454.0),
            (390.0, 844.0),
            (500.0, 700.0),
          ]) {
            final run = _clearByTouch(
              level,
              screen: screen,
              reducedMotion: reduced,
            );
            expect(run.phase, GardenPhase.cleared, reason: '$screen $reduced');
          }
        }
      });

      test('${level.id}: every landing\'s area is reachable and unblocked', () {
        final notes = _clearByTouch(
          level,
          screen: (390, 844),
          reducedMotion: false,
        ).notes.values;
        expect(notes, isNotEmpty);
        for (final (w, h) in _screens) {
          final radius = tapAreaRadius(w);
          // The header's two 48 buttons, at the right, under any notch.
          final buttonsLeft = w - 14 - 96;
          final buttonsBottom = _worstTopPadding + 14 + 48;
          for (final reduced in [false, true]) {
            for (final cue in notes) {
              final at = cuePath(
                limb: cue.limb,
                beat: cue.beat,
                id: cue.id,
                width: w,
                height: h,
                reducedMotion: reduced,
              ).landing;
              final where = '${level.id} $w x $h ${cue.limb} ${cue.beat}';
              // The ring is whole on screen, and on its own side of the pad.
              expect(
                at.x - cueRingRadius,
                greaterThanOrEqualTo(0),
                reason: where,
              );
              expect(at.x + cueRingRadius, lessThanOrEqualTo(w), reason: where);
              expect(at.y + cueRingRadius, lessThanOrEqualTo(h), reason: where);
              expect(thumbLimbAt(at.x / w, at.y / h), cue.limb, reason: where);
              // The buttons can't take any of the area's touches.
              final nearestX = at.x.clamp(buttonsLeft, w).toDouble();
              final nearestY = math.min(at.y, buttonsBottom);
              final clear = math.sqrt(
                math.pow(at.x - nearestX, 2) + math.pow(at.y - nearestY, 2),
              );
              expect(clear, greaterThan(radius), reason: where);
              // Most of the area is on the glass.
              var inside = 0;
              var total = 0;
              for (var dx = -radius; dx <= radius; dx += radius / 8) {
                for (var dy = -radius; dy <= radius; dy += radius / 8) {
                  if (dx * dx + dy * dy > radius * radius) continue;
                  total++;
                  final x = at.x + dx;
                  final y = at.y + dy;
                  if (x >= 0 && x <= w && y >= 0 && y <= h) inside++;
                }
              }
              expect(inside / total, greaterThan(.6), reason: where);
            }
          }
        }
      });
    }

    test('reduced motion lands every note on its home, and it still resolves', () {
      for (final (w, h) in _screens) {
        for (final limb in Limb.values) {
          final path = cuePath(
            limb: limb,
            beat: 12.5,
            id: 'x:0:0:0:3',
            width: w,
            height: h,
            reducedMotion: true,
          );
          final home = cueHome(limb, width: w, height: h);
          expect(path.landing.x, home.x);
          expect(path.landing.y, home.y);
          // All four rings open at once: each home still answers for its limb.
          final rings = [
            for (final other in Limb.values)
              TapCandidate(other, cueHome(other, width: w, height: h), 0),
          ];
          expect(
            resolveTap(
              x: home.x,
              y: home.y,
              radius: tapAreaRadius(w),
              candidates: rings,
            )?.limb,
            limb,
          );
        }
      }
    });
  });
}
