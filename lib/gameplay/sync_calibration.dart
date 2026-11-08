import 'dart:math' as math;

/// The tap-along that measures how late this phone, and this player, land
/// against what they hear. It shifts judging only, never the audio. See
/// `plan/feel-2026-11-07.md` and the research cheatsheet it cites.
///
/// Pure: the page plays the clicks and hands over tap times, on the clock taps
/// are judged by, with the browser's latency estimate already taken off. What
/// comes out is what that estimate still gets wrong on this device.
class SyncCalibration {
  SyncCalibration({
    required this.firstClickMs,
    this.bpm = 100,
    this.countInClicks = 4,
    this.tapClicks = 16,
  });

  /// When the first click sounds, on the audio clock, in milliseconds.
  final int firstClickMs;
  final double bpm;

  /// Clicks to listen to before tapping. Their taps don't count.
  final int countInClicks;

  /// Clicks to tap along with.
  final int tapClicks;

  /// Fewer kept taps than this, and the result isn't trusted.
  static const minimumTaps = 8;

  /// A tap this far from the median is a stumble, not the player's timing.
  static const outlierMs = 150;

  /// The most a calibration may shift judging, either way.
  static const maxOffsetMs = 250;

  double get beatMs => 60000 / bpm;
  int get totalClicks => countInClicks + tapClicks;

  /// Every click, on the audio clock.
  List<int> get clicksMs => [
    for (var i = 0; i < totalClicks; i++) (firstClickMs + i * beatMs).round(),
  ];

  /// When the last click's taps stop counting.
  int get endMs => (firstClickMs + (totalClicks - .5) * beatMs).round();

  final List<int> _deltasMs = [];

  /// How each counted tap landed, after the nearest click, in milliseconds.
  List<int> get deltasMs => List.unmodifiable(_deltasMs);

  /// Taps during the count-in, or past the end, are ignored.
  void tap(int judgedMs) {
    final index = ((judgedMs - firstClickMs) / beatMs).round();
    if (index < countInClicks || index >= totalClicks) return;
    _deltasMs.add(judgedMs - (firstClickMs + index * beatMs).round());
  }

  /// The taps kept: those within [outlierMs] of the median of them all.
  List<int> get kept {
    if (_deltasMs.isEmpty) return const [];
    final middle = _median(_deltasMs);
    return [
      for (final d in _deltasMs)
        if ((d - middle).abs() <= outlierMs) d,
    ];
  }

  /// The offset to save, positive when taps land late. Null until enough taps
  /// agree.
  int? get offsetMs {
    final good = kept;
    if (good.length < minimumTaps) return null;
    return _median(good).round().clamp(-maxOffsetMs, maxOffsetMs);
  }

  static double _median(List<int> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid].toDouble()
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }
}

/// A correction from play itself: at a phrase's end, if the player's taps sat
/// steadily off by more than [thresholdMs], judging moves toward them, capped
/// like the tap-along. On while the player hasn't calibrated.
class AutoNudge {
  /// A phrase whose median sits closer than this moves nothing: that's the
  /// player's own wobble, not the device.
  static const thresholdMs = 30;

  /// As far as the tap-along may go. Was 60, which left any phone more than
  /// 60 ms off the browser's estimate (Bluetooth adds 150 to 300) reading late
  /// for the whole run.
  static const capMs = SyncCalibration.maxOffsetMs;
  static const minimumTaps = 4;

  int offsetMs = 0;
  bool _moved = false;

  /// Feeds one phrase's signed tap deltas (positive is late), hits and near
  /// misses alike: a phone far enough off misses most notes, and its misses
  /// are the evidence. The first move takes the whole median, since a device
  /// offset is there from the first phrase; later ones take half, so one
  /// sloppy phrase can't swing it. Returns the new offset.
  int phrase(List<int> deltasMs) {
    if (deltasMs.length < minimumTaps) return offsetMs;
    final middle = SyncCalibration._median(deltasMs);
    if (middle.abs() <= thresholdMs) return offsetMs;
    final step = _moved ? (middle / 2).round() : middle.round();
    _moved = true;
    offsetMs = math.max(-capMs, math.min(capMs, offsetMs + step));
    return offsetMs;
  }
}
