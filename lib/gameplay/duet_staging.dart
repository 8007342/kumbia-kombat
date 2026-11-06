import 'party_layout.dart';

/// What a dancer of a pair is doing this turn. Art only: the session never reads
/// this, so nothing here can move a note, the music or the score.
enum DuetRole {
  /// Showing the call, then yielding toward Mācron. The sampler's pose stands.
  lead,

  /// Dancing with Mācron through his answer.
  partner,

  /// Leaving Mācron for this turn's end mark.
  outgoing,

  /// Stepping slowly at the side, playing with her skirt.
  offTurn,

  /// Walking to the next call's mark.
  incoming,
}

class DuetOffStep {
  const DuetOffStep(this.at, this.floor);

  /// Beats from the call's first beat.
  final double at;
  final PartyPoint floor;
}

/// One call and answer: who leads it, and where everybody goes.
class DuetTurn {
  const DuetTurn({
    required this.lead,
    required this.call,
    required this.dance,
    required this.end,
    required this.offSteps,
  });

  /// Index into the level's challengers.
  final int lead;

  /// Where she shows the call, and where she dances with Mācron after it.
  final PartyPoint call, dance;

  /// Where she is left when the turn is over. The next turn's off-turn starts here.
  final PartyPoint end;

  /// The other dancer's slow steps, from the mark the turn before left her on.
  final List<DuetOffStep> offSteps;
}

/// Where the pair go when the level is won: to the sides, then a quick reach down
/// to Mācron. Each keeps the side she was on, so nobody crosses to get there.
class DuetExit {
  const DuetExit({
    required this.left,
    required this.right,
    required this.leftReach,
    required this.rightReach,
    required this.sideBeats,
    required this.reachFrom,
    required this.reachTo,
    required this.reachFrame,
  });
  final PartyPoint left, right, leftReach, rightReach;

  /// Beats from the shot's start to reach the side marks.
  final double sideBeats;
  final double reachFrom, reachTo;

  /// A drawing that leans toward the picture's left; mirrored on the left side.
  final String reachFrame;
}

class DuetSample {
  const DuetSample({
    required this.floor,
    required this.role,
    this.travel = 0,
    this.moving = false,
    this.mirrored = false,
  });
  final PartyPoint floor;
  final DuetRole role;

  /// How far along a walk, 0 to 1, for the walking clips.
  final double travel;
  final bool moving;

  /// Partner clips reach toward the picture's left, so she mirrors on his left.
  final bool mirrored;
}

class DuetExitSample {
  const DuetExitSample({required this.floor, this.reaching = false, this.mirrored = false});
  final PartyPoint floor;
  final bool reaching;
  final bool mirrored;
}

/// The pair's floor pattern, as data from the level file. Pure: a position is a
/// function of the music beat and of the turn, so a skipped frame loses nothing.
class LevelDuet {
  const LevelDuet({
    required this.turns,
    required this.offClip,
    required this.partnerClip,
    required this.outgoingBeats,
    required this.incomingBeats,
    required this.exit,
  });
  final List<DuetTurn> turns;
  final String offClip, partnerClip;
  final double outgoingBeats, incomingBeats;
  final DuetExit exit;

