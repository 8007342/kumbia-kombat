import 'dart:math' as math;

enum CrowdGuestState {
  occupied,
  curious,
  following,
  participating,
  celebrating,
}

/// Presentation is sampled from song beats. Reading a guest never changes it.
class CrowdGuestSnapshot {
  const CrowdGuestSnapshot({
    required this.interest,
    required this.state,
    required this.styleEnergy,
    required this.reactionBeat,
    this.noticedBy,
  });
  final double interest;
  final CrowdGuestState state;
  final double styleEnergy;
  final double reactionBeat;
  final int? noticedBy;
}

class _Guest {
  _Guest(this.interest);
  double interest;
  CrowdGuestState before = CrowdGuestState.occupied;
  CrowdGuestState after = CrowdGuestState.occupied;
  double reactionBeat = 0;
  double styleBeat = -100;
  double styleStrength = 0;
  double styleDuration = 4;
  int? noticedBy;

  _Guest copy() => _Guest(interest)
    ..before = before
    ..after = after
    ..reactionBeat = reactionBeat
    ..styleBeat = styleBeat
    ..styleStrength = styleStrength
    ..styleDuration = styleDuration
    ..noticedBy = noticedBy;
}

/// In-memory checkpoint; durable persistence belongs to the run save format.
class CrowdCheckpoint {
  CrowdCheckpoint._(this._guests, this._lastSequence, this._cleared);
  final List<_Guest> _guests;
  final int _lastSequence;
  final bool _cleared;
}

/// Lasting support comes from completed phrases, never a tap combo or a timer.
/// Neighbors notice each other on staggered beats; they cannot create support.
class CrowdInterestModel {
  CrowdInterestModel({required this.rampPhrases})
    : assert(rampPhrases > 0),
      _guests = List.generate(5, (i) => _Guest(.025 + i * .005));

  final int rampPhrases;
  List<_Guest> _guests;
  int _lastSequence = -1;
  bool _cleared = false;
  static const _receptiveness = [1.06, .94, 1.02, .97, 1.0];
  static const _noticeOrder = [0, 2, 1, 4, 3];

  bool get peakSupported =>
      _guests.where((g) => g.interest >= .70).length >= 4 &&
      _guests.fold(0.0, (total, g) => total + g.interest) / 5 >= .78;

  List<CrowdGuestSnapshot> get guests => List.generate(
    _guests.length,
    (i) => guest(i, _guests[i].reactionBeat),
    growable: false,
  );

  CrowdGuestSnapshot guest(int index, double beat) {
    final g = _guests[index];
    final age = beat - g.styleBeat;
    return CrowdGuestSnapshot(
      interest: g.interest,
      state: beat >= g.reactionBeat ? g.after : g.before,
      styleEnergy: age >= 0 && age < g.styleDuration
          ? g.styleStrength * (1 - age / g.styleDuration)
          : 0,
      reactionBeat: g.reactionBeat,
      noticedBy: g.noticedBy,
    );
  }

  CrowdCheckpoint checkpoint() => CrowdCheckpoint._(
    _guests.map((g) => g.copy()).toList(),
    _lastSequence,
    _cleared,
  );

  void restore(CrowdCheckpoint checkpoint) {
    _guests = checkpoint._guests.map((g) => g.copy()).toList();
    _lastSequence = checkpoint._lastSequence;
    _cleared = checkpoint._cleared;
  }

  /// A replay keeps its sequence number. Completed retries receive a new one.
  bool resolvePhrase({
    required int sequence,
    required bool passed,
    required double beat,
    bool cleared = false,
  }) {
    if (sequence <= _lastSequence) return false;
    _lastSequence = sequence;
    _cleared = cleared;
    for (var i = 0; i < _guests.length; i++) {
      final g = _guests[i];
      g.interest = (g.interest + (passed ? _receptiveness[i] / rampPhrases : 0))
          .clamp(0.0, 1.0);
      _change(i, beat);
    }
    if (!passed) stumble(sequence % _guests.length, beat);
    return true;
  }

  /// A playful near-trip affects the nearest guest and their neighbor only.
  void stumble(int index, double beat) {
    for (final (guestIndex, loss) in [(index, .09), ((index + 1) % 5, .035)]) {
      final g = _guests[guestIndex];
      g.interest = math.max(0, g.interest - loss);
      _change(guestIndex, beat);
    }
  }

  /// Caller deduplicates accepted adornments with the existing style ledger.
  void adorn(int index, double beat, {int chain = 1}) {
    final boundedChain = chain.clamp(1, 4);
    for (final (guestIndex, strength) in [
      (index, 1.0),
      ((index + 1) % 5, .45 + boundedChain * .15),
      if (boundedChain >= 3) ((index + 2) % 5, .5),
      if (boundedChain == 4) ((index + 3) % 5, .35),
    ]) {
      final g = _guests[guestIndex];
      g.styleBeat = beat;
      g.styleStrength = strength;
      g.styleDuration = 3.0 + boundedChain;
    }
  }

  void clearStyle() {
    for (final g in _guests) {
      g.styleStrength = 0;
    }
  }

  void _change(int index, double beat) {
    final g = _guests[index];
    final current = guest(index, beat).state;
    var next = _cleared
        ? CrowdGuestState.celebrating
        : g.interest >= .70
        ? CrowdGuestState.participating
        : g.interest >= .34
        ? CrowdGuestState.following
        : g.interest >= .12
        ? CrowdGuestState.curious
        : CrowdGuestState.occupied;
    // A tiny localized setback does not toggle someone repeatedly at a boundary.
    if (!_cleared && next.index < current.index) {
      final lowerBoundary = switch (current) {
        CrowdGuestState.participating => .62,
        CrowdGuestState.following => .26,
        CrowdGuestState.curious => .06,
        _ => 0.0,
      };
      if (g.interest >= lowerBoundary) next = current;
    }
    if (next == g.after) return;
    g.before = current;
    g.after = next;
    final order = _noticeOrder.indexOf(index);
    g.reactionBeat = beat.ceilToDouble() + order * .5;
    g.noticedBy = order == 0 ? null : _noticeOrder[order - 1];
  }
}
