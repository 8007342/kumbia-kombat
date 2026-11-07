import '../music/transport.dart';
import 'garden_session.dart';
import 'gesture_shapes.dart';
import 'rhythm.dart';
import 'touch_gesture.dart';

/// The AutoPlay button's three states, in the order a press moves through them.
enum AutoplayMode {
  off,

  /// Deliberately imperfect, so it shows a partly engaged room.
  withErrors,

  /// Every note on time and every offered move, so the owner can watch what a
  /// flawless run earns.
  flawless,
}

/// The pointer AutoPlay's thumb uses. Real pointers are never negative.
const autoplayPointer = -1;

/// A spectator mode. Every action uses normal judgment, and every move goes
/// through the same recogniser a thumb does. State is bounded to one response
/// and one stroke in the air.
class PartyAutoplay {
  PartyAutoplay({bool flawless = false, this.startFlawless = false})
    : _style = flawless ? AutoplayMode.flawless : AutoplayMode.withErrors;

  /// `?autoplay=flawless`: a press goes to flawless first.
  final bool startFlawless;
  AutoplayMode _style;
  bool _enabled = false;

  bool get enabled => _enabled;
  bool get flawless => _style == AutoplayMode.flawless;
  AutoplayMode get mode => _enabled ? _style : AutoplayMode.off;

  set enabled(bool value) {
    _enabled = value;
    if (!value) suspend();
  }

  set mode(AutoplayMode value) {
    if (value != AutoplayMode.off) _style = value;
    enabled = value != AutoplayMode.off;
  }

  /// Off, then on with errors, then flawless, then off again.
  AutoplayMode get nextMode => switch (mode) {
    AutoplayMode.off =>
      startFlawless ? AutoplayMode.flawless : AutoplayMode.withErrors,
    AutoplayMode.withErrors =>
      startFlawless ? AutoplayMode.off : AutoplayMode.flawless,
    AutoplayMode.flawless =>
      startFlawless ? AutoplayMode.withErrors : AutoplayMode.off,
  };

  GardenSession? _owner;
  int? _window;
  double? _responseBeat;
  int _responseOrdinal = -1;
  final Set<String> _attempted = {};
  _AutoStroke? _stroke;
  final _ownTouches = DanceTouchGestures();
  DanceTouchGestures? _strokeTouches;

  /// Pausing/off/doorways cancel future actions without changing game state.
  /// The resumed audio anchor identifies the replay as a fresh input window.
  void suspend() {
    _strokeTouches?.cancel(autoplayPointer);
    _stroke = null;
  }

