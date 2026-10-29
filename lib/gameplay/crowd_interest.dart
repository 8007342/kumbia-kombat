import 'dart:math' as math;

enum CrowdGuestState {
  occupied,
  curious,
  following,
  participating,
  celebrating,
}

/// Each tag names an authored multi-frame group, including movement between
/// seated and standing poses. The renderer must not substitute canvas bobbing.
enum CrowdClip {
  seatedIdle,
  notice,
  seatedFollow,
  standUp,
  standingIdle,
  stepTouch,
  clap,
  cheer,
  sitDown,
}

class CrowdStageProfile {
  const CrowdStageProfile(
    this.roomId,
    this.interested,
    this.following,
    this.standing,
    this.cheering,
  );
  final String roomId;

  /// Cumulative budgets at a reference cast size of twelve.
  final int interested;
  final int following;
  final int standing;
  final int cheering;

  static const garden = CrowdStageProfile('garden', 3, 2, 1, 0);
  static const bar = CrowdStageProfile('bar', 5, 4, 2, 1);
  static const coolCrowd = CrowdStageProfile('cool-crowd', 8, 7, 5, 3);
  static const restroom = CrowdStageProfile('restroom', 9, 8, 6, 4);
  static const vip = CrowdStageProfile('vip', 12, 12, 12, 12);
  static const stages = [garden, bar, coolCrowd, restroom, vip];

  static CrowdStageProfile forRoom(String id) => stages.firstWhere(
    (profile) => profile.roomId == id,
    orElse: () => garden,
  );

  CrowdGuestState ceiling(int rank, int count) {
    int budget(int value) => (value * count / 12).ceil();
    if (rank < budget(cheering)) return CrowdGuestState.celebrating;
    if (rank < budget(standing)) return CrowdGuestState.participating;
    if (rank < budget(following)) return CrowdGuestState.following;
    if (rank < budget(interested)) return CrowdGuestState.curious;
    return CrowdGuestState.occupied;
  }
}

class CrowdGuestSnapshot {
  const CrowdGuestSnapshot({
    required this.interest,
    required this.state,
    required this.styleEnergy,
    required this.reactionBeat,
    required this.clip,
    required this.clipBeat,
    required this.clipDurationBeats,
    required this.transitioning,
    required this.standing,
    required this.archetypeIndex,
    required this.paletteIndex,
    required this.phaseOffset,
    this.noticedBy,
  });
  final double interest;
  final CrowdGuestState state;
  final double styleEnergy;
  final double reactionBeat;
  final int? noticedBy;
  final CrowdClip clip;
  final double clipBeat;
  final double clipDurationBeats;
  final bool transitioning;
  final bool standing;
  final int archetypeIndex;
  final int paletteIndex;
  final double phaseOffset;
}

class _Motion {
  const _Motion(this.clip, this.start, this.duration, this.before, this.after);
  final CrowdClip clip;
  final double start;
  final double duration;
  final CrowdGuestState before;
  final CrowdGuestState after;
}

class _Pose {
  const _Pose(
    this.state,
    this.clip,
    this.beat,
    this.duration,
    this.transitioning,
    this.standing,
  );
  final CrowdGuestState state;
  final CrowdClip clip;
  final double beat;
  final double duration;
  final bool transitioning;
  final bool standing;
}

class _Guest {
  _Guest(this.interest, this.rank, this.phaseOffset);
  double interest;
  final int rank;
  final double phaseOffset;
  CrowdGuestState base = CrowdGuestState.occupied;
  CrowdGuestState target = CrowdGuestState.occupied;
  List<_Motion> motions = [];
  double reactionBeat = 0;
  double styleBeat = -100;
  double styleStrength = 0;
  double styleDuration = 4;
  int? noticedBy;
  _Guest copy() => _Guest(interest, rank, phaseOffset)
    ..base = base
    ..target = target
    ..motions = List.of(motions)
    ..reactionBeat = reactionBeat
    ..styleBeat = styleBeat
    ..styleStrength = styleStrength
    ..styleDuration = styleDuration
    ..noticedBy = noticedBy;
}

