import 'dart:math' as math;

import 'party_layout.dart';

enum BattleFloorOwner { challenger, macron, neither }
enum BattleFacing { front, left, right, back }

/// Source-image floor roots, deliberately separate from sprite stature.
class BattleStageMarks {
  const BattleStageMarks({
    required this.challengerDemonstrating,
    required this.challengerWaypoint,
    required this.challengerWatching,
    required this.macronWatching,
    required this.macronWaypoint,
    required this.macronAnswering,
    required this.compactChallengerWatching,
    required this.compactMacronAnswering,
  });
  final PartyPoint challengerDemonstrating, challengerWaypoint,
      challengerWatching, macronWatching, macronWaypoint, macronAnswering,
      compactChallengerWatching, compactMacronAnswering;
}

const battleStageMarks = <String, BattleStageMarks>{
  'garden': BattleStageMarks(
    challengerDemonstrating: PartyPoint(.50, .59),
    challengerWaypoint: PartyPoint(.62, .55),
    challengerWatching: PartyPoint(.67, .47),
    macronWatching: PartyPoint(.35, .49),
    macronWaypoint: PartyPoint(.42, .55),
    macronAnswering: PartyPoint(.50, .64),
    compactChallengerWatching: PartyPoint(.62, .55),
    compactMacronAnswering: PartyPoint(.40, .64),
  ),
  'bar': BattleStageMarks(
    challengerDemonstrating: PartyPoint(.50, .49),
    challengerWaypoint: PartyPoint(.61, .45),
    challengerWatching: PartyPoint(.67, .39),
    macronWatching: PartyPoint(.35, .43),
    macronWaypoint: PartyPoint(.42, .51),
    macronAnswering: PartyPoint(.50, .61),
    compactChallengerWatching: PartyPoint(.61, .45),
    compactMacronAnswering: PartyPoint(.40, .61),
  ),
};

class BattleStagingSample {
  const BattleStagingSample({
    required this.challengerFloor,
    required this.macronFloor,
    required this.challengerFacing,
    required this.macronFacing,
    required this.floorOwner,
    this.challengerWalkPhase = 0,
    this.macronWalkPhase = 0,
    this.challengerMoving = false,
    this.macronMoving = false,
  });
  final PartyPoint challengerFloor, macronFloor;
  final BattleFacing challengerFacing, macronFacing;
  final BattleFloorOwner floorOwner;
  final double challengerWalkPhase, macronWalkPhase;
  final bool challengerMoving, macronMoving;
}

/// Pure beat-clock routes. Rendering projects these roots through the room's
/// floor plane; it must never fake a step by changing character stature.
class BattleStaging {
  BattleStaging({required String roomId, this.callBeats = 8})
      : marks = battleStageMarks[roomId] ??
            (throw ArgumentError.value(roomId, 'roomId')) {
    if (!callBeats.isFinite || callBeats < 8) {
      throw ArgumentError.value(callBeats, 'callBeats');
    }
  }
  final BattleStageMarks marks;
  final double callBeats;
  bool get cinematic => callBeats >= 12;

  BattleStagingSample sample({
    required double beat,
    required double callStartBeat,
    double? protectedUntilBeat,
    bool started = true,
    bool reducedMotion = false,
    bool holdResponse = false,
  }) {
    if (!beat.isFinite || !callStartBeat.isFinite ||
        (protectedUntilBeat != null && !protectedUntilBeat.isFinite)) {
      throw ArgumentError('Staging requires finite beats');
    }
    final t = beat - callStartBeat;
    if (!started || t < 0) return _demonstrating(active: false);
    return cinematic
        ? _cinematic(t, beat, protectedUntilBeat, reducedMotion, holdResponse)
        : _compact(t, beat, reducedMotion);
  }

