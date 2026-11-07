import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/challenger_choreography.dart';
import 'package:kumbia_kombat/gameplay/crowd_interest.dart';
import 'package:kumbia_kombat/gameplay/cue_links.dart';
import 'package:kumbia_kombat/gameplay/cue_path.dart';
import 'package:kumbia_kombat/gameplay/dance_grammar.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/gameplay/party_autoplay.dart';
import 'package:kumbia_kombat/gameplay/party_sprites.dart';
import 'package:kumbia_kombat/gameplay/progression.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transport.dart';

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

MusicScore _score(String id) => MusicScore.fromJson(
  jsonDecode(File('assets/music/scores/$id.json').readAsStringSync())
      as Map<String, dynamic>,
);

LevelRegistry _levels() => LevelRegistry.parse(
  File('levels/index.json').readAsStringSync(),
  (id) => File('levels/$id.json').readAsStringSync(),
);

/// The tempo each game tier plays, as the owner ruled the ladders: the bar rises,
/// and the lawn goes mid, high, low. RENDER owns the mapping onto takes, so if
/// the merged mapping differs, this table and the charts must be looked at again.
const _tierBpm = {
  'pool-garden': [144.0, 144.0, 160.0, 160.0, 136.0],
  'bar': [100.0, 100.0, 106.0, 106.0, 112.0],
  'cool-crowd': [112.0, 112.0, 124.0, 124.0, 136.0],
  'billiards': [96.0, 96.0, 100.0, 100.0, 104.0],
  'salon': [108.0, 108.0, 116.0, 116.0, 124.0],
};

