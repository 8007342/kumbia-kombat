import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/battle_staging.dart';

void main() {
  for (final room in ['garden', 'bar']) {
    test('$room compact route is sequential and settled before response', () {
      final stage = BattleStaging(roomId: room);
      expect(stage.sample(beat: 6.9, callStartBeat: 0).floorOwner, BattleFloorOwner.challenger);
      final yielding = stage.sample(beat: 7.1, callStartBeat: 0);
      expect(yielding.challengerMoving, isTrue);
      expect(yielding.macronMoving, isFalse);
      final entering = stage.sample(beat: 7.35, callStartBeat: 0);
      expect(entering.challengerMoving, isFalse);
      expect(entering.macronMoving, isTrue);
      final answer = stage.sample(beat: 7.5, callStartBeat: 0);
      expect(answer.floorOwner, BattleFloorOwner.macron);
      expect(answer.macronMoving, isFalse);
      expect(answer.macronFloor.y, stage.marks.compactMacronAnswering.y);
    });
    test('$room cinematic response waits for protected input before return', () {
      final stage = BattleStaging(roomId: room, callBeats: 12);
      expect(stage.sample(beat: 9.5, callStartBeat: 0).challengerMoving, isTrue);
      expect(stage.sample(beat: 10.5, callStartBeat: 0).macronMoving, isTrue);
      final protected = stage.sample(beat: 23, callStartBeat: 0, protectedUntilBeat: 24);
      expect(protected.macronMoving, isFalse);
      final leaving = stage.sample(beat: 24.5, callStartBeat: 0, protectedUntilBeat: 24);
      expect(leaving.macronMoving, isTrue);
      final reduced = stage.sample(beat: 9, callStartBeat: 0, reducedMotion: true);
      expect(reduced.challengerMoving, isFalse);
      expect(reduced.challengerFloor.x, stage.marks.challengerWatching.x);
    });
  }
}