  BattleStagingSample _compact(double t, double beat, bool reduced) {
    final yieldStart = callBeats - 1;
    final enterStart = callBeats - .75;
    final enterEnd = callBeats - .5;
    if (t < yieldStart) return _demonstrating();
    if (t < enterStart) {
      return _sample(
        challenger: reduced ? marks.compactChallengerWatching : _lerp(marks.challengerDemonstrating, marks.compactChallengerWatching, (t-yieldStart)/(enterStart-yieldStart)),
        macron: marks.macronWatching, owner: BattleFloorOwner.neither,
        challengerMoving: !reduced, beat: beat,
      );
    }
    if (t < enterEnd) {
      return _sample(
        challenger: marks.compactChallengerWatching,
        macron: reduced ? marks.compactMacronAnswering : _lerp(marks.macronWatching, marks.compactMacronAnswering, (t-enterStart)/(enterEnd-enterStart)),
        owner: BattleFloorOwner.macron, macronMoving: !reduced, beat: beat,
      );
    }
    return _answering(compact: true);
  }

  BattleStagingSample _cinematic(double t, double beat, double? protected, bool reduced, bool hold) {
    final yieldStart = callBeats - 3;
    final enterStart = callBeats - 2;
    final enterEnd = callBeats - 1;
    if (t < yieldStart) return _demonstrating();
    if (t < enterStart) return _sample(
      challenger: _route(marks.challengerDemonstrating, marks.challengerWaypoint, marks.challengerWatching, t-yieldStart, reduced),
      macron: marks.macronWatching, owner: BattleFloorOwner.neither,
      challengerMoving: !reduced, beat: beat,
    );
    if (t < enterEnd) return _sample(
      challenger: marks.challengerWatching,
      macron: _route(marks.macronWatching, marks.macronWaypoint, marks.macronAnswering, t-enterStart, reduced),
      owner: BattleFloorOwner.macron, macronMoving: !reduced, beat: beat,
    );
    final returnStart = math.max(callBeats * 2 - 3, (protected ?? callBeats * 2) - 0.0);
    if (hold || t < returnStart) return _answering();
    if (t < returnStart + 1.5) return _sample(
      challenger: marks.challengerWatching,
      macron: _route(marks.macronAnswering, marks.macronWaypoint, marks.macronWatching, (t-returnStart)/1.5, reduced),
      owner: BattleFloorOwner.neither, macronMoving: !reduced, beat: beat,
    );
    if (t < returnStart + 3) return _sample(
      challenger: _route(marks.challengerWatching, marks.challengerWaypoint, marks.challengerDemonstrating, (t-returnStart-1.5)/1.5, reduced),
      macron: marks.macronWatching, owner: BattleFloorOwner.challenger,
      challengerMoving: !reduced, beat: beat,
    );
    return _demonstrating();
  }

  BattleStagingSample _demonstrating({bool active = true}) => _sample(
    challenger: marks.challengerDemonstrating, macron: marks.macronWatching,
    owner: active ? BattleFloorOwner.challenger : BattleFloorOwner.neither,
  );
  BattleStagingSample _answering({bool compact = false}) => _sample(
    challenger: compact ? marks.compactChallengerWatching : marks.challengerWatching,
    macron: compact ? marks.compactMacronAnswering : marks.macronAnswering,
    owner: BattleFloorOwner.macron,
  );
  BattleStagingSample _sample({required PartyPoint challenger, required PartyPoint macron, required BattleFloorOwner owner, bool challengerMoving = false, bool macronMoving = false, double beat = 0}) => BattleStagingSample(
    challengerFloor: challenger, macronFloor: macron, floorOwner: owner,
    challengerFacing: owner == BattleFloorOwner.challenger && !challengerMoving ? BattleFacing.front : BattleFacing.left,
    macronFacing: owner == BattleFloorOwner.macron ? BattleFacing.front : BattleFacing.back,
    challengerMoving: challengerMoving, macronMoving: macronMoving,
    challengerWalkPhase: challengerMoving ? (beat * 2) % 1 : 0,
    macronWalkPhase: macronMoving ? (beat * 2) % 1 : 0,
  );
}

PartyPoint _route(PartyPoint start, PartyPoint waypoint, PartyPoint end, double progress, bool reduced) {
  if (reduced) return end;
  return progress < .5 ? _lerp(start, waypoint, progress * 2) : _lerp(waypoint, end, (progress-.5)*2);
}
PartyPoint _lerp(PartyPoint a, PartyPoint b, double progress) {
  final t = progress.clamp(0.0, 1.0);
  final ease = t * t * (3 - 2 * t);
  return PartyPoint(a.x + (b.x-a.x)*ease, a.y + (b.y-a.y)*ease);
}