/// A bounded in-memory save, not a durable run-save implementation.
class CrowdCheckpoint {
  CrowdCheckpoint._(
    this._guests,
    this._lastSequence,
    this._support,
    this._consecutiveFailures,
  );
  final List<_Guest> _guests;
  final int _lastSequence;
  final double _support;
  final int _consecutiveFailures;
}

class CrowdInterestModel {
  CrowdInterestModel({
    required this.rampPhrases,
    this.profile = CrowdStageProfile.garden,
    int guestCount = 12,
  }) {
    if (rampPhrases <= 0 || guestCount <= 0) {
      throw ArgumentError('Crowd needs positive ramp and guest counts');
    }
    // Interleave depth/side slots so the first supporters are not one solid row.
    _order = [
      for (var column = 0; column < 4; column++)
        for (var i = column; i < guestCount; i += 4) i,
    ];
    _guests = List.generate(
      guestCount,
      (i) => _Guest(.025 + (i % 5) * .005, _order.indexOf(i), (i * .371) % 4),
    );
  }
  final int rampPhrases;
  final CrowdStageProfile profile;
  late final List<int> _order;
  late List<_Guest> _guests;
  int _lastSequence = -1;
  double _support = 0;
  int _consecutiveFailures = 0;
  int get guestCount => _guests.length;

  /// Musical readiness, independent of how expressive this room's guests are.
  /// Never an additional clearance requirement.
  bool get peakSupported => _support >= .9;
  double get earnedSupport => _support;

  List<CrowdGuestSnapshot> get guests => List.generate(
    guestCount,
    (i) => guest(
      i,
      _guests[i].motions.isEmpty
          ? 0
          : _guests[i].motions.last.start + _guests[i].motions.last.duration,
    ),
    growable: false,
  );

  /// Pure beat sampling, including a staggered return to each guest's own seat.
  /// Supply the conductor's continuous beat at the beginning of the exit coda.
  CrowdGuestSnapshot guest(int index, double beat, {double? exitBeat}) {
    final g = _guests[index];
    var pose = _sample(index, beat);
    final styleAge = beat - g.styleBeat;
    final energy = styleAge >= 0 && styleAge < g.styleDuration
        ? g.styleStrength * (1 - styleAge / g.styleDuration)
        : 0.0;
    if (exitBeat != null && beat >= exitBeat) {
      final atExit = _sample(index, exitBeat);
      final escort = g.rank < 2 && atExit.state != CrowdGuestState.occupied;
      final sitAt = exitBeat + 2 + g.rank * .47 + (escort ? 4 : 0);
      if (beat >= sitAt) {
        final duration = atExit.standing ? 2.0 : 1.0;
        pose = beat < sitAt + duration
            ? _Pose(
                atExit.state,
                atExit.standing ? CrowdClip.sitDown : CrowdClip.notice,
                beat - sitAt,
                duration,
                true,
                atExit.standing && beat - sitAt < duration / 2,
              )
            : _loop(CrowdGuestState.occupied, beat - sitAt - duration, index);
      } else {
        pose = _loop(atExit.state, beat - exitBeat, index);
      }
    } else if (energy > .2 && !pose.transitioning) {
      // A flourish can earn a glance from a busy guest, but cannot make a
      // seated holdout jump to a standing pose or breach the room's budget.
      pose = _Pose(
        pose.state,
        pose.standing
            ? CrowdClip.clap
            : pose.state == CrowdGuestState.occupied
            ? CrowdClip.notice
            : CrowdClip.seatedFollow,
        styleAge,
        g.styleDuration,
        false,
        pose.standing,
      );
    }
    return CrowdGuestSnapshot(
      interest: g.interest,
      state: pose.state,
      styleEnergy: energy,
      reactionBeat: g.reactionBeat,
      noticedBy: g.noticedBy,
      clip: pose.clip,
      clipBeat: pose.beat,
      clipDurationBeats: pose.duration,
      transitioning: pose.transitioning,
      standing: pose.standing,
      archetypeIndex: index % 3,
      paletteIndex: (index ~/ 3) % 4,
      phaseOffset: g.phaseOffset,
    );
  }

