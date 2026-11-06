import 'dart:math' as math;

import 'rhythm.dart';

const challengerFrameIds = [
  'occupied',
  'ready',
  'anticipate_left',
  'anticipate_right',
  'left_hand',
  'right_hand',
  'left_foot',
  'right_foot',
  'follow_left',
  'follow_right',
  'settle',
  'finish',
  'cede',
  'invite',
  'watch_left',
  'watch_right',
  'approve',
  'recover',
  'turn_in',
  'turn_out',
];

enum ChallengerDanceState {
  occupied,
  ready,
  demonstrate,
  settle,
  finish,
  cede,
  invite,
  handoffMove,
  watch,
  approve,
  recover,
}

enum DanceMovePhase { anticipation, accent, followThrough, settle, idle }

/// The player's own judged move remains authoritative during [responding].
enum PlayerDanceRole {
  waiting,
  ready,
  responding,
  finishing,
  celebrating,
  recovering,
}

const minimumRestBeats = .5;

/// How far the sidestep has gone when the call ends, and how long it then takes.
const yieldByHandoff = .45;
const yieldSettleBeats = 1.0;

/// The walk back to the demonstration mark, ending as the next call starts.
const returnBeats = 1.25;

class ChallengerPose {
  const ChallengerPose({
    required this.frameId,
    required this.state,
    this.floorYield = 0,
    this.rootOffsetX = 0,
    this.limb,
    this.noteIndex,
    this.movePhase = DanceMovePhase.idle,
    this.playerRole = PlayerDanceRole.waiting,
    this.restBeats,
    this.moveAge = 0,
  });

  final String frameId;
  final ChallengerDanceState state;

  /// 0 = demonstration mark; 1 = sideline watching the player's response.
  /// The renderer chooses the two room-local marks. This never moves the HUD.
  final double floorYield;

  /// A bounded step in logical art pixels. Vertical weight is authored in art.
  final double rootOffsetX;
  final Limb? limb;
  final int? noteIndex;
  final DanceMovePhase movePhase;
  final PlayerDanceRole playerRole;

  /// Beats since a settle finished, when a rest of at least [minimumRestBeats]
  /// remains before the next note's preparation. Null otherwise. The dance
  /// grammar may groove here; a shorter gap would only flash a stray drawing.
  final double? restBeats;

  /// Beats into a [ChallengerDanceState.handoffMove], for the grammar's clip.
  final double moveAge;

  ChallengerPose withFrame(String frame) => ChallengerPose(
    frameId: frame,
    state: state,
    floorYield: floorYield,
    rootOffsetX: rootOffsetX,
    limb: limb,
    noteIndex: noteIndex,
    movePhase: movePhase,
    playerRole: playerRole,
    restBeats: restBeats,
    moveAge: moveAge,
  );
}

String limbAccentFrame(Limb limb) => switch (limb) {
  Limb.leftHand => 'left_hand',
  Limb.rightHand => 'right_hand',
  Limb.leftFoot => 'left_foot',
  Limb.rightFoot => 'right_foot',
};

