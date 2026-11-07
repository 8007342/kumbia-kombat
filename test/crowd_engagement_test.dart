import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/crowd_interest.dart';
import 'package:kumbia_kombat/gameplay/ensemble_sprites.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/gameplay/party_autoplay.dart';
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
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {}
  @override
  void silence() {}
}

/// Decides each note of each phrase. A null offset drops the note.
class _Player {
  const _Player(this.offsetMs, {this.gesture = false});
  final int? Function(int phrase, int note, GardenSession session) offsetMs;
  final bool gesture;
}

/// Steady lag: every note hit, none PERFECT, spread zero.
const _lagged = 110;

final _flawlessTaps = _Player((_, _, _) => 0);
final _laggedClean = _Player((_, _, _) => _lagged);
final _laggedWithFlicks = _Player((_, _, _) => _lagged, gesture: true);
final _flawlessWithFlicks = _Player((_, _, _) => 0, gesture: true);

/// All notes hit, timing all over the place.
final _sloppy = _Player((_, note, _) => note.isEven ? 150 : -150);

/// Scrapes through: drops exactly what the phrase allows, loosely timed.
final _poor = _Player((_, note, session) {
  if (note >= session.requiredHits) return null;
  return note.isEven ? 140 : -140;
});

/// Poor, and fails outright twice.
final _failing = _Player((phrase, note, session) {
  if ((phrase == 2 || phrase == 5) && note >= 2) return null;
  if (note >= session.requiredHits) return null;
  return note.isEven ? 140 : -140;
});

/// Everything right, until one dropped note in the middle of the run.
final _oneSlip = _Player(
  (phrase, note, _) => phrase == 2 && note == 3 ? null : 0,
);

/// A good player's run: one dropped note, and timing that wanders on one phrase.
final _goodRun = _Player((phrase, note, _) {
  if (phrase == 1 && note == 3) return null;
  if (phrase == 3) return note.isEven ? 150 : -150;
  return 0;
});

/// Starts with two scraped phrases, then settles down.
final _recovering = _Player((phrase, note, session) {
  if (phrase >= 2) return 0;
  if (note >= session.requiredHits) return null;
  return note.isEven ? 140 : -140;
});

/// Fails the opening phrase, then plays cleanly from there.
final _failsThenRecovers = _Player(
  (phrase, note, session) => phrase == 0 && note >= 2 ? null : _lagged,
);

class _Run {
  _Run(this.session, this.clearBeat, this.phrases);
  final GardenSession session;
  final double clearBeat;
  final int phrases;
  List<CrowdGuestSnapshot> get cast => [
    for (var i = 0; i < session.crowd.guestCount; i++)
      session.crowd.guest(i, clearBeat),
  ];
  int get standing => cast.where((g) => g.standing).length;
  int get celebrating =>
      cast.where((g) => g.state == CrowdGuestState.celebrating).length;
  int get occupied =>
      cast.where((g) => g.state == CrowdGuestState.occupied).length;
  double get swing => session.crowd.partySwing(clearBeat);
  String get outcome =>
      '${session.progress.tier}/${session.progress.entranceResets}/'
      '${session.passedPhrases}/'
      '${session.completedAtSeconds!.toStringAsFixed(3)}/'
      '${session.completedAtBeat!.toStringAsFixed(3)}/${session.perfects}';
}