void main() {
  group('a chart with none of this plays as before', () {
    final garden = _levels().byId('garden').chart;
    test('every step is one note, on the plain limbs and offsets', () {
      for (var i = 0; i <= garden.variants.length; i++) {
        final played = garden.pattern(i);
        expect(played.limbs, i == 0 ? garden.limbs : garden.variants[i - 1]);
        expect(played.offsets, garden.offsets);
        expect(played.steps, played.limbs.length);
        expect(played.moves.every((m) => m == null), isTrue);
      }
    });
    test('the garden stays simple', () {
      expect(garden.richPatterns, isEmpty);
    });
  });

  group('validation', () {
    FightChart chart(List<ChartStep> steps) => FightChart(
      limbs: const [Limb.leftHand, Limb.rightHand],
      offsets: const [0, 1],
      callBeats: 4,
      richPatterns: {0: steps},
    );
    const one = ChartStep(0, Limb.leftHand);
    test('a good pattern passes', () {
      chart([
        const ChartStep(
          0,
          Limb.leftHand,
          move: RichMove.pair,
          partner: Limb.rightHand,
        ),
        const ChartStep(1, Limb.leftFoot, move: RichMove.doubleTap, gap: .75),
      ]).validate();
    });
    test('a pattern must keep its number of steps', () {
      expect(() => chart([one]).validate(), throwsArgumentError);
    });
    test('a pair needs a thumb on each side', () {
      expect(
        () => chart([
          const ChartStep(
            0,
            Limb.leftHand,
            move: RichMove.pair,
            partner: Limb.leftFoot,
          ),
          const ChartStep(1, Limb.rightHand),
        ]).validate(),
        throwsArgumentError,
      );
    });
    test('a split needs a thumb on each side, and a gap', () {
      for (final bad in [
        const ChartStep(
          0,
          Limb.leftHand,
          move: RichMove.split,
          partner: Limb.leftFoot,
          gap: .5,
        ),
        const ChartStep(
          0,
          Limb.leftHand,
          move: RichMove.split,
          partner: Limb.rightHand,
        ),
      ]) {
        expect(
          () => chart([bad, const ChartStep(1, Limb.rightHand)]).validate(),
          throwsArgumentError,
        );
      }
    });
    test('a step must start after the press before it', () {
      expect(
        () => chart([
          const ChartStep(0, Limb.leftHand, move: RichMove.doubleTap, gap: 1),
          const ChartStep(1, Limb.rightHand),
        ]).validate(),
        throwsArgumentError,
      );
    });
    test('a level file rejects a move it does not know', () {
      final raw =
          jsonDecode(File('levels/bar.json').readAsStringSync())
              as Map<String, dynamic>;
      final rich = (raw['chart'] as Map)['rich'] as Map;
      final patterns = rich['patterns'] as Map;
      ((patterns['1'] as List).first as Map)['move'] = 'triple';
      expect(() => LevelDefinition.fromJson(raw), throwsA(isA<LevelDataError>()));
    });
  });

  group('the real charts, at the tempos they play', () {
    final levels = _levels();
    for (final id in _tierBpm.keys) {
      test('$id holds every fairness limit, on musical subdivisions', () {
        final chart = levels.byId(id).chart;
        final rules = levels.byId(id).rules;
        for (var tier = 0; tier < 5; tier++) {
          final peaks = tier == 4 ? rules.finalChallenges : 1;
          for (var peak = 0; peak < peaks; peak++) {
            final index = chart.patternIndex(tier, peak);
            expect(
              chart.fairnessProblems(index, _tierBpm[id]![tier]),
              isEmpty,
              reason: '$id tier $tier',
            );
            for (final offset in chart.pattern(index).offsets) {
              expect((offset * 4) % 1, 0, reason: '$id tier $tier $offset');
            }
          }
        }
      });

      test('$id grows richer tier by tier, on the same eight steps', () {
        final chart = levels.byId(id).chart;
        final rules = levels.byId(id).rules;
        int rich(int tier) => chart.patternFor(tier, 0).richSteps;
        for (var tier = 1; tier < 5; tier++) {
          expect(rich(tier), greaterThanOrEqualTo(rich(tier - 1)));
          expect(chart.patternFor(tier, 0).steps, 8);
        }
        expect(rich(0), 0);
        expect(rich(4), greaterThan(rich(1)));
        // One dropped step in eight still clears the peak.
        expect(rules.requiredHits(8, atPeak: true), 7);
      });
    }

    test('the lawn is at its richest and busiest at its slowest tier', () {
      final chart = levels.byId('pool-garden').chart;
      for (var tier = 0; tier < 4; tier++) {
        expect(
          chart.patternFor(4, 0).limbs.length,
          greaterThan(chart.patternFor(tier, 0).limbs.length),
        );
      }
      for (var peak = 0; peak < 2; peak++) {
        final moves = chart.patternFor(4, peak).moves.toSet();
        expect(moves, containsAll(RichMove.values));
      }
    });
  });

  group('judging', () {
    late _Audio audio;
    late MusicTransport music;
    late GardenSession session;

    void until(double seconds) {
      while (audio.nowSeconds < seconds - 1e-6) {
        audio.nowSeconds = (audio.nowSeconds + .01).clamp(0, seconds);
        music.pump();
        session.advance();
      }
    }

    double response(int cycle, double offset) => music.secondsAt(
      session.chart.introBeats +
          cycle * session.chart.cycleBeats +
          session.chart.callBeats +
          offset,
    );

    const steps = [
      ChartStep(0, Limb.leftHand, move: RichMove.pair, partner: Limb.rightHand),
      ChartStep(1, Limb.leftFoot, move: RichMove.doubleTap, gap: .75),
      ChartStep(
        3,
        Limb.leftHand,
        move: RichMove.split,
        partner: Limb.rightHand,
        gap: .5,
      ),
      ChartStep(5, Limb.rightFoot),
    ];
    final chart = FightChart(
      limbs: const [
        Limb.leftHand,
        Limb.leftFoot,
        Limb.rightHand,
        Limb.rightFoot,
      ],
      offsets: const [0, 1, 3, 5],
      richPatterns: const {0: steps},
    );

    setUp(() {
      audio = _Audio();
      music = MusicTransport(_score('pool_swing'), audio, lookaheadSeconds: .3);
      session = GardenSession(
        music,
        audio,
        chart: chart,
        definition: fights.first,
      )..start();
    });

    test('a pair: two thumbs a few ms apart both count, and share a grade', () {
      // 70 ms late is perfect, 90 ms late is only good, 20 ms apart: one gesture.
      until(response(0, 0) + .07);
      expect(session.tap(Limb.leftHand).grade, TapGrade.perfect);
      until(response(0, 0) + .09);
      final second = session.tap(Limb.rightHand);
      expect(second.note, isNotNull);
      expect(second.grade, TapGrade.perfect);
      expect(session.perfects, 2);
      expect(session.richStepsCompleted, 1);
      expect(session.lastPairPartner, Limb.leftHand);
      expect(session.pizazz, richStepPizazz);
    });

    test('a pair outside the tolerance still counts, on its own grades', () {
      until(response(0, 0) - .1);
      expect(session.tap(Limb.leftHand).grade, TapGrade.good);
      until(response(0, 0) + .05);
      expect(session.tap(Limb.rightHand).grade, TapGrade.perfect);
      expect(session.perfects, 1);
      expect(session.richStepsCompleted, 1);
    });

    test('half of every richer step passes, and costs nothing', () {
      for (final (offset, limb) in [
        (0.0, Limb.leftHand),
        (1.0, Limb.leftFoot),
        (3.0, Limb.leftHand),
        (5.0, Limb.rightFoot),
      ]) {
        until(response(0, offset));
        session.tap(limb);
      }
      expect(session.combo, 4);
      until(response(0, 5) + .3);
      expect(session.combo, 4, reason: 'missed second presses break nothing');
      expect(session.passedPhrases, 1);
      expect(session.richStepsCompleted, 0);
      expect(session.pizazz, 0);
    });

    test('the second press alone also lands the step', () {
      until(response(0, 1.75));
      expect(session.tap(Limb.leftFoot).note, isNotNull);
      until(response(0, 2.5));
      expect(session.combo, 1);
    });

    test('a double: each press takes its own note, in order', () {
      until(response(0, 1));
      final first = session.tap(Limb.leftFoot);
      until(response(0, 1.75));
      final second = session.tap(Limb.leftFoot);
      expect(first.note, isNotNull);
      expect(second.note, isNotNull);
      expect(first.note!.id, isNot(second.note!.id));
      expect(first.grade, TapGrade.perfect);
      expect(second.grade, TapGrade.perfect);
      expect(session.richStepsCompleted, 1);
    });

    test('a whole step going by breaks the combo, as a plain note does', () {
      until(response(0, 0));
      session.tap(Limb.leftHand);
      expect(session.combo, 1);
      until(response(0, 1.75) + .25);
      expect(session.combo, 0);
    });

    test('a pause replay pays a finished step only once', () {
      until(response(0, 0));
      session.tap(Limb.leftHand);
      session.tap(Limb.rightHand);
      expect(session.pizazz, richStepPizazz);
      session.pause();
      session.resume();
      until(response(0, 0));
      session.tap(Limb.leftHand);
      session.tap(Limb.rightHand);
      expect(session.richStepsCompleted, 1);
      expect(session.pizazz, richStepPizazz);
    });

    test('cues say which step and move they belong to', () {
      until(response(0, 0) - .2);
      final pair = session.visibleCues
          .where((c) => !c.demo && c.step == 0)
          .toList();
      expect(pair.map((c) => c.limb), [Limb.leftHand, Limb.rightHand]);
      expect(pair.map((c) => c.index), [0, 1]);
      expect(pair.every((c) => c.move == RichMove.pair), isTrue);
      expect(pair.first.beat, pair.last.beat);
    });

    test('every press of a phrase lands: three steps finished, no retries', () {
      for (final (offset, limb) in [
        (0.0, Limb.leftHand),
        (0.0, Limb.rightHand),
        (1.0, Limb.leftFoot),
        (1.75, Limb.leftFoot),
        (3.0, Limb.leftHand),
        (3.5, Limb.rightHand),
        (5.0, Limb.rightFoot),
      ]) {
        until(response(0, offset));
        session.tap(limb);
      }
      until(response(0, 5) + .3);
      expect(session.passedPhrases, 1);
      expect(session.richStepsCompleted, 3);
    });
  });

  test('a finished richer step lifts a clean phrase, as an optional move does', () {
    // What the session reports: steps as notes, finished steps as gestures.
    const plain = PhraseReport(notes: 8, hits: 8, perfects: 0);
    const rich = PhraseReport(notes: 8, hits: 8, perfects: 0, gestures: 1);
    expect(CrowdEngagement.grade(true, plain), PhraseGrade.clean);
    expect(CrowdEngagement.grade(true, rich), PhraseGrade.excellent);
  });

  group('what a richer step looks like', () {
    Offset place(GardenCue cue) => switch (cue.id) {
      'a' => const Offset(100, 100),
      'b' => const Offset(300, 100),
      _ => const Offset(0, 0),
    };

    test('two cues of one step tie together, rim to rim', () {
      final links = cueLinks([
        _cue('a', 0, RichMove.pair),
        _cue('b', 0, RichMove.pair),
      ], place);
      expect(links, hasLength(1));
      final rim = cueExtent(.8) / 2;
      expect(links.single.from, Offset(100 + rim, 100));
      expect(links.single.to, Offset(300 - rim, 100));
      expect(links.single.move, RichMove.pair);
    });

    test('plain notes, lone cues, and a call and its answer never tie', () {
      expect(cueLinks([_cue('a', 0, null), _cue('b', 0, null)], place), isEmpty);
      expect(cueLinks([_cue('a', 0, RichMove.pair)], place), isEmpty);
      expect(
        cueLinks([
          _cue('a', 0, RichMove.pair, demo: true),
          _cue('b', 0, RichMove.pair),
        ], place),
        isEmpty,
      );
      expect(
        cueLinks([_cue('a', 0, RichMove.split), _cue('b', 1, RichMove.split)], place),
        isEmpty,
      );
    });

    test('touching cues draw no cord', () {
      expect(
        cueLinks([
          _cue('a', 0, RichMove.doubleTap),
          _cue('c', 0, RichMove.doubleTap),
        ], (cue) => cue.id == 'a' ? const Offset(100, 100) : const Offset(105, 100)),
        isEmpty,
      );
    });

    test('a split points at the cue that comes second', () {
      final link = cueLinks([
        _cue('a', 0, RichMove.split),
        _cue('b', 0, RichMove.split),
      ], place).single;
      final arrow = splitArrow(link);
      final mid = Offset.lerp(link.from, link.to, .5)!;
      expect(arrow.first.dx, greaterThan(mid.dx));
    });

    test('Mācron has a drawing for both hands, and for both feet', () {
      expect(heroFrameIds, contains(playerPairFrame(Limb.leftHand, Limb.rightHand)));
      expect(heroFrameIds, contains(playerPairFrame(Limb.leftFoot, Limb.rightFoot)));
      expect(playerPairFrame(Limb.leftHand, Limb.rightFoot), isNull);
      expect(playerPairFrame(Limb.leftHand, null), isNull);
      final pose = playerMovePose(
        limb: Limb.rightHand,
        acceptedBeat: 8,
        targetBeat: 8,
        beat: 8.05,
        partnerLimb: Limb.leftHand,
      );
      expect(pose.frameId, 'spin_front');
      expect(pose.phase, DanceMovePhase.accent);
    });

    group('the opponent shows it in the call', () {
      final grammar = DanceGrammar.fromJson(
        jsonDecode(
              File('assets/art/ensemble/choreography.json').readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      final phrase = ChallengerChoreography(
        limbs: const [
          Limb.leftHand,
          Limb.rightHand,
          Limb.leftFoot,
          Limb.leftFoot,
          Limb.leftHand,
          Limb.rightHand,
        ],
        offsets: const [0, 0, 2, 2.75, 4, 4.5],
      );
      String frame(double t) => grammar
          .dress(
            phrase.sample(beat: t, callStartBeat: 0),
            dancer: 'bartender',
            beat: t,
            callStartBeat: 0,
          )
          .frameId;

      test('a pair of hands is the clap, with its contact on the note', () {
        expect(phrase.sample(beat: .01, callStartBeat: 0).partnerLimb, Limb.leftHand);
        expect(frame(.01), 'clap_contact');
      });
      test('a double is the same accent twice', () {
        expect(frame(2.01), 'left_foot');
        expect(frame(2.76), 'left_foot');
      });
      test('a split is one side, then the other', () {
        expect(frame(4.01), 'left_hand');
        expect(frame(4.51), 'right_hand');
        expect(phrase.sample(beat: 4.51, callStartBeat: 0).partnerLimb, isNull);
      });
      test('every dancer has the clap', () {
        for (final dancer in ['gatekeeper', 'bartender', 'swing-a', 'swing-b']) {
          expect(grammar.framesFor(dancer), contains('clap_contact'));
        }
      });
    });

    test('on the lawn both dancers raise an arm for a pair', () {
      final duet = _levels().byId('pool-garden').stage.duet!;
      for (final onLeft in [true, false]) {
        expect(
          duet.pairFrame(
            onLeft: onLeft,
            limb: Limb.rightHand,
            partner: Limb.leftHand,
            phase: DanceMovePhase.accent,
            beat: 1,
          ),
          duet.pairFrames.arm,
        );
      }
    });
  });

  group('autoplay clears the real levels with the new moves', () {
    for (final id in ['pool-garden', 'bar', 'cool-crowd']) {
      for (final flawless in [true, false]) {
        test('$id, ${flawless ? 'flawless' : 'with errors'}', () {
          final level = _levels().byId(id);
          final audio = _Audio();
          final music = MusicTransport(
            _score(level.music.score),
            audio,
            loop: true,
            lookaheadSeconds: .3,
          );
          final session = level.newSession(music, audio)..start();
          final demo = PartyAutoplay(flawless: flawless)..enabled = true;
          final tiersSeen = <int>{};
          var richCues = 0;
          final seenCue = <String>{};
          final limit = 900.0;
          while (session.phase != GardenPhase.cleared &&
              audio.nowSeconds < limit) {
            audio.nowSeconds += .02;
            music.pump();
            session.advance();
            tiersSeen.add(session.progress.tier);
            for (final cue in session.visibleCues) {
              if (!cue.demo && cue.move != null && seenCue.add(cue.id)) {
                richCues++;
              }
            }
            demo.pump(session);
          }
          expect(session.phase, GardenPhase.cleared);
          expect(tiersSeen, contains(4));
          expect(richCues, greaterThan(0));
          expect(session.richStepsCompleted, greaterThan(0));
          expect(session.pizazz, greaterThan(0));
          if (flawless) {
            // Every phrase passed the first time: no retries on a flawless run.
            final rules = level.rules;
            expect(session.passedPhrases, 4 * rules.successesPerTier + rules.finalChallenges);
            // Every rich step of every phrase played landed both presses.
            var expected = 0;
            for (var tier = 0; tier < 4; tier++) {
              expected +=
                  rules.successesPerTier * level.chart.patternFor(tier, 0).richSteps;
            }
            for (var peak = 0; peak < rules.finalChallenges; peak++) {
              expected += level.chart.patternFor(4, peak).richSteps;
            }
            expect(session.richStepsCompleted, expected);
          }
        });
      }
    }
  });
}

GardenCue _cue(
  String id,
  int step,
  RichMove? move, {
  bool demo = false,
  Limb limb = Limb.leftHand,
  double beat = 0,
}) => GardenCue(
  id: id,
  limb: limb,
  beat: beat,
  progress: .8,
  demonstration: demo,
  step: step,
  move: move,
);