bool _left(Limb limb) => limb == Limb.leftHand || limb == Limb.leftFoot;
double _ease(double value) {
  final t = value.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Immutable choreography of the *actual* call chart. A tier is deliberately
/// absent: a costume, bounce or animation-speed change cannot invent notes.
/// Recreate when the session's active phrase changes, not on every frame.
class ChallengerChoreography {
  ChallengerChoreography({
    required List<Limb> limbs,
    required List<double> offsets,
    this.callBeats = 8,
  }) : limbs = List.unmodifiable(limbs),
       offsets = List.unmodifiable(offsets) {
    if (limbs.isEmpty ||
        limbs.length != offsets.length ||
        !callBeats.isFinite ||
        callBeats <= 0) {
      throw ArgumentError('Invalid challenger phrase');
    }
    var previous = -1.0;
    for (final offset in offsets) {
      if (!offset.isFinite ||
          offset < 0 ||
          offset <= previous ||
          offset >= callBeats) {
        throw ArgumentError(
          'Challenger note offsets must increase within the call',
        );
      }
      previous = offset;
    }
  }

  final List<Limb> limbs;
  final List<double> offsets;
  final double callBeats;

  /// Absolute beats must come from the music transport (including its continuing
  /// success/bridge presentation clock), never elapsed render or wall time.
  ChallengerPose sample({
    required double beat,
    required double callStartBeat,
    bool started = true,
    bool reducedMotion = false,
    double? outcomeBeat,
    bool? passed,
    bool cleared = false,
    double handoffMoveBeats = 0,
  }) {
    if (!beat.isFinite ||
        !callStartBeat.isFinite ||
        (outcomeBeat != null && !outcomeBeat.isFinite)) {
      throw ArgumentError('Choreography requires finite musical beats');
    }
    if (!started) {
      return const ChallengerPose(
        frameId: 'occupied',
        state: ChallengerDanceState.occupied,
      );
    }
    // Beat/seconds inversion can land a few ulps below an authored marker.
    final t = beat - callStartBeat + 1e-9;
    final outcomeAge = outcomeBeat == null ? -1.0 : beat - outcomeBeat;
    if (cleared && outcomeAge >= 0) {
      if (outcomeAge < .5) {
        return const ChallengerPose(
          frameId: 'approve',
          state: ChallengerDanceState.approve,
          floorYield: 1,
          playerRole: PlayerDanceRole.celebrating,
        );
      }
      return ChallengerPose(
        frameId: outcomeAge < .75
            ? 'turn_out'
            : outcomeAge < 1
            ? 'cede'
            : 'invite',
        state: outcomeAge < 1
            ? ChallengerDanceState.cede
            : ChallengerDanceState.invite,
        floorYield: 1,
        playerRole: PlayerDanceRole.celebrating,
      );
    }
    if (passed != null && outcomeAge >= 0 && outcomeAge < .75) {
      return ChallengerPose(
        frameId: passed ? 'approve' : 'recover',
        state: passed
            ? ChallengerDanceState.approve
            : ChallengerDanceState.recover,
        floorYield: t >= callBeats ? 1 : 0,
        playerRole: passed
            ? PlayerDanceRole.finishing
            : PlayerDanceRole.recovering,
      );
    }
    if (t < -2) {
      return const ChallengerPose(
        frameId: 'occupied',
        state: ChallengerDanceState.occupied,
      );
    }
    if (t < 0) {
      if (t >= offsets.first - .25) return _anticipation(0, reducedMotion);
      return ChallengerPose(
        frameId: t < -1 ? 'turn_in' : 'ready',
        state: ChallengerDanceState.ready,
      );
    }
    final move = reducedMotion ? null : _handoffMove(t, handoffMoveBeats);
    if (move != null) return move;
    if (t < callBeats) return _call(t, reducedMotion);

    // The sidestep finishes on the response's first beat, so it never rushes.
    if (!reducedMotion && t < callBeats + yieldSettleBeats) {
      return ChallengerPose(
        frameId: 'invite',
        state: ChallengerDanceState.invite,
        floorYield:
            yieldByHandoff +
            (1 - yieldByHandoff) * _ease((t - callBeats) / yieldSettleBeats),
        playerRole: PlayerDanceRole.responding,
      );
    }

    // Watch the response quietly, then turn back within its existing final rest.
    // The session replaces this chart at its boundary; this does not add time.
    final returnStart = callBeats * 2 - returnBeats;
    if (t >= returnStart) {
      return ChallengerPose(
        frameId: 'turn_in',
        state: ChallengerDanceState.ready,
        floorYield: reducedMotion
            ? 1
            : 1 - _ease((t - returnStart) / returnBeats),
        playerRole: PlayerDanceRole.waiting,
      );
    }
    return ChallengerPose(
      frameId: reducedMotion || (t * 2).floor().isEven
          ? 'watch_left'
          : 'watch_right',
      state: ChallengerDanceState.watch,
      floorYield: 1,
      playerRole: PlayerDanceRole.responding,
    );
  }

  /// A showy finish on the demonstration mark. It may overflow into the player's
  /// turn: only the drawing and the walk wait, never a note. Null outside it, or
  /// when it wouldn't leave time to step away before the walk back.
  ChallengerPose? _handoffMove(double t, double beats) {
    if (beats <= 0) return null;
    final start = offsets.last + math.min(.5, (callBeats - offsets.last) * .5);
    final end = start + beats;
    if (t < start || end + yieldSettleBeats > callBeats * 2 - returnBeats) {
      return null;
    }
    if (t < end) {
      return ChallengerPose(
        frameId: 'invite',
        state: ChallengerDanceState.handoffMove,
        moveAge: t - start,
        playerRole: t < callBeats
            ? PlayerDanceRole.ready
            : PlayerDanceRole.responding,
      );
    }
    if (t < end + yieldSettleBeats) {
      return ChallengerPose(
        frameId: 'invite',
        state: ChallengerDanceState.invite,
        floorYield: _ease((t - end) / yieldSettleBeats),
        playerRole: PlayerDanceRole.responding,
      );
    }
    return null;
  }

  ChallengerPose _anticipation(int index, bool reducedMotion) => ChallengerPose(
    frameId: _left(limbs[index]) ? 'anticipate_left' : 'anticipate_right',
    state: ChallengerDanceState.demonstrate,
    limb: limbs[index],
    noteIndex: index,
    movePhase: DanceMovePhase.anticipation,
  );

  ChallengerPose _call(double t, bool reducedMotion) {
    var previous = -1;
    for (var i = 0; i < offsets.length; i++) {
      if (offsets[i] <= t) {
        previous = i;
      } else {
        break;
      }
    }
    final next = previous + 1;
    if (next < offsets.length) {
      final gap = next == 0 ? 1.0 : offsets[next] - offsets[next - 1];
      final lead = math.min(.25, gap * .25);
      if (t >= offsets[next] - lead) return _anticipation(next, reducedMotion);
    }
    if (previous < 0) {
      return const ChallengerPose(
        frameId: 'ready',
        state: ChallengerDanceState.ready,
      );
    }

    final last = previous == offsets.length - 1;
    final gap = (last ? callBeats : offsets[previous + 1]) - offsets[previous];
    final duration = last ? math.min(.5, gap * .5) : math.min(.65, gap * .75);
    final age = t - offsets[previous];
    if (last && age >= duration) {
      final handoff = (age - duration) / (gap - duration);
      final yield = reducedMotion
          ? (handoff >= .5 ? 1.0 : 0.0)
          : yieldByHandoff * _ease((handoff - .25) / .75);
      return ChallengerPose(
        frameId: handoff < .25
            ? 'finish'
            : handoff < .5
            ? 'cede'
            : 'invite',
        state: handoff < .25
            ? ChallengerDanceState.finish
            : handoff < .5
            ? ChallengerDanceState.cede
            : ChallengerDanceState.invite,
        floorYield: yield,
        playerRole: PlayerDanceRole.ready,
      );
    }
    final limb = limbs[previous];
    final progress = age / duration;
    final side = _left(limb) ? -1.0 : 1.0;
    final foot = limb == Limb.leftFoot || limb == Limb.rightFoot;
    if (progress < .32) {
      return ChallengerPose(
        frameId: limbAccentFrame(limb),
        state: ChallengerDanceState.demonstrate,
        rootOffsetX: !reducedMotion && foot ? side * .8 : 0,
        limb: limb,
        noteIndex: previous,
        movePhase: DanceMovePhase.accent,
      );
    }
    if (progress < .70) {
      return ChallengerPose(
        frameId: _left(limb) ? 'follow_left' : 'follow_right',
        state: ChallengerDanceState.demonstrate,
        rootOffsetX: !reducedMotion && foot ? side * 1.1 : 0,
        limb: limb,
        noteIndex: previous,
        movePhase: DanceMovePhase.followThrough,
      );
    }
    return ChallengerPose(
      frameId: 'settle',
      state: ChallengerDanceState.settle,
      rootOffsetX: !reducedMotion && foot
          ? side * (1 - progress).clamp(0, 1)
          : 0,
      limb: limb,
      noteIndex: previous,
      movePhase: DanceMovePhase.settle,
      restBeats: age > duration && gap - duration - .25 >= minimumRestBeats
          ? age - duration
          : null,
    );
  }
}

class PlayerMovePose {
  const PlayerMovePose(this.frameId, this.phase, this.peakBeat);
  final String frameId;
  final DanceMovePhase phase;
  final double peakBeat;
}

/// Accepted taps give immediate visual feedback. Early taps can prepare before
/// the scheduled accent; late taps accent now, never rewind the music. A newer
/// accepted tap replaces this event, so required moves cannot queue behind art.
PlayerMovePose playerMovePose({
  required Limb limb,
  required double acceptedBeat,
  required double targetBeat,
  required double beat,
  double? nextRequiredBeat,
}) {
  if (![
    acceptedBeat,
    targetBeat,
    beat,
    ?nextRequiredBeat,
  ].every((value) => value.isFinite)) {
    throw ArgumentError('Player choreography requires finite musical beats');
  }
  final peak = math.max(acceptedBeat, targetBeat);
  if (beat + 1e-9 < acceptedBeat) {
    return PlayerMovePose('front_idle', DanceMovePhase.idle, peak);
  }
  if (beat + 1e-9 < peak) {
    return PlayerMovePose('anticipate', DanceMovePhase.anticipation, peak);
  }
  final duration = nextRequiredBeat == null
      ? .65
      : (nextRequiredBeat - peak).clamp(.12, .65);
  final age = math.max(0.0, beat - peak);
  if (age < duration * .32) {
    return PlayerMovePose(limbAccentFrame(limb), DanceMovePhase.accent, peak);
  }
  if (age < duration * .70) {
    return PlayerMovePose(
      _left(limb) ? 'groove_left' : 'groove_right',
      DanceMovePhase.followThrough,
      peak,
    );
  }
  if (age < duration) {
    return PlayerMovePose('front_idle', DanceMovePhase.settle, peak);
  }
  return PlayerMovePose('front_idle', DanceMovePhase.idle, peak);
}
