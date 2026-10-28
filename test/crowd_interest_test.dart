import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/crowd_interest.dart';

void main() {
  test(
    'room budgets remain sparse after approval; VIP alone wins everyone',
    () {
      for (final profile in CrowdStageProfile.stages) {
        final crowd = CrowdInterestModel(rampPhrases: 4, profile: profile);
        expect(crowd.guestCount, 12);
        expect(
          crowd.guests
              .map((g) => '${g.archetypeIndex}:${g.paletteIndex}')
              .toSet()
              .length,
          12,
        );
        for (var phrase = 0; phrase < 6; phrase++) {
          crowd.resolvePhrase(
            sequence: phrase,
            passed: true,
            beat: phrase * 16.0,
            cleared: phrase == 5,
          );
        }
        final cast = List.generate(
          crowd.guestCount,
          (i) => crowd.guest(i, 120),
        );
        expect(
          cast.where((g) => g.state != CrowdGuestState.occupied).length,
          profile.interested,
        );
        expect(
          cast
              .where((g) => g.state.index >= CrowdGuestState.following.index)
              .length,
          profile.following,
        );
        expect(cast.where((g) => g.standing).length, profile.standing);
        expect(
          cast.where((g) => g.state == CrowdGuestState.celebrating).length,
          profile.cheering,
        );
        expect(crowd.peakSupported, isTrue);
      }
    },
  );

  test(
    'stand-up has anticipation and weight transfer instead of a pose snap',
    () {
      final crowd = CrowdInterestModel(rampPhrases: 4);
      for (var phrase = 0; phrase < 3; phrase++) {
        crowd.resolvePhrase(
          sequence: phrase,
          passed: true,
          beat: 16 + phrase * 16.0,
        );
      }
      final preparing = crowd.guest(0, 48.5);
      expect(preparing.clip, CrowdClip.standUp);
      expect(preparing.transitioning, isTrue);
      expect(preparing.standing, isFalse);
      expect(preparing.clipBeat, closeTo(.15, .0001));
      expect(crowd.guest(0, 49.8).standing, isTrue);
      expect(crowd.guest(0, 51).transitioning, isFalse);
      expect(crowd.guest(0, 51).state, CrowdGuestState.participating);
    },
  );

  test('a new result never cuts a stand-up motion halfway through', () {
    final crowd = CrowdInterestModel(
      rampPhrases: 4,
      profile: CrowdStageProfile.vip,
    );
    for (var phrase = 0; phrase < 3; phrase++) {
      crowd.resolvePhrase(
        sequence: phrase,
        passed: true,
        beat: 16 + phrase * 16.0,
      );
    }
    final before = crowd.guest(0, 49);
    expect(before.clip, CrowdClip.standUp);
    crowd.resolvePhrase(sequence: 3, passed: true, beat: 49);
    final after = crowd.guest(0, 49);
    expect(after.clip, before.clip);
    expect(after.clipBeat, before.clipBeat);
    expect(after.standing, before.standing);
    expect(crowd.guest(0, 55).state, CrowdGuestState.celebrating);
  });

  test('VIP reactions span multiple bars and finish before any approval', () {
    final crowd = CrowdInterestModel(
      rampPhrases: 4,
      profile: CrowdStageProfile.vip,
    );
    for (var phrase = 0; phrase < 4; phrase++) {
      crowd.resolvePhrase(
        sequence: phrase,
        passed: true,
        beat: 16 + phrase * 16.0,
      );
    }
    final reactions = crowd.guests.map((g) => g.reactionBeat).toList()..sort();
    expect(reactions.last - reactions.first, greaterThan(12));
    expect(reactions.toSet().length, 12);
    final perBar = <int, int>{};
    for (final beat in reactions) {
      final bar = (beat / 4).floor();
      perBar[bar] = (perBar[bar] ?? 0) + 1;
    }
    expect(perBar.values.every((count) => count <= 4), isTrue);
    expect(
      List.generate(
        12,
        (i) => crowd.guest(i, 96),
      ).every((g) => g.standing && g.state == CrowdGuestState.celebrating),
      isTrue,
    );
  });

  test(
    'exit plays sit-down transitions while early supporters clap longer',
    () {
      final crowd = CrowdInterestModel(
        rampPhrases: 4,
        profile: CrowdStageProfile.vip,
      );
      for (var phrase = 0; phrase < 4; phrase++) {
        crowd.resolvePhrase(
          sequence: phrase,
          passed: true,
          beat: phrase * 16.0,
        );
      }
      final leaving = crowd.guest(8, 99.1, exitBeat: 96);
      expect(leaving.clip, CrowdClip.sitDown);
      expect(leaving.transitioning, isTrue);
      expect(crowd.guest(0, 99.1, exitBeat: 96).standing, isTrue);
      expect(
        List.generate(
          12,
          (i) => crowd.guest(i, 110, exitBeat: 96),
        ).every((g) => !g.standing && g.clip == CrowdClip.seatedIdle),
        isTrue,
      );
      expect(
        crowd.guest(0, 110).standing,
        isTrue,
        reason: 'Exit sampling is pure.',
      );
    },
  );

  test('flourish waves cannot make seated holdouts stand', () {
    final crowd = CrowdInterestModel(rampPhrases: 4);
    for (var phrase = 0; phrase < 6; phrase++) {
      crowd.resolvePhrase(
        sequence: phrase,
        passed: true,
        beat: phrase * 16.0,
        cleared: phrase == 5,
      );
    }
    for (var i = 0; i < 12; i++) {
      crowd.adorn(i, 100, chain: 4);
    }
    final cast = List.generate(12, (i) => crowd.guest(i, 101));
    expect(cast.where((g) => g.standing).length, 1);
    expect(cast.where((g) => g.state == CrowdGuestState.occupied).length, 9);
  });

  test(
    'first phrase gets attention; sustained success earns peak before clear',
    () {
      final crowd = CrowdInterestModel(rampPhrases: 4);
      expect(
        crowd.guests.every((g) => g.state == CrowdGuestState.occupied),
        isTrue,
      );
      crowd.resolvePhrase(sequence: 0, passed: true, beat: 16);
      expect(crowd.guest(0, 17).clip, CrowdClip.notice);
      expect(crowd.guest(0, 17).transitioning, isTrue);
      expect(crowd.guest(0, 19).state, CrowdGuestState.curious);
      expect(crowd.guest(3, 16).state, CrowdGuestState.occupied);
      expect(crowd.peakSupported, isFalse);
      for (var sequence = 1; sequence < 4; sequence++) {
        crowd.resolvePhrase(
          sequence: sequence,
          passed: true,
          beat: sequence * 16 + 16,
        );
      }
      expect(crowd.peakSupported, isTrue);
      expect(
        crowd.guests.every((g) => g.state != CrowdGuestState.celebrating),
        isTrue,
      );
    },
  );

  test(
    'adornments excite neighbors without manufacturing lasting interest',
    () {
      final crowd = CrowdInterestModel(rampPhrases: 4);
      final before = crowd.guests.map((g) => g.interest).toList();
      crowd.adorn(2, 8);
      expect(crowd.guest(2, 8).styleEnergy, 1);
      expect(crowd.guest(3, 8).styleEnergy, 0);
      expect(crowd.guest(3, 8.5).styleEnergy, greaterThan(.5));
      expect(crowd.guest(4, 8).styleEnergy, 0);
      expect(crowd.guest(2, 12).styleEnergy, 0);
      expect(crowd.guests.map((g) => g.interest), before);
      expect(crowd.peakSupported, isFalse);
    },
  );

  test(
    'one failed combo affects only nearby guests and cannot resolve twice',
    () {
      final crowd = CrowdInterestModel(rampPhrases: 4);
      for (var sequence = 0; sequence < 4; sequence++) {
        crowd.resolvePhrase(
          sequence: sequence,
          passed: true,
          beat: sequence * 16.0,
        );
      }
      final before = crowd.guests.map((g) => g.interest).toList();
      crowd.resolvePhrase(sequence: 4, passed: false, beat: 64);
      expect(crowd.guest(4, 68).interest, lessThan(before[4]));
      expect(crowd.guest(5, 68).interest, lessThan(before[5]));
      for (final i in [0, 1, 2, 3, 6, 7, 8, 9, 10, 11]) {
        expect(crowd.guest(i, 68).interest, before[i]);
      }
      final after = crowd.guests.map((g) => g.interest).toList();
      expect(crowd.resolvePhrase(sequence: 4, passed: true, beat: 70), isFalse);
      expect(crowd.guests.map((g) => g.interest), after);
    },
  );

  test('sampling rate and checkpoint replay cannot change the crowd', () {
    final crowd = CrowdInterestModel(rampPhrases: 4);
    crowd.resolvePhrase(sequence: 0, passed: true, beat: 16);
    final checkpoint = crowd.checkpoint();
    crowd.adorn(0, 17);
    for (var frame = 0; frame < 1000; frame++) {
      crowd.guest(frame % 5, 16 + frame / 120);
    }
    crowd.restore(checkpoint);
    expect(crowd.guest(0, 17).styleEnergy, 0);
    expect(crowd.resolvePhrase(sequence: 0, passed: true, beat: 32), isFalse);
    expect(crowd.guest(0, 40).state, CrowdGuestState.curious);
    for (var sequence = 1; sequence <= 100; sequence++) {
      crowd.resolvePhrase(
        sequence: sequence,
        passed: false,
        beat: 40 + sequence * 16.0,
      );
    }
    expect(crowd.peakSupported, isFalse);
    expect(crowd.guests.every((g) => g.interest == 0), isTrue);
  });
}
