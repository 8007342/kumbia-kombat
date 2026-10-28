import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/crowd_interest.dart';

void main() {
  test(
    'first phrase gets attention; sustained success earns peak before clear',
    () {
      final crowd = CrowdInterestModel(rampPhrases: 4);
      expect(
        crowd.guests.every((g) => g.state == CrowdGuestState.occupied),
        isTrue,
      );
      crowd.resolvePhrase(sequence: 0, passed: true, beat: 16);
      expect(crowd.guest(0, 17).state, CrowdGuestState.curious);
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
      expect(crowd.guest(3, 8).styleEnergy, .6);
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
      expect(crowd.guest(0, 68).interest, lessThan(before[0]));
      for (final i in [1, 2, 3]) {
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