  /// [touches] and [origin] let a host see the stroke: it draws the same trail a
  /// thumb leaves. Without them it still runs, for tests and headless shows.
  void pump(
    GardenSession session, {
    TapResult Function(Limb limb)? onTap,
    void Function(FlourishDirection direction)? onFlourish,
    void Function(OptionalMove move)? onMove,
    DanceTouchGestures? touches,
    (double, double) Function(RhythmNote note)? origin,
  }) {
    final transport = session.transport;
    if (!_enabled ||
        transport.state != TransportState.playing ||
        transport.countingIn) {
      suspend();
      return;
    }
    // Plays on the clock taps are judged by, as a player with a calibrated
    // phone would: its taps have no touch screen to cross.
    final now = session.judgedNowMs / 1000;
    // A stroke in the air outlives the turn, as a late thumb's does.
    _drawStroke(session, now, onFlourish, onMove);
    if (session.phase != GardenPhase.response) return;
    if (!identical(_owner, session)) {
      _owner = session;
      _window = null;
      _responseBeat = null;
      _responseOrdinal = -1;
      _attempted.clear();
      suspend();
    }

    final chart = session.chart;
    final cycle =
        ((session.positionBeats - chart.introBeats) / chart.cycleBeats).floor();
    final responseBeat =
        chart.introBeats + cycle * chart.cycleBeats + chart.callBeats;
    final window = (transport.secondsAt(responseBeat) * 1000).round();
    if (_window != window) {
      _window = window;
      _attempted.clear();
      if (_responseBeat != responseBeat) {
        _responseOrdinal++;
        _responseBeat = responseBeat;
      }
    }
    if (session.progress.cleared) return;

    // Two early setbacks let viewers see the crowd recover. Later responses
    // succeed consistently, so a demonstration cannot get stuck retrying.
    final failPhrase =
        !flawless && (_responseOrdinal == 2 || _responseOrdinal == 6);
    final dropCount = flawless
        ? 0
        : failPhrase
        ? session.stepCount - session.requiredHits + 1
        : _responseOrdinal % 3 == 1
        ? 1
        : 0;
    final dropped = <int>[
      for (final i in [1, 2, 4, 5, 0, 3, 6, 7])
        if (i < session.stepCount) i,
    ].take(dropCount).toSet();

    for (final cue in session.visibleCues.where((cue) => !cue.demo)) {
      final index = cue.index;
      final noteAt = transport.secondsAt(cue.beat);
      final key = '${(noteAt * 1000).round()}:${cue.id}';
      if (_attempted.contains(key)) continue;
      final offset = flawless || index == 0
          ? .025
          : const [.025, .105, -.09, .035][(index + _responseOrdinal) % 4];
      if (now < noteAt + offset) continue;
      _attempted.add(key);
      // Imperfect play drops whole steps, and now and then a richer step's second
      // press, which is what a real player would let go first.
      final secondPress = cue.move != null &&
          session.activeSteps.indexOf(cue.step) != index;
      if (dropped.contains(cue.step) ||
          (!flawless &&
              secondPress &&
              (_responseOrdinal + cue.step) % 3 == 0) ||
          now > noteAt + RhythmJudge.lateWindowMs / 1000) {
        continue;
      }
      final result = (onTap ?? session.tap)(cue.limb);
      final note = result.note;
      if (note?.flourishTo != null &&
          (flawless || (_responseOrdinal + index) % 4 != 0)) {
        _startStroke(note!, now, touches ?? _ownTouches, origin);
      }
    }
  }

  void _startStroke(
    RhythmNote note,
    double now,
    DanceTouchGestures touches,
    (double, double) Function(RhythmNote note)? origin,
  ) {
    suspend();
    _ownTouches.clear();
    final kind = note.offer ?? GestureKind.spin;
    final (x, y) = origin?.call(note) ?? (0.0, 0.0);
    _strokeTouches = touches;
    touches.begin(pointer: autoplayPointer, x: x, y: y, acceptedNote: note);
    _stroke = _AutoStroke(
      // Heading toward the screen's middle, as a thumb most comfortably would.
      idealStroke(
        kind,
        flip: note.limb == Limb.rightHand || note.limb == Limb.rightFoot,
      ),
      x,
      y,
      now,
      switch (kind) {
        GestureKind.spin || GestureKind.flick => .2,
        GestureKind.stomp => .34,
        GestureKind.wave => .36,
        GestureKind.circle => .6,
      },
      kind == GestureKind.spin ? 72 : 64,
    );
  }

  void _drawStroke(
    GardenSession session,
    double now,
    void Function(FlourishDirection direction)? onFlourish,
    void Function(OptionalMove move)? onMove,
  ) {
    final stroke = _stroke;
    final touches = _strokeTouches;
    if (stroke == null || touches == null) return;
    final done = now >= stroke.endsAt;
    DanceStrokeResult? result;
    while (result == null) {
      final (x, y, more) = stroke.next(now);
      if (!more) break;
      result = touches.move(pointer: autoplayPointer, x: x, y: y);
    }
    if (result == null && done) {
      result = touches.settle(autoplayPointer);
      _stroke = null;
    }
    if (result == null) return;
    _stroke = null;
    final move = landStroke(session, result);
    if (move != null) {
      onFlourish?.call(move.direction);
      onMove?.call(move);
    }
  }
}

/// AutoPlay's thumb: an ideal path, walked at a steady pace.
class _AutoStroke {
  _AutoStroke(this.path, this.x, this.y, this.startedAt, this.seconds, this.size);
  final List<(double, double)> path;
  final double x, y, startedAt, seconds, size;
  int _next = 1;
  double get endsAt => startedAt + seconds;

  /// The next point due by [now], with false when none is.
  (double, double, bool) next(double now) {
    if (_next >= path.length) return (0, 0, false);
    final due = startedAt + seconds * _next / (path.length - 1);
    if (now < due) return (0, 0, false);
    final (px, py) = path[_next++];
    return (x + px * size, y + py * size, true);
  }
}