_Run _play(
  _Player player, {
  FightDefinition? definition,
  FightChart chart = FightChart.garden,
  CrowdStageProfile? profile,
}) {
  final audio = _Audio();
  final transport = MusicTransport(
    MusicScore(
      id: 'test',
      beatsPerBar: 4,
      bars: 4,
      phraseBars: 1,
      tempos: const [120, 120, 120, 120, 120],
      notes: const [],
    ),
    audio,
    loop: true,
  );
  final session = GardenSession(
    transport,
    audio,
    definition: definition,
    chart: chart,
    crowdProfile: profile,
  )..start();

  void until(double seconds) {
    while (audio.nowSeconds + .01 < seconds) {
      audio.nowSeconds += .01;
      transport.pump();
      session.advance();
    }
    audio.nowSeconds = seconds;
    transport.pump();
    session.advance();
  }

  var phrase = 0;
  // Counted by the phrase that decides the win. The last move's window can run
  // past the phrase at a slow tempo, so the page's cleared phase may come later.
  while (!session.progress.cleared && phrase < 80) {
    final cycle = chart.introBeats + phrase * chart.cycleBeats;
    until(transport.secondsAt(cycle + chart.callBeats - .5));
    final limbs = session.activeLimbs;
    final actions = <(double, void Function())>[];
    for (var i = 0; i < limbs.length; i++) {
      final offset = player.offsetMs(phrase, i, session);
      if (offset == null) continue;
      final at =
          transport.secondsAt(cycle + chart.callBeats + chart.offsets[i]) +
          offset / 1000;
      actions.add((
        at,
        () {
          final result = session.tap(limbs[i]);
          final id = result.note?.id;
          if (player.gesture && id != null && result.note!.flourishTo != null) {
            actions.add((
              at + .13,
              () => session.flourishGesture(id, FlourishDirection.up),
            ));
            actions.sort((a, b) => a.$1.compareTo(b.$1));
          }
        },
      ));
    }
    actions.sort((a, b) => a.$1.compareTo(b.$1));
    for (var next = 0; next < actions.length; next++) {
      until(actions[next].$1);
      actions[next].$2();
    }
    until(transport.secondsAt(cycle + chart.cycleBeats - .02));
    phrase++;
  }
  until(audio.nowSeconds + 1);
  expect(session.phase, GardenPhase.cleared, reason: 'run must clear');
  return _Run(session, session.completedAtBeat!, phrase);
}

const _rooms = [
  ('garden', 0, FightChart.garden, 6),
  ('bar', 1, FightChart.bar, 10),
];