  CrowdCheckpoint checkpoint() => CrowdCheckpoint._(
    _guests.map((g) => g.copy()).toList(),
    _lastSequence,
    _support,
    _consecutiveFailures,
  );
  void restore(CrowdCheckpoint checkpoint) {
    if (checkpoint._guests.length != guestCount) {
      throw ArgumentError('Crowd checkpoint belongs to a different cast');
    }
    _guests = checkpoint._guests.map((g) => g.copy()).toList();
    _lastSequence = checkpoint._lastSequence;
    _support = checkpoint._support;
    _consecutiveFailures = checkpoint._consecutiveFailures;
  }

  bool resolvePhrase({
    required int sequence,
    required bool passed,
    required double beat,
    bool cleared = false,
  }) {
    if (sequence <= _lastSequence) return false;
    _lastSequence = sequence;
    _consecutiveFailures = passed ? 0 : _consecutiveFailures + 1;
    _support = (_support + (passed ? 1 / rampPhrases : -.035)).clamp(0.0, 1.0);
    // One failed phrase creates the existing local stumble. Repeated failures
    // cool the wider room slowly; one good phrase resets this broad-loss ramp.
    final roomLoss = !passed && _consecutiveFailures >= 2 ? .025 : 0.0;
    for (var i = 0; i < guestCount; i++) {
      final g = _guests[i];
      final ceiling = profile.ceiling(g.rank, guestCount);
      final maxInterest = ceiling == CrowdGuestState.occupied ? .07 : 1.0;
      final receptiveness = const [1.06, .94, 1.02, .97, 1.0][i % 5];
      g.interest =
          (g.interest + (passed ? receptiveness / rampPhrases : -roomLoss))
              .clamp(0.0, maxInterest);
      _change(i, beat);
    }
    if (!passed) stumble(sequence % guestCount, beat);
    // Approval intentionally does not override individual stage ceilings.
    return true;
  }

  void stumble(int index, double beat) {
    for (final (i, loss) in [
      (index % guestCount, .09),
      ((index + 1) % guestCount, .035),
    ]) {
      final g = _guests[i];
      g.interest = math.max(0, g.interest - loss);
      _change(i, beat);
    }
  }

  void adorn(int index, double beat, {int chain = 1}) {
    final bounded = chain.clamp(1, 4);
    for (
      var neighbor = 0;
      neighbor < math.min(guestCount, bounded >= 3 ? bounded : 2);
      neighbor++
    ) {
      final g = _guests[(index + neighbor) % guestCount];
      g.styleBeat = beat + neighbor * .23;
      g.styleStrength = neighbor == 0
          ? 1
          : neighbor == 1
          ? .45 + bounded * .15
          : .5 - (neighbor - 2) * .15;
      g.styleDuration = 3.0 + bounded;
    }
  }

  void clearStyle() {
    for (final g in _guests) {
      g.styleStrength = 0;
    }
  }

  _Pose _loop(CrowdGuestState state, double beat, int index) {
    final local = beat + _guests[index].phaseOffset;
    final clip = switch (state) {
      CrowdGuestState.occupied => CrowdClip.seatedIdle,
      CrowdGuestState.curious => CrowdClip.notice,
      CrowdGuestState.following => CrowdClip.seatedFollow,
      CrowdGuestState.participating => const [
        CrowdClip.standingIdle,
        CrowdClip.stepTouch,
        CrowdClip.clap,
      ][(local / 4).floor() % 3],
      CrowdGuestState.celebrating =>
        (local / 4).floor().isEven ? CrowdClip.cheer : CrowdClip.clap,
    };
    final duration = switch (clip) {
      CrowdClip.seatedIdle => 8.0,
      CrowdClip.notice => 4.0,
      _ => 2.0,
    };
    return _Pose(
      state,
      clip,
      local,
      duration,
      false,
      state.index >= CrowdGuestState.participating.index,
    );
  }