  static double _ease(double u) {
    final t = u.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  static PartyPoint _lerp(PartyPoint a, PartyPoint b, double u) =>
      PartyPoint(a.x + (b.x - a.x) * u, a.y + (b.y - a.y) * u);

  /// Which turn a call starting at [callStartBeat] plays. Calls run on a fixed
  /// grid, so this reads the music's position alone and a retry moves on too.
  int turnIndex(double callStartBeat, double introBeats, double cycleBeats) =>
      ((callStartBeat - introBeats) / cycleBeats).round() % turns.length;

  DuetTurn _previous(int index) => turns[(index - 1) % turns.length];

  /// Where [dancer] stands and what she does, [t] beats into [turn]. [floorYield]
  /// is the sampler's: a spin that overflows the call keeps it at 0, so the spin
  /// finishes mid-floor before she moves.
  DuetSample sample({
    required int dancer,
    required int turn,
    required double t,
    required double callBeats,
    required double floorYield,
    required double heroX,
    bool reducedMotion = false,
  }) {
    final now = turns[turn % turns.length];
    final cycle = callBeats * 2;
    final at = t.clamp(0.0, cycle);
    if (dancer == now.lead) {
      if (reducedMotion) {
        final answering = at >= callBeats;
        return DuetSample(
          floor: answering ? now.dance : now.call,
          role: answering ? DuetRole.partner : DuetRole.lead,
          mirrored: answering && now.dance.x < heroX,
        );
      }
      final outStart = cycle - outgoingBeats;
      if (at >= outStart) {
        final u = (at - outStart) / outgoingBeats;
        return DuetSample(
          floor: _lerp(now.dance, now.end, _ease(u)),
          role: DuetRole.outgoing,
          travel: u.clamp(0.0, 1.0),
          moving: true,
        );
      }
      final settled = floorYield >= 1 && at >= callBeats;
      return DuetSample(
        floor: _lerp(now.call, now.dance, floorYield.clamp(0.0, 1.0)),
        role: settled ? DuetRole.partner : DuetRole.lead,
        mirrored: settled && now.dance.x < heroX,
      );
    }
    final rest = _offFloor(turn, at, reducedMotion);
    if (reducedMotion) {
      return DuetSample(floor: rest, role: DuetRole.offTurn);
    }
    final inStart = cycle - incomingBeats;
    if (at >= inStart) {
      final next = turns[(turn + 1) % turns.length];
      final u = (at - inStart) / incomingBeats;
      return DuetSample(
        floor: _lerp(rest, next.call, _ease(u)),
        role: DuetRole.incoming,
        travel: u.clamp(0.0, 1.0),
        moving: true,
      );
    }
    return DuetSample(floor: rest, role: DuetRole.offTurn, moving: _stepping(turn, at));
  }

  bool _stepping(int turn, double at) {
    var from = 0.0;
    for (final step in turns[turn % turns.length].offSteps) {
      if (at >= from && at < step.at) return true;
      from = step.at;
    }
    return false;
  }

  PartyPoint _offFloor(int turn, double at, bool reducedMotion) {
    final now = turns[turn % turns.length];
    var from = _previous(turn % turns.length).end;
    if (now.offSteps.isEmpty) return from;
    if (reducedMotion) return now.offSteps.last.floor;
    var fromBeat = 0.0;
    for (final step in now.offSteps) {
      if (at < step.at) {
        return _lerp(from, step.floor, _ease((at - fromBeat) / (step.at - fromBeat)));
      }
      from = step.floor;
      fromBeat = step.at;
    }
    return from;
  }

  /// Where [dancer] is when the level is won, [t] beats into [turn], for the walk
  /// to the sides. The win comes in the answer, or just after it: the sampler's
  /// yield is no use here, since a cleared pose always reports a full yield.
  PartyPoint floorAtWin({
    required int dancer,
    required int turn,
    required double t,
    required double callBeats,
    required double heroX,
  }) => sample(
    dancer: dancer,
    turn: turn,
    t: t,
    callBeats: callBeats,
    floorYield: t >= callBeats ? 1 : 0,
    heroX: heroX,
  ).floor;

  /// [e] counts beats from the shot's start. [from] is where she was at the win.
  DuetExitSample exitSample({
    required bool onLeft,
    required PartyPoint from,
    required double e,
    bool reducedMotion = false,
  }) {
    final side = onLeft ? exit.left : exit.right;
    final reach = onLeft ? exit.leftReach : exit.rightReach;
    if (reducedMotion) return DuetExitSample(floor: side);
    if (e >= exit.reachFrom) {
      return DuetExitSample(
        floor: _lerp(
          side,
          reach,
          _ease((e - exit.reachFrom) / (exit.reachTo - exit.reachFrom)),
        ),
        reaching: true,
        mirrored: onLeft,
      );
    }
    return DuetExitSample(floor: _lerp(from, side, _ease(e / exit.sideBeats)));
  }

  /// The close-up is drawn with the first dancer on the left. If she won on the
  /// right the picture mirrors, so whoever is on the right stays on the right.
  static bool closeupMirrored(double firstDancerX, double secondDancerX) =>
      firstDancerX > secondDancerX;
}
