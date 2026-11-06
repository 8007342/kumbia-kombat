import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/challenger_choreography.dart';
import 'package:kumbia_kombat/gameplay/dance_grammar.dart';
import 'package:kumbia_kombat/gameplay/ensemble_sprites.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/progression.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transport.dart';

class GrammarAudio implements MusicAudioBackend {
  @override
  double nowSeconds = 0;
  @override
  bool get ready => true;
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {}
  @override
  void silence() {}
}

Map<String, dynamic> readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final data = readJson('assets/art/ensemble/choreography.json');
  final manifest = readJson('assets/art/ensemble/manifest.json');
  final grammar = DanceGrammar.fromJson(data);
  const dancers = ['gatekeeper', 'bartender'];

  // Resolves an id to its drawing, so an alias can't hide a shaker.
  String drawing(String dancer, String id) =>
      (manifest['atlases'][dancer]['frames'][id] as Map)['aliasOf']
          as String? ??
      id;

  /// Every frame a dancer can show on a clean or failed phrase, at any tier.
  Iterable<(ChallengerPose, ChallengerPose, double)> walk(
    String dancer,
    FightChart chart, {
    bool reducedMotion = false,
  }) sync* {
    for (var tier = 0; tier < 5; tier++) {
      final routine = ChallengerChoreography(
        limbs: chart.limbsFor(tier, 0),
        offsets: chart.offsets,
      );
      for (final (cleared, passed) in [
        (false, null),
        (false, true),
        (false, false),
        (true, true),
      ]) {
        for (var section = 0; section < 4; section++) {
          for (var i = -300; i < 2000; i++) {
            final beat = 20 + i / 100;
            final pose = routine.sample(
              beat: beat,
              callStartBeat: 20,
              reducedMotion: reducedMotion,
              outcomeBeat: passed == null ? null : 34.7,
              passed: passed,
              cleared: cleared,
            );
            yield (
              pose,
              grammar.dress(
                pose,
                dancer: dancer,
                beat: beat,
                callStartBeat: 20,
                tier: tier,
                section: section,
                outcomeBeat: passed == null ? null : 34.7,
                reducedMotion: reducedMotion,
              ),
              beat,
            );
          }
        }
      }
    }
  }

  test('all data names real frames, and grooves never show a call accent', () {
    final parsed = EnsembleManifest.fromJson(manifest);
    for (final dancer in dancers) {
      grammar.requireFrames(dancer, parsed.atlases[dancer]!.art.frames.keys);
    }
    final typo = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
    (typo['clips']['clap']['frames'] as List)[0] = 'clap_opne';
    expect(
      () => DanceGrammar.fromJson(typo).requireFrames(
        'gatekeeper',
        parsed.atlases['gatekeeper']!.art.frames.keys,
      ),
      throwsFormatException,
    );
    final accent = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
    (accent['clips']['hip_pops']['frames'] as List)[0] = 'left_hand_peak';
    expect(
      () => DanceGrammar.fromJson(accent).requireFrames(
        'gatekeeper',
        parsed.atlases['gatekeeper']!.art.frames.keys,
      ),
      throwsFormatException,
    );
    final missing = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
    (missing['clips'] as Map).remove('watch_sway');
    expect(() => DanceGrammar.fromJson(missing), throwsFormatException);
  });

  test('call accents are untouched and only the drawing ever changes', () {
    for (final dancer in dancers) {
      for (final chart in [FightChart.garden, FightChart.bar]) {
        for (var tier = 0; tier < 5; tier++) {
          final limbs = chart.limbsFor(tier, 0);
          final routine = ChallengerChoreography(
            limbs: limbs,
            offsets: chart.offsets,
          );
          for (var i = 0; i < limbs.length; i++) {
            final beat = 20 + chart.offsets[i];
            final pose = routine.sample(beat: beat, callStartBeat: 20);
            final dressed = grammar.dress(
              pose,
              dancer: dancer,
              beat: beat,
              callStartBeat: 20,
              tier: tier,
            );
            expect(dressed.movePhase, DanceMovePhase.accent);
            expect(dressed.frameId, limbAccentFrame(limbs[i]));
            expect(dressed.limb, limbs[i]);
            expect(dressed.noteIndex, i);
          }
        }
      }
      for (final (pose, dressed, _) in walk(dancer, FightChart.garden)) {
        expect(dressed.state, pose.state);
        expect(dressed.floorYield, pose.floorYield);
        expect(dressed.rootOffsetX, pose.rootOffsetX);
        expect(dressed.playerRole, pose.playerRole);
        expect(dressed.limb, pose.limb);
        expect(dressed.noteIndex, pose.noteIndex);
        expect(dressed.movePhase, pose.movePhase);
        // A limb's peak drawing appears only on that limb's accent.
        final isPeak = const [
          'left_hand',
          'right_hand',
          'left_foot',
          'right_foot',
        ].contains(dressed.frameId);
        expect(isPeak, pose.movePhase == DanceMovePhase.accent);
      }
    }
  });

  test('hits use each limb\'s own drawn clip', () {
    final routine = ChallengerChoreography(
      limbs: const [Limb.leftFoot, Limb.rightHand],
      offsets: const [1, 4],
    );
    String at(double t) => grammar
        .dress(
          routine.sample(beat: 20 + t, callStartBeat: 20),
          dancer: 'gatekeeper',
          beat: 20 + t,
          callStartBeat: 20,
        )
        .frameId;
    expect(at(.9), 'left_foot_prep');
    expect(at(1), 'left_foot');
    expect(at(1.3), 'left_foot_follow');
    expect(at(1.6), 'left_foot_return');
    // A long rest grooves, then prepares the next note on time.
    expect(at(3), startsWith('groove_'));
    expect(at(3.9), 'right_hand_prep');
    expect(at(4), 'right_hand');
    expect(at(4.2), 'right_hand_follow');
  });

  test('a call only grooves in rests long enough to read', () {
    final routine = ChallengerChoreography(
      limbs: FightChart.garden.limbs,
      offsets: FightChart.garden.offsets,
    );
    final grooving = <double>[];
    for (var i = 0; i < 800; i++) {
      final t = i / 100;
      final frame = grammar
          .dress(
            routine.sample(beat: 20 + t, callStartBeat: 20),
            dancer: 'gatekeeper',
            beat: 20 + t,
            callStartBeat: 20,
          )
          .frameId;
      if (frame.startsWith('groove_')) grooving.add(t);
    }
    // Only the rest after beat 2.5 is long enough in this chart.
    expect(grooving.first, greaterThanOrEqualTo(3.1));
    expect(grooving.last, lessThan(3.75));
  });

  test('groove belongs to the beat: paused, tempo-free and in drawn order', () {
    ChallengerPose watching(double beat) => const ChallengerPose(
      frameId: 'watch_left',
      state: ChallengerDanceState.watch,
      floorYield: 1,
      playerRole: PlayerDanceRole.responding,
    );
    String frame(double beat, {int tier = 1, int section = 0}) => grammar
        .dress(
          watching(beat),
          dancer: 'gatekeeper',
          beat: beat,
          callStartBeat: beat - 12.2,
          tier: tier,
          section: section,
        )
        .frameId;
    // Same beat, same drawing, however many times or in what order it is read.
    expect(frame(1000.3), frame(1000.3));
    frame(5);
    expect(frame(1000.3), frame(1000.3));
    // Mid-frame samples agree; the next count changes it.
    final loop = [for (var b = 40.2; b < 44; b++) frame(b, tier: 0)];
    expect(loop.toSet().length, 4);
    expect(frame(40.2, tier: 0), frame(40.9, tier: 0));
    // Sections change which variant leads the same tier.
    expect(frame(41.2, section: 0), isNot(frame(41.2, section: 1)));
    // Tiers read differently.
    final byTier = {
      for (var tier = 0; tier < 5; tier++)
        [for (var b = 40.0; b < 48; b += .5) frame(b, tier: tier)].join(),
    };
    expect(byTier.length, 5);
  });

  test('clap contact lands on the phrase beat; tier 0 stays quiet', () {
    String at(double t, int tier, {String dancer = 'gatekeeper'}) => grammar
        .dress(
          const ChallengerPose(
            frameId: 'watch_left',
            state: ChallengerDanceState.watch,
            floorYield: 1,
            playerRole: PlayerDanceRole.responding,
          ),
          dancer: dancer,
          beat: 20 + t,
          callStartBeat: 20,
          tier: tier,
        )
        .frameId;
    // Cycle start is 4 past a phrase, so t 12 is the score's two-bar downbeat.
    expect(at(12, 1), 'clap_contact');
    expect(at(11.5, 1), 'clap_open');
    expect(at(12.25, 1), 'clap_release');
    expect(at(14, 2), 'clap_contact');
    expect(at(14, 1), isNot(startsWith('clap')));
    // The shared grammar claps the brass stab once the dancer reaches the sideline.
    expect(at(10.5, 4), 'clap_contact');
    expect(at(10.5, 4, dancer: 'swing-a'), 'clap_contact');
    expect(at(12, 0), isNot(startsWith('clap')));
    // The offered palm holds as the player's first note lands.
    expect(at(8.2, 3), 'invite');
  });

  test('brass accents sit on real brass notes in both scores', () {
    final brass = grammar.accents.singleWhere((a) => a.atBeat == 14.5);
    for (final name in ['garden_mojo', 'bar_swag']) {
      final score = MusicScore.fromJson(
        readJson('assets/music/scores/$name.json'),
      );
      expect(
        score.notes.any(
          (n) =>
              n.track == 'brass' &&
              n.audibleAt(brass.minTier) &&
              n.beat % brass.everyBeats == brass.atBeat,
        ),
        isTrue,
        reason: name,
      );
      expect(score.sectionAt(0), 0);
      expect(score.sectionAt(40), 1);
      expect(score.sectionAt(127.9), 3);
      expect(score.sectionAt(128), 0);
    }
  });

  test('celebration keeps moving past the old held invite', () {
    for (final dancer in dancers) {
      final seen = <String>{};
      final routine = ChallengerChoreography(
        limbs: FightChart.garden.limbs,
        offsets: FightChart.garden.offsets,
      );
      for (var i = 0; i < 2000; i++) {
        final beat = 100 + i / 100;
        seen.add(
          grammar
              .dress(
                routine.sample(
                  beat: beat,
                  callStartBeat: 88,
                  outcomeBeat: 100,
                  passed: true,
                  cleared: true,
                ),
                dancer: dancer,
                beat: beat,
                callStartBeat: 88,
                tier: 4,
                outcomeBeat: 100,
              )
              .frameId,
        );
      }
      expect(seen, containsAll(['approval_nod', 'clap_contact']));
      expect(seen.length, greaterThan(10));
    }
  });

  test('reduced motion keeps hits and holds everything decorative', () {
    final decorative = RegExp(r'^(groove_|clap_|challenge_|yield_side_)');
    for (final dancer in dancers) {
      final watchFrames = <String>{};
      final celebration = <String>{};
      for (final (pose, dressed, _) in walk(
        dancer,
        FightChart.bar,
        reducedMotion: true,
      )) {
        expect(dressed.frameId, isNot(matches(decorative)));
        expect(dressed.rootOffsetX, 0);
        if (pose.state == ChallengerDanceState.watch) {
          watchFrames.add(dressed.frameId);
        }
        if (pose.playerRole == PlayerDanceRole.celebrating) {
          celebration.add(dressed.frameId);
        }
        if (pose.movePhase == DanceMovePhase.accent) {
          expect(dressed.frameId, limbAccentFrame(pose.limb!));
        }
      }
      expect(watchFrames, hasLength(1));
      expect(celebration, hasLength(1));
    }
  });

  test('the bartender never shows the shaker while her overrides stand', () {
    bool shaker(String id) {
      final d = drawing('bartender', id);
      return d.startsWith('groove_') || d.startsWith('challenge_');
    }

    for (final chart in [FightChart.garden, FightChart.bar]) {
      for (final reduced in [false, true]) {
        for (final (_, dressed, _) in walk(
          'bartender',
          chart,
          reducedMotion: reduced,
        )) {
          expect(shaker(dressed.frameId), isFalse, reason: dressed.frameId);
        }
      }
    }
    final idle = grammar.dress(
      const ChallengerPose(
        frameId: 'occupied',
        state: ChallengerDanceState.occupied,
      ),
      dancer: 'bartender',
      beat: 0,
      callStartBeat: 0,
      reducedMotion: true,
    );
    expect(shaker(idle.frameId), isFalse);
  });

  test('identical input scores identically with the dance layer on or off', () {
    String play({required bool dressed, required bool sloppy}) {
      final score = MusicScore.fromJson(
        readJson('assets/music/scores/garden_mojo.json'),
      );
      final audio = GrammarAudio();
      final transport = MusicTransport(
        score,
        audio,
        loop: true,
        lookaheadSeconds: .3,
      );
      final session = GardenSession(
        transport,
        audio,
        definition: fights.first,
        chart: FightChart.garden,
      )..start();
      final done = <String>{};
      final log = StringBuffer();
      var phrase = 0;
      var lastStart = session.callStartBeat;
      for (
        var step = 0;
        step < 240 * 120 && session.phase != GardenPhase.cleared;
        step++
      ) {
        audio.nowSeconds += 1 / 240;
        transport.pump();
        session.advance();
        if (session.callStartBeat != lastStart) {
          lastStart = session.callStartBeat;
          phrase++;
        }
        final beat = session.positionBeats;
        if (dressed) {
          final pose = ChallengerChoreography(
            limbs: session.activeLimbs,
            offsets: session.activeOffsets,
          ).sample(beat: beat, callStartBeat: session.callStartBeat);
          grammar.dress(
            pose,
            dancer: 'gatekeeper',
            beat: beat,
            callStartBeat: session.callStartBeat,
            tier: session.progress.tier,
            section: score.sectionAt(beat),
          );
        }
        final response = session.callStartBeat + session.chart.callBeats;
        for (var i = 0; i < session.activeLimbs.length; i++) {
          final key = '${session.callStartBeat}:$i';
          // The sloppy player drops the second phrase's first notes and rushes.
          final skip = sloppy && phrase == 1 && i < 4;
          final lead = sloppy ? .05 : 0;
          if (!skip &&
              !done.contains(key) &&
              beat >= response + session.chart.offsets[i] - lead) {
            done.add(key);
            final result = session.tap(session.activeLimbs[i]);
            log.write('${result.grade.name}${result.deltaMs};');
          }
        }
      }
      log.write(
        '|${session.pizazz}|${session.perfects}|${session.combo}'
        '|${session.passedPhrases}|${session.lastOutcome}'
        '|${session.completedAtBeat}|${session.progress.tier}',
      );
      return log.toString();
    }

    for (final sloppy in [false, true]) {
      expect(
        play(dressed: true, sloppy: sloppy),
        play(dressed: false, sloppy: sloppy),
      );
    }
  });

  test(
    'opponents finish on the mark as the call ends, never at the sideline',
    () {
      const watching = ChallengerPose(
        frameId: 'watch_left',
        state: ChallengerDanceState.watch,
        floorYield: 1,
        playerRole: PlayerDanceRole.responding,
      );
      String resting(String dancer, double beat, int tier) => grammar
          .dress(
            watching,
            dancer: dancer,
            beat: beat,
            callStartBeat: beat - 12,
            tier: tier,
          )
          .frameId;
      String moving(String dancer, double age) => grammar
          .dress(
            ChallengerPose(
              frameId: 'invite',
              state: ChallengerDanceState.handoffMove,
              moveAge: age,
            ),
            dancer: dancer,
            beat: 100,
            callStartBeat: 93,
            tier: 1,
          )
          .frameId;
      for (final dancer in ['gatekeeper', 'bartender']) {
        expect(grammar.handoffBeats(dancer, 0), 1.5);
        expect(grammar.handoffBeats(dancer, 1), 3);
        expect(grammar.handoffBeats(dancer, 4), 3);
        expect(moving(dancer, 0), 'spin_front');
        expect(moving(dancer, 1), 'spin_back');
        expect(moving(dancer, 2.5), startsWith('flare_'));
        // Nothing showy is left for the sideline.
        for (var beat = 0.0; beat < 16; beat += .25) {
          expect(resting(dancer, beat, 4), isNot(startsWith('spin_')));
          expect(resting(dancer, beat, 4), isNot(startsWith('flare_')));
        }
      }
      // The swing pair have no spin art yet, and keep the shared grammar.
      expect(grammar.handoffBeats('swing-a', 4), 0);
    },
  );
}