void main() {
  for (final (room, index, chart, clean) in _rooms) {
    _Run run(_Player player, {CrowdStageProfile? profile}) => _play(
      player,
      definition: fights[index],
      chart: chart,
      profile: profile,
    );

    group('$room run', () {
      test('a poor run clears warm: five dancing, the rest following', () {
        for (final player in [_poor, _failing]) {
          final poor = run(player);
          expect(poor.celebrating, 0);
          expect(poor.standing, CrowdEngagement.warmFloorOfTwelve);
          expect(poor.occupied, 0, reason: 'nobody is indifferent at a clear');
          expect(
            poor.cast.where((g) => g.state == CrowdGuestState.following).length,
            12 - CrowdEngagement.warmFloorOfTwelve,
          );
          expect(poor.swing, 0);
        }
      });

      test('sloppy timing clears with everyone up and half celebrating', () {
        final sloppy = run(_sloppy);
        expect(sloppy.phrases, clean, reason: 'timing never costs a pass');
        expect(sloppy.session.crowd.averageCredit, .75);
        expect(sloppy.standing, 12);
        expect(sloppy.celebrating, 6);
        expect(sloppy.swing, 0, reason: 'just short of the top');
      });

      test('a clean run reaches full swing, with no PERFECT or gesture', () {
        final tidy = run(_laggedClean);
        expect(tidy.phrases, clean);
        expect(tidy.session.perfects, 0);
        expect(tidy.celebrating, 12);
        expect(tidy.swing, 1);
        // It has arrived before the clear, and the exit shot samples it there.
        final last = tidy.session.crowd.guest(11, tidy.clearBeat - .01);
        expect(last.state, CrowdGuestState.celebrating);
      });

      test('steady lag is not sloppiness: latency is not calibrated yet', () {
        final lagged = run(_laggedClean);
        final onTime = run(_flawlessTaps);
        expect(lagged.celebrating, onTime.celebrating);
        expect(lagged.swing, onTime.swing);
      });

      test('poor play still cools the room against good play', () {
        final poor = run(_poor);
        final sloppy = run(_sloppy);
        final tidy = run(_laggedClean);
        expect(poor.standing, lessThan(sloppy.standing));
        expect(poor.celebrating, lessThan(sloppy.celebrating));
        expect(sloppy.celebrating, lessThan(tidy.celebrating));
        expect(sloppy.swing, lessThan(tidy.swing));
      });

      test('slips and a dropped note still reach full swing', () {
        for (final player in [_oneSlip, _goodRun]) {
          final good = run(player);
          expect(good.session.crowd.averageCredit, lessThan(1));
          expect(good.celebrating, 12);
          expect(good.swing, 1);
        }
      });

      test('a rough start can recover to full swing', () {
        for (final player in [_recovering, _failsThenRecovers]) {
          final back = run(player);
          expect(back.celebrating, 12);
          expect(back.swing, 1);
        }
      });

      test('ignoring every optional move costs nothing', () {
        final ignored = run(_flawlessTaps);
        final flicked = run(_flawlessWithFlicks);
        expect(ignored.outcome, flicked.outcome);
        expect(ignored.celebrating, flicked.celebrating);
        expect(ignored.swing, flicked.swing);
        expect(flicked.session.pizazz, greaterThan(0));
        expect(ignored.session.pizazz, 0);
        // A plain clean run with no extras gets the same top.
        final tidy = run(_laggedClean);
        expect(tidy.celebrating, flicked.celebrating);
        expect(tidy.swing, flicked.swing);
      });

      test('optional moves can add interest, never take it', () {
        final without = run(_laggedClean);
        final withFlicks = run(_laggedWithFlicks);
        for (var i = 0; i < 12; i++) {
          expect(
            withFlicks.cast[i].interest,
            greaterThanOrEqualTo(without.cast[i].interest),
          );
        }
      });

      test('clearing is decided as before: the crowd changes nothing', () {
        expect(fights[index].requiredHits(8, atPeak: true), 7);
        expect(
          fights[index].requiredHits(8, atPeak: false),
          index == 0 ? 6 : 7,
        );
        for (final player in [_flawlessTaps, _laggedClean, _poor, _failing]) {
          final full = run(player);
          final empty = run(
            player,
            profile: CrowdStageProfile(room, 0, 0, 0, 0),
          );
          expect(full.outcome, empty.outcome);
          expect(full.session.pizazz, empty.session.pizazz);
          expect(full.session.combo, empty.session.combo);
        }
        expect(run(_flawlessTaps).phrases, clean);
        expect(run(_poor).phrases, clean, reason: 'a scrape still advances');
      });

      test('the same play gives the same room', () {
        for (final player in [_poor, _failing, _flawlessTaps]) {
          final a = run(player);
          final b = run(player);
          expect(a.outcome, b.outcome);
          expect(
            a.cast.map((g) => '${g.state}/${g.interest}/${g.clip}'),
            b.cast.map((g) => '${g.state}/${g.interest}/${g.clip}'),
          );
          expect(a.swing, b.swing);
        }
      });
    });
  }

  group('the arc', () {
    test('interest grows over the level; nobody is full on phrase one', () {
      final crowd = CrowdInterestModel(rampPhrases: 4);
      var previous = 0;
      final standingByPhrase = <int>[];
      for (var phrase = 0; phrase < 6; phrase++) {
        crowd.resolvePhrase(
          sequence: phrase,
          passed: true,
          beat: 16.0 * (phrase + 1),
        );
        final standing = List.generate(
          12,
          (i) => crowd.guest(i, 16.0 * (phrase + 2)),
        ).where((g) => g.standing).length;
        expect(standing, greaterThanOrEqualTo(previous));
        previous = standing;
        standingByPhrase.add(standing);
      }
      expect(standingByPhrase.first, 0);
      expect(standingByPhrase[4], 12, reason: 'full a phrase before the clear');
    });

    test('a failed phrase drains slowly and seats no one at once', () {
      final crowd = CrowdInterestModel(rampPhrases: 4);
      for (var phrase = 0; phrase < 6; phrase++) {
        crowd.resolvePhrase(
          sequence: phrase,
          passed: true,
          beat: 16.0 * phrase,
        );
      }
      final before = List.generate(12, (i) => crowd.guest(i, 200).interest);
      crowd.resolvePhrase(sequence: 6, passed: false, beat: 200);
      final after = List.generate(12, (i) => crowd.guest(i, 240));
      for (var i = 0; i < 12; i++) {
        expect(before[i] - after[i].interest, lessThan(.15));
      }
      // Only the two guests the failure lands on may react.
      expect(after.where((g) => g.standing).length, greaterThanOrEqualTo(10));
      var failures = 0;
      while (List.generate(
        12,
        (i) => crowd.guest(i, 2000 + failures * 16.0),
      ).any((g) => g.standing)) {
        failures++;
        crowd.resolvePhrase(
          sequence: 6 + failures,
          passed: false,
          beat: 2000 + failures * 16.0,
        );
      }
      expect(failures, greaterThan(2), reason: 'the room cools over phrases');
    });

    test('the ladder, by average, on twelve guests', () {
      int standing(double average) => [
        for (var rank = 0; rank < 12; rank++)
          if (average >= CrowdEngagement.standsAt(rank / 11)) rank,
      ].length;
      int celebrating(double average) => [
        for (var rank = 0; rank < 12; rank++)
          if (average >= CrowdEngagement.celebratesAt(rank / 11)) rank,
      ].length;
      expect(standing(0), 5);
      expect(standing(.5), 5);
      expect(standing(.6), 8);
      expect(standing(.7), 12);
      expect(celebrating(.69), 0);
      expect(celebrating(.75), 6);
      expect(celebrating(.79), 10);
      expect(celebrating(.8), 12);
    });

    test('a warm clear, whatever the mix of grades, and full swing for good '
        'averages', () {
      const reports = [
        PhraseReport(notes: 8, hits: 8, perfects: 8),
        PhraseReport(notes: 8, hits: 8, perfects: 0),
        PhraseReport(notes: 8, hits: 8, perfects: 0, spreadMs: 100),
        PhraseReport(notes: 8, hits: 7, perfects: 0),
      ];
      final random = math.Random(1847);
      var topped = 0;
      for (final definition in fights) {
        final arc =
            4 * definition.successesPerTier + definition.finalChallenges;
        for (var run = 0; run < 400; run++) {
          // Each run has its own appetite for failures and for each grade.
          final failure = random.nextDouble() * .4;
          final skill = random.nextDouble();
          final progress = FightProgress(definition);
          final crowd = CrowdInterestModel(rampPhrases: arc, arcPhrases: arc);
          var sequence = 0;
          var beat = 16.0;
          var averageBefore = 0.0;
          while (!progress.cleared && sequence < 400) {
            final passed = random.nextDouble() >= failure;
            progress.resolve(passed: passed);
            if (progress.cleared) averageBefore = crowd.averageCredit;
            crowd.resolvePhrase(
              sequence: sequence++,
              passed: passed,
              beat: beat,
              report: passed
                  ? reports[random.nextDouble() < skill
                        ? random.nextInt(2)
                        : 2 + random.nextInt(2)]
                  : const PhraseReport(notes: 8, hits: 2, perfects: 0),
            );
            beat += 16;
          }
          if (!progress.cleared) continue;
          final clear = beat - 16;
          final cast = List.generate(12, (i) => crowd.guest(i, clear));
          final why = '${definition.id} run $run, $sequence phrases';
          expect(
            cast.where((g) => g.standing).length,
            greaterThanOrEqualTo(CrowdEngagement.warmFloorOfTwelve),
            reason: why,
          );
          expect(
            cast.where((g) => g.state == CrowdGuestState.occupied),
            isEmpty,
            reason: why,
          );
          if (averageBefore >= CrowdEngagement.fullSwingAverage) {
            topped++;
            expect(
              cast.where((g) => g.state == CrowdGuestState.celebrating).length,
              12,
              reason: '$why, average before the clear $averageBefore',
            );
            expect(crowd.partySwing(clear), 1, reason: why);
          }
        }
      }
      expect(topped, greaterThan(100), reason: 'the top must be exercised');
    });

    test('a slip does not shut the top, and a drop can be recovered from', () {
      final crowd = CrowdInterestModel(rampPhrases: 4);
      const best = PhraseReport(notes: 8, hits: 8, perfects: 8);
      crowd.resolvePhrase(
        sequence: 0,
        passed: true,
        beat: 16,
        report: const PhraseReport(notes: 8, hits: 7, perfects: 7),
      );
      expect(crowd.fullSwingEarned, isFalse);
      for (var phrase = 1; phrase < 6; phrase++) {
        crowd.resolvePhrase(
          sequence: phrase,
          passed: true,
          beat: 16.0 + 16 * phrase,
          report: best,
        );
      }
      expect(crowd.fullSwingEarned, isTrue);
      expect(crowd.partySwing(1000), 1);
      expect(
        List.generate(
          12,
          (i) => crowd.guest(i, 1000),
        ).every((g) => g.state == CrowdGuestState.celebrating),
        isTrue,
      );
    });

    test('an optional move can lift a phrase, and only once', () {
      const loose = PhraseReport(notes: 8, hits: 8, perfects: 0, spreadMs: 100);
      const flicked = PhraseReport(
        notes: 8,
        hits: 8,
        perfects: 0,
        gestures: 1,
        spreadMs: 100,
      );
      expect(CrowdEngagement.credit(PhraseGrade.clean, gesture: true), 1);
      final plain = CrowdInterestModel(rampPhrases: 4);
      final moved = CrowdInterestModel(rampPhrases: 4);
      for (var phrase = 0; phrase < 6; phrase++) {
        plain.resolvePhrase(
          sequence: phrase,
          passed: true,
          beat: 16.0 * phrase,
          report: loose,
        );
        moved.resolvePhrase(
          sequence: phrase,
          passed: true,
          beat: 16.0 * phrase,
          report: flicked,
        );
      }
      expect(plain.fullSwingEarned, isFalse);
      expect(moved.fullSwingEarned, isTrue, reason: 'loose with flicks: .85');
      // A flick after the phrase resolved counts the same, once.
      final late = CrowdInterestModel(rampPhrases: 4)
        ..resolvePhrase(sequence: 0, passed: true, beat: 16, report: loose);
      expect(late.averageCredit, .75);
      expect(late.gestureAfterPhrase(sequence: 0, beat: 16.2), isTrue);
      expect(late.averageCredit, closeTo(.85, 1e-9));
      expect(late.gestureAfterPhrase(sequence: 0, beat: 16.3), isFalse);
      expect(late.averageCredit, closeTo(.85, 1e-9));
    });

    test('grades read the report and ignore gestures for the floor', () {
      PhraseGrade grade({
        bool passed = true,
        int hits = 8,
        int perfects = 0,
        int gestures = 0,
        double spread = 0,
      }) => CrowdEngagement.grade(
        passed,
        PhraseReport(
          notes: 8,
          hits: hits,
          perfects: perfects,
          gestures: gestures,
          spreadMs: spread,
        ),
      );
      expect(grade(passed: false, hits: 0), PhraseGrade.failed);
      expect(grade(hits: 7, perfects: 7), PhraseGrade.scrappy);
      expect(grade(hits: 7, gestures: 3), PhraseGrade.scrappy);
      expect(grade(spread: 71, perfects: 8), PhraseGrade.loose);
      expect(grade(spread: 71, gestures: 3), PhraseGrade.loose);
      expect(grade(perfects: 3), PhraseGrade.clean);
      expect(grade(perfects: 4), PhraseGrade.excellent);
      expect(grade(gestures: 1), PhraseGrade.excellent);
    });

    test('spread ignores steady lag and sees scatter', () {
      expect(PhraseReport.spreadOf([150, 150, 150, 150]), 0);
      expect(PhraseReport.spreadOf([100, -100, 100, -100]), 100);
      expect(PhraseReport.spreadOf([5]), 0);
    });

    test('a flick landing after the phrase resolved counts, once', () {
      final crowd = CrowdInterestModel(rampPhrases: 4);
      crowd.resolvePhrase(sequence: 0, passed: true, beat: 16);
      expect(crowd.lastGrade, PhraseGrade.clean);
      final before = crowd.guest(0, 16).interest;
      expect(crowd.gestureAfterPhrase(sequence: 0, beat: 16.2), isTrue);
      expect(crowd.lastGrade, PhraseGrade.excellent);
      final after = crowd.guest(0, 16.2).interest;
      expect(after, greaterThan(before));
      expect(crowd.gestureAfterPhrase(sequence: 0, beat: 16.3), isFalse);
      expect(crowd.gestureAfterPhrase(sequence: 3, beat: 16.3), isFalse);
      expect(crowd.guest(0, 16.3).interest, after);
    });

    test('checkpoint restores the arc, so a replay cannot farm it', () {
      final crowd = CrowdInterestModel(rampPhrases: 4);
      const best = PhraseReport(notes: 8, hits: 8, perfects: 8);
      crowd.resolvePhrase(sequence: 0, passed: true, beat: 16, report: best);
      final checkpoint = crowd.checkpoint();
      crowd.resolvePhrase(sequence: 1, passed: true, beat: 32, report: best);
      crowd.resolvePhrase(sequence: 2, passed: false, beat: 48);
      expect(crowd.averageCredit, lessThan(1));
      crowd.restore(checkpoint);
      expect(crowd.averageCredit, 1);
      expect(crowd.partySwing(40), 0);
    });
  });

  group('props', () {
    const kinds = ['umbrella', 'plant', 'candle', 'waiter'];

    test('the swing arrives slowly, and leaves slowly', () {
      final crowd = CrowdInterestModel(rampPhrases: 4);
      const best = PhraseReport(notes: 8, hits: 8, perfects: 8);
      crowd.resolvePhrase(sequence: 0, passed: true, beat: 16, report: best);
      expect(crowd.partySwing(16.5), 0, reason: 'not on the first phrase');
      crowd.resolvePhrase(sequence: 1, passed: true, beat: 32, report: best);
      expect(crowd.partySwing(32), 0, reason: 'never switched on at speed');
      const samples = 48 * 20;
      var previous = 0.0;
      for (var i = 1; i <= samples; i++) {
        final value = crowd.partySwing(32 + i / 20);
        expect(value, greaterThanOrEqualTo(previous));
        expect(value - previous, lessThan(.002));
        previous = value;
      }
      expect(crowd.partySwing(80), 1, reason: 'a phrase before the clear');
      // A dropped note leaves the average high, and nothing changes.
      crowd.resolvePhrase(
        sequence: 2,
        passed: true,
        beat: 80,
        report: const PhraseReport(notes: 8, hits: 7, perfects: 7),
      );
      expect(crowd.fullSwingEarned, isTrue);
      expect(crowd.partySwing(104), 1);
      // Only falling below the top starts the fade, and it's slow.
      crowd.resolvePhrase(sequence: 3, passed: false, beat: 104);
      expect(crowd.fullSwingEarned, isFalse);
      expect(crowd.partySwing(104), 1);
      expect(crowd.partySwing(104 + 24), closeTo(.5, .001));
      expect(crowd.partySwing(104 + 48), 0);
      // Recovery brings it back, slowly again.
      for (final (sequence, beat) in [
        (4, 152.0),
        (5, 168.0),
        (6, 184.0),
        (7, 200.0),
      ]) {
        crowd.resolvePhrase(
          sequence: sequence,
          passed: true,
          beat: beat,
          report: best,
        );
      }
      expect(crowd.fullSwingEarned, isTrue);
      expect(crowd.partySwing(200), 0);
      expect(crowd.partySwing(216), 1);
    });

    test('below the top, props stay exactly as they were', () {
      for (final kind in kinds) {
        for (final seconds in [0.0, 1.5, 7.0, 31.0]) {
          expect(
            ensemblePartyFrame(kind, seconds, beat: 40, swing: 0, instance: 3),
            ensembleAmbientFrame(kind, seconds, instance: 3),
          );
        }
      }
    });

    test('at the top they follow the beat, not the wall clock', () {
      for (final kind in kinds) {
        expect(
          ensemblePartyFrame(kind, 1, beat: 40, swing: 1, instance: 3),
          ensemblePartyFrame(kind, 99, beat: 40, swing: 1, instance: 3),
        );
        final frames = {
          for (var beat = 40.0; beat < 44; beat += .05)
            ensemblePartyFrame(kind, 1, beat: beat, swing: 1),
        };
        expect(frames.length, 4, reason: 'the full range of drawings');
      }
    });

    test('range grows with the swing; props wake one by one', () {
      Set<String> range(double swing) => {
        for (var beat = 40.0; beat < 44; beat += .05)
          ensemblePartyFrame('plant', 1, beat: beat, swing: swing),
      };
      expect(range(.3).length, 2);
      expect(range(.6).length, 3);
      expect(range(1).length, 4);
      final woken = [
        for (var instance = 0; instance < 12; instance++)
          ensemblePartyFrame(
                'plant',
                100,
                beat: 41,
                swing: .1,
                instance: instance,
              ) !=
              ensembleAmbientFrame('plant', 100, instance: instance),
      ];
      expect(woken.contains(true), isTrue);
      expect(woken.contains(false), isTrue);
    });

    test('reduced motion keeps every prop still at any swing', () {
      for (final kind in kinds) {
        for (final swing in [0.0, .5, 1.0]) {
          expect(
            ensemblePartyFrame(
              kind,
              33,
              beat: 40.5,
              swing: swing,
              reducedMotion: true,
            ),
            '${kind}_a',
          );
        }
      }
    });
  });

  group('shipped levels', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('every room can end fully engaged', () async {
      final levels = await LevelRegistry.loadShipping();
      for (final level in levels.levels) {
        final budgets = level.crowd;
        expect(budgets.interested, 12, reason: level.id);
        expect(budgets.following, 12, reason: level.id);
        expect(budgets.standing, 12, reason: level.id);
        expect(budgets.cheering, 12, reason: level.id);
      }
    });

    test('clean-run length from each level sets its arc', () async {
      final levels = await LevelRegistry.loadShipping();
      for (final level in levels.levels) {
        final audio = _Audio();
        final transport = MusicTransport(
          MusicScore(
            id: 'test',
            beatsPerBar: 4,
            bars: 4,
            phraseBars: 1,
            tempos: const [120, 120, 120, 120, 120],
            notes: const [],
          ),
          audio,
          loop: true,
        );
        final session = level.newSession(transport, audio);
        expect(
          session.crowd.arcPhrases,
          4 * level.rules.successesPerTier + level.rules.finalChallenges,
        );
        expect(session.crowd.phraseBeats, level.chart.cycleBeats);
      }
    });
  });

  group('real scores, tempo changes included', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    (String, double) show(LevelDefinition level, {required bool flawless}) {
      final audio = _Audio();
      final music = MusicTransport(
        MusicScore.fromJson(
          jsonDecode(
            File('assets/music/scores/${level.music.score}.json')
                .readAsStringSync(),
          ) as Map<String, dynamic>,
        ),
        audio,
        loop: true,
        lookaheadSeconds: .3,
      );
      final session = level.newSession(music, audio)..start();
      final demo = PartyAutoplay(flawless: flawless)..enabled = true;
      while (session.phase != GardenPhase.cleared && audio.nowSeconds < 400) {
        audio.nowSeconds += .02;
        music.pump();
        session.advance();
        demo.pump(session);
      }
      expect(session.phase, GardenPhase.cleared, reason: level.id);
      final beat = session.completedAtBeat!;
      return (
        [for (var i = 0; i < 12; i++) session.crowd.guest(i, beat).state.name]
            .join(','),
        session.crowd.partySwing(beat),
      );
    }

    test(
      'every shipped level: flawless tops out, the default show stays warm',
      () async {
        final levels = await LevelRegistry.loadShipping();
        expect(levels.levels, isNotEmpty);
        for (final level in levels.levels) {
          final (best, swing) = show(level, flawless: true);
          expect(best.split(',').toSet(), {'celebrating'}, reason: level.id);
          expect(swing, 1, reason: level.id);
          final (imperfect, none) = show(level, flawless: false);
          final states = imperfect.split(',');
          expect(states, isNot(contains('occupied')), reason: level.id);
          expect(
            states.where((s) => s == 'celebrating').length,
            lessThan(12),
            reason: level.id,
          );
          expect(
            states.where((s) => s != 'following').length,
            greaterThanOrEqualTo(CrowdEngagement.warmFloorOfTwelve),
            reason: level.id,
          );
          expect(none, 0, reason: level.id);
        }
      },
    );
  });

  group('autoplay', () {
    (List<String>, double, int) watch({required bool flawless}) {
      final audio = _Audio();
      final transport = MusicTransport(
        MusicScore(
          id: 'test',
          beatsPerBar: 4,
          bars: 4,
          phraseBars: 1,
          tempos: const [120, 120, 120, 120, 120],
          notes: const [],
        ),
        audio,
        loop: true,
      );
      final session = GardenSession(transport, audio)..start();
      final autoplay = PartyAutoplay(flawless: flawless)..enabled = true;
      while (session.phase != GardenPhase.cleared && audio.nowSeconds < 300) {
        audio.nowSeconds += .02;
        transport.pump();
        session.advance();
        autoplay.pump(session);
      }
      expect(session.phase, GardenPhase.cleared);
      final beat = session.completedAtBeat!;
      return (
        [
          for (var i = 0; i < 12; i++)
            () {
              final g = session.crowd.guest(i, beat);
              return '${g.state.name}/${g.interest}/${g.clip.name}';
            }(),
        ],
        session.crowd.partySwing(beat),
        session.pizazz,
      );
    }

    test('values are deterministic', () {
      for (final flawless in [false, true]) {
        final a = watch(flawless: flawless);
        final b = watch(flawless: flawless);
        expect(a.$1, b.$1);
        expect(a.$2, b.$2);
        expect(a.$3, b.$3);
      }
    });

    test('the default imperfect show clears warm, short of the top', () {
      final (cast, swing, _) = watch(flawless: false);
      expect(
        cast.where((g) => g.startsWith('celebrating')).length,
        lessThan(12),
      );
      expect(swing, 0);
      expect(cast.where((g) => g.startsWith('occupied')), isEmpty);
      expect(
        cast.where((g) => !g.startsWith('following')).length,
        greaterThanOrEqualTo(CrowdEngagement.warmFloorOfTwelve),
      );
    });

    test('the flawless show reaches the top, for the owner to watch', () {
      final (cast, swing, _) = watch(flawless: true);
      expect(cast.every((g) => g.startsWith('celebrating')), isTrue);
      expect(swing, 1);
    });
  });
}