  _Pose _sample(int index, double beat) {
    final g = _guests[index];
    var state = g.base;
    var loopStart = 0.0;
    for (final motion in g.motions) {
      if (beat < motion.start) break;
      if (beat < motion.start + motion.duration) {
        final age = beat - motion.start;
        final standing = motion.clip == CrowdClip.standUp
            ? age >= motion.duration * .65
            : motion.clip == CrowdClip.sitDown
            ? age < motion.duration * .5
            : motion.before.index >= CrowdGuestState.participating.index;
        return _Pose(
          motion.before,
          motion.clip,
          age,
          motion.duration,
          true,
          standing,
        );
      }
      state = motion.after;
      loopStart = motion.start + motion.duration;
    }
    return _loop(state, beat - loopStart, index);
  }

  void _change(int index, double beat) {
    final g = _guests[index];
    final ceiling = profile.ceiling(g.rank, guestCount);
    var next = g.interest >= .90
        ? CrowdGuestState.celebrating
        : g.interest >= .72
        ? CrowdGuestState.participating
        : g.interest >= .38 + math.min(g.rank, 6) * .015
        ? CrowdGuestState.following
        : g.interest >= .15 + math.min(g.rank, 8) * .035
        ? CrowdGuestState.curious
        : CrowdGuestState.occupied;
    if (next.index > ceiling.index) next = ceiling;
    final current = _sample(index, beat);
    if (next.index < current.state.index) {
      final floor = switch (current.state) {
        CrowdGuestState.celebrating => .82,
        CrowdGuestState.participating => .64,
        CrowdGuestState.following => .30,
        CrowdGuestState.curious => .08,
        CrowdGuestState.occupied => 0.0,
      };
      if (g.interest >= floor) next = current.state;
    }
    if (next == g.target) return;
    while (g.motions.isNotEmpty &&
        g.motions.first.start + g.motions.first.duration <= beat) {
      g.base = g.motions.first.after;
      g.motions.removeAt(0);
    }
    // Fractional delays spread twelve guests over approximately fourteen beats;
    // no more than four begin a reaction in any four-beat bar.
    var cursor = beat + .35 + g.rank * 1.3 + ((index * 7) % 5) * .07;
    var state = current.state;
    final retained = <_Motion>[];
    if (g.motions.isNotEmpty &&
        next.index > g.target.index &&
        g.motions.last.start + g.motions.last.duration > beat) {
      // Finish the already promised look/lean/stand before adding enthusiasm.
      retained.addAll(g.motions);
      state = g.target;
      cursor = g.motions.last.start + g.motions.last.duration;
    } else {
      final active = g.motions.indexWhere(
        (motion) =>
            beat >= motion.start && beat < motion.start + motion.duration,
      );
      if (active >= 0) {
        // A setback may change the destination, never cut a standing motion
        // halfway through and teleport the guest back into their chair.
        retained.addAll(g.motions.take(active + 1));
        state = retained.last.after;
        cursor = retained.last.start + retained.last.duration;
      }
    }
    if (retained.isEmpty) g.base = current.state;
    g.target = next;
    g.motions = retained;
    g.reactionBeat = retained.isEmpty ? cursor : retained.first.start;
    g.noticedBy = g.rank == 0 ? null : _order[g.rank - 1];
    void add(CrowdClip clip, double duration, CrowdGuestState after) {
      g.motions.add(_Motion(clip, cursor, duration, state, after));
      cursor += duration;
      state = after;
    }

    if (state.index >= CrowdGuestState.participating.index &&
        next.index < CrowdGuestState.participating.index) {
      add(CrowdClip.sitDown, 2, next);
      return;
    }
    if (next.index < state.index) {
      add(
        next.index >= CrowdGuestState.participating.index
            ? CrowdClip.clap
            : next == CrowdGuestState.occupied
            ? CrowdClip.seatedIdle
            : CrowdClip.notice,
        1,
        next,
      );
      return;
    }
    while (state.index < next.index) {
      final after = CrowdGuestState.values[state.index + 1];
      switch (after) {
        case CrowdGuestState.curious:
          add(CrowdClip.notice, 2, after);
        case CrowdGuestState.following:
          add(CrowdClip.seatedFollow, 2, after);
        case CrowdGuestState.participating:
          add(CrowdClip.standUp, 2, after);
        case CrowdGuestState.celebrating:
          add(CrowdClip.clap, 1, state);
          add(CrowdClip.cheer, 1, after);
        case CrowdGuestState.occupied:
          break;
      }
    }
  }
}
