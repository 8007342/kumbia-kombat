import 'challenger_choreography.dart';
import 'party_layout.dart';
import 'rhythm.dart';

/// What a dancer of a pair is doing this turn. Art only: the session never reads
/// this, so nothing here can move a note, the music or the score.
enum DuetRole {
  /// Dancing the call with the other dancer, on the pair's marks.
  pair,

  /// Dancing with Mācron through his answer.
  partner,

  /// Holding Mācron's hand while he turns under it. His flourish, her arm.
  spinning,

  /// Stepping slowly at the side, playing with her skirt.
  offTurn,

  /// Walking to the pair's next mark.
  incoming,
}

class DuetOffStep {
  const DuetOffStep(this.at, this.floor);

  /// Beats from the call's first beat.
  final double at;
  final PartyPoint floor;
}

/// One call and answer: who stands where in the pair, who partners Mācron, and
/// where the other one goes.
class DuetTurn {
  const DuetTurn({
    required this.partner,
    required this.left,
    required this.from,
    required this.to,
    required this.dance,
    required this.off,
    required this.offSteps,
  });

  /// Index into the level's challengers: who dances with Mācron this turn.
  final int partner;

  /// Index into the level's challengers: who is on the picture's left of the pair.
  final int left;

  /// The middle of the pair, as the call starts and as it ends.
  final PartyPoint from, to;

  /// Beside Mācron, at arm's reach, on the side the partner was already on.
  final PartyPoint dance;

  /// Where the other dancer goes when the call is over. Off the floor, at a side.
  final PartyPoint off;

  /// Her slow steps from there, through the answer.
  final List<DuetOffStep> offSteps;

  /// Whoever isn't partnering.
  int get other => 1 - partner;
}

/// The drawings of a pair's call. Each is drawn as the dancer on the picture's
/// left, with her inner hand reaching right, and mirrors for the other side.
class DuetPairFrames {
  const DuetPairFrames({
    required this.rest,
    required this.arm,
    required this.kick,
  });
  final List<String> rest;
  final String arm, kick;
}

/// Mācron turning under a partner's hand on a landed flourish.
class DuetSpinSpec {
  const DuetSpinSpec({
    required this.beats,
    required this.reachFrame,
    required this.heroFrames,
    required this.catchUpBeats,
  });

  /// One whole turn, in beats.
  final double beats;

  /// Her drawing, reaching toward the picture's right; mirrored on his right.
  final String reachFrame;

  /// His turn, drawn with the held hand toward the picture's left; he mirrors
  /// when she is on his right. Every drawing holds that hand on one spot.
  final List<String> heroFrames;

  /// How long she takes to rejoin the pair when a spin kept her past her walk.
  final double catchUpBeats;
}

/// A spin in progress, in beats from the current call's first beat. [from] is
/// negative when it started on the turn before and overflowed into this one.
class DuetSpin {
  const DuetSpin({
    required this.dancer,
    required this.floor,
    required this.from,
    required this.to,
    required this.catchUpTo,
  });
  final int dancer;
  final PartyPoint floor;
  final double from, to, catchUpTo;

  bool isTurning(double t) => t >= from && t < to;
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
    this.onLeft = false,
  });
  final PartyPoint floor;
  final DuetRole role;

  /// How far along a walk, 0 to 1, for the walking clips.
  final double travel;
  final bool moving;

  /// Whether her drawing flips. Which way a drawing faces depends on the role.
  final bool mirrored;

  /// In the pair, whether she is the one on the picture's left.
  final bool onLeft;
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
    required this.spread,
    required this.pairFrames,
    required this.spin,
    required this.exit,
  });
  final List<DuetTurn> turns;
  final String offClip, partnerClip;

  /// The partner's walk from Mācron back to the pair, after his last note.
  final double outgoingBeats;

  /// The other dancer's walk from the side back to the pair.
  final double incomingBeats;

  /// Half the distance between the two in the pair, in floor units. The scene
  /// closes what remains so the hands meet, whatever size depth makes them.
  final double spread;
  final DuetPairFrames pairFrames;
  final DuetSpinSpec spin;
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

  /// The spin a flourish landed at [flourishBeat] sets going, seen from the call
  /// starting at [callStartBeat], or null once it is over. It belongs to the
  /// answer the flourish landed in, or the one just before when a late swipe
  /// lands after the next call has started. Purely a reading of the two beats:
  /// the session never asks, so a missed flourish simply has no spin to show.
  DuetSpin? spinFrom({
    required double flourishBeat,
    required double beat,
    required double callStartBeat,
    required double introBeats,
    required double callBeats,
  }) {
    final cycle = callBeats * 2;
    final age = beat - flourishBeat;
    if (age < 0) return null;
    final fromIntro = flourishBeat - introBeats;
    if (fromIntro < 0) return null;
    var grid = (fromIntro / cycle).floor();
    if (fromIntro - grid * cycle < callBeats) grid--;
    if (grid < 0) return null;
    final to = flourishBeat + spin.beats;
    final walkStart = introBeats + grid * cycle + cycle - outgoingBeats;
    final catchUp = to > walkStart ? spin.catchUpBeats : 0.0;
    if (beat >= to + catchUp) return null;
    final turn = turns[grid % turns.length];
    return DuetSpin(
      dancer: turn.partner,
      floor: turn.dance,
      from: flourishBeat - callStartBeat,
      to: to - callStartBeat,
      catchUpTo: to + catchUp - callStartBeat,
    );
  }

  /// The drawing a dancer in the pair shows, with [limb] the sampler's limb at
  /// [phase]. The two read as one body facing the player: a limb on the picture's
  /// left is the left dancer's outer limb, and on the right the right dancer's,
  /// so their inner hands stay joined and the chart still reads by side.
  String pairFrame({
    required bool onLeft,
    required Limb? limb,
    required DanceMovePhase phase,
    required double beat,
  }) {
    final showing =
        limb != null &&
        (phase == DanceMovePhase.accent ||
            phase == DanceMovePhase.followThrough) &&
        onLeft == pictureLeftLimb(limb);
    if (showing) {
      return limb == Limb.leftHand || limb == Limb.rightHand
          ? pairFrames.arm
          : pairFrames.kick;
    }
    // Opposite weight on the two sides, so they rock toward and away together.
    final index = beat.floor() + (onLeft ? 0 : 1);
    return pairFrames.rest[index % pairFrames.rest.length];
  }

  /// The drawn limbs: a dancer faces us, so her left is on the picture's right.
  static bool pictureLeftLimb(Limb limb) =>
      limb == Limb.rightHand || limb == Limb.rightFoot;

  PartyPoint _pairFloor(DuetTurn turn, int dancer, double at, double callBeats) {
    final middle = _lerp(turn.from, turn.to, _ease(at / callBeats));
    final side = dancer == turn.left ? -spread : spread;
    return PartyPoint(middle.x + side, middle.y);
  }

  /// Where [dancer] stands and what she does, [t] beats into [turn]. [floorYield]
  /// is the sampler's: while a move overflows the call it stays at 0, so the move
  /// finishes mid-floor before anyone steps away. [spin] holds his partner beside
  /// him until he has finished turning, even past the end of the answer.
  DuetSample sample({
    required int dancer,
    required int turn,
    required double t,
    required double callBeats,
    required double floorYield,
    required double heroX,
    DuetSpin? spin,
    bool reducedMotion = false,
  }) {
    final base = _place(
      dancer: dancer,
      turn: turn,
      t: t,
      callBeats: callBeats,
      floorYield: floorYield,
      heroX: heroX,
      reducedMotion: reducedMotion,
    );
    if (spin == null || spin.dancer != dancer || reducedMotion) return base;
    final at = t.clamp(0.0, callBeats * 2);
    if (spin.isTurning(at)) {
      return DuetSample(
        floor: spin.floor,
        role: DuetRole.spinning,
        mirrored: spin.floor.x > heroX,
      );
    }
    if (at >= spin.to && at < spin.catchUpTo) {
      final u = (at - spin.to) / (spin.catchUpTo - spin.to);
      return DuetSample(
        floor: _lerp(spin.floor, base.floor, _ease(u)),
        role: DuetRole.incoming,
        travel: u.clamp(0.0, 1.0),
        moving: true,
      );
    }
    return base;
  }

  DuetSample _place({
    required int dancer,
    required int turn,
    required double t,
    required double callBeats,
    required double floorYield,
    required double heroX,
    required bool reducedMotion,
  }) {
    final now = turns[turn % turns.length];
    final next = turns[(turn + 1) % turns.length];
    final cycle = callBeats * 2;
    final at = t.clamp(0.0, cycle);
    final partnering = dancer == now.partner;
    final onLeft = dancer == now.left;
    final inPair = at < callBeats;
    if (reducedMotion) {
      if (inPair) {
        return DuetSample(
          floor: _pairFloor(now, dancer, 0, callBeats),
          role: DuetRole.pair,
          mirrored: !onLeft,
          onLeft: onLeft,
        );
      }
      if (partnering) {
        return DuetSample(
          floor: now.dance,
          role: DuetRole.partner,
          mirrored: now.dance.x < heroX,
        );
      }
      return DuetSample(
        floor: now.offSteps.isEmpty ? now.off : now.offSteps.last.floor,
        role: DuetRole.offTurn,
      );
    }
    final walk = partnering ? outgoingBeats : incomingBeats;
    final walkStart = cycle - walk;
    final rest = partnering
        ? now.dance
        : _offFloor(now, at, callBeats);
    if (at >= walkStart) {
      final u = (at - walkStart) / walk;
      return DuetSample(
        floor: _lerp(rest, _pairFloor(next, dancer, 0, callBeats), _ease(u)),
        role: DuetRole.incoming,
        travel: u.clamp(0.0, 1.0),
        moving: true,
      );
    }
    final yielded = floorYield.clamp(0.0, 1.0);
    final fromPair = _pairFloor(now, dancer, at.clamp(0.0, callBeats), callBeats);
    if (inPair && yielded == 0) {
      return DuetSample(
        floor: fromPair,
        role: DuetRole.pair,
        mirrored: !onLeft,
        onLeft: onLeft,
      );
    }
    if (yielded < 1) {
      return DuetSample(
        floor: _lerp(fromPair, rest, yielded),
        role: DuetRole.incoming,
        travel: yielded,
        moving: yielded > 0,
      );
    }
    if (partnering) {
      return DuetSample(
        floor: now.dance,
        role: DuetRole.partner,
        mirrored: now.dance.x < heroX,
      );
    }
    return DuetSample(
      floor: rest,
      role: DuetRole.offTurn,
      moving: _stepping(now, at, callBeats),
    );
  }

  bool _stepping(DuetTurn turn, double at, double callBeats) {
    var from = callBeats;
    for (final step in turn.offSteps) {
      if (at >= from && at < step.at) return true;
      from = step.at;
    }
    return false;
  }

  PartyPoint _offFloor(DuetTurn turn, double at, double callBeats) {
    var from = turn.off;
    var fromBeat = callBeats;
    for (final step in turn.offSteps) {
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
