import '../music/transport.dart';
import 'garden_session.dart';
import 'rhythm.dart';

/// A deliberately imperfect spectator mode. Every action uses normal judgment.
/// State is bounded to one response and one pending optional flick.
class PartyAutoplay {
  PartyAutoplay({this.flawless = false});

  /// Plays every note on time, so the owner can watch what a flawless run earns.
  /// The default stays imperfect on purpose, and so shows a partly engaged room.
  final bool flawless;
  bool _enabled = false;
  bool get enabled => _enabled;
  set enabled(bool value) {
    _enabled = value;
    if (!value) suspend();
  }

  GardenSession? _owner;
  int? _window;
  double? _responseBeat;
  int _responseOrdinal = -1;
  int _flourishes = 0;
  final Set<String> _attempted = {};
  _PendingFlick? _pending;

  /// Pausing/off/doorways cancel future actions without changing game state.
  /// The resumed audio anchor identifies the replay as a fresh input window.
  void suspend() => _pending = null;

  void pump(
    GardenSession session, {
    TapResult Function(Limb limb)? onTap,
    void Function(FlourishDirection direction)? onFlourish,
  }) {
    final transport = session.transport;
    if (!_enabled ||
        transport.state != TransportState.playing ||
        transport.countingIn ||
        session.phase != GardenPhase.response) {
      suspend();
      return;
    }
    if (!identical(_owner, session)) {
      _owner = session;
      _window = null;
      _responseBeat = null;
      _responseOrdinal = -1;
      _flourishes = 0;
      _attempted.clear();
      _pending = null;
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
      _pending = null;
      if (_responseBeat != responseBeat) {
        _responseOrdinal++;
        _responseBeat = responseBeat;
      }
    }

    final now = session.backend.nowSeconds;
    final pending = _pending;
    if (pending != null && now >= pending.atSeconds) {
      _pending = null;
      if (now <= pending.expiresAt &&
          session.flourishGesture(pending.noteId, pending.direction)) {
        _flourishes++;
        onFlourish?.call(pending.direction);
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
        ? session.activeLimbs.length - session.requiredHits + 1
        : _responseOrdinal % 3 == 1
        ? 1
        : 0;
    final dropped = <int>[
      for (final i in [1, 2, 4, 5, 0, 3, 6, 7])
        if (i < session.activeLimbs.length) i,
    ].take(dropCount).toSet();

    for (final cue in session.visibleCues.where((cue) => !cue.demo)) {
      final index = session.activeOffsets.indexWhere(
        (offset) => (responseBeat + offset - cue.beat).abs() < .00001,
      );
      if (index < 0) continue;
      final noteAt = transport.secondsAt(cue.beat);
      final key = '${(noteAt * 1000).round()}:${cue.id}';
      if (_attempted.contains(key)) continue;
      final offset = flawless || index == 0
          ? .025
          : const [.025, .105, -.09, .035][(index + _responseOrdinal) % 4];
      if (now < noteAt + offset) continue;
      _attempted.add(key);
      if (dropped.contains(index) ||
          now > noteAt + RhythmJudge.goodWindowMs / 1000) {
        continue;
      }
      final result = (onTap ?? session.tap)(cue.limb);
      if (result.note?.flourishTo != null &&
          (_responseOrdinal + index) % 4 != 0) {
        _pending = _PendingFlick(
          result.note!.id,
          FlourishDirection.values[_flourishes %
              FlourishDirection.values.length],
          now + .13,
          now + RhythmJudge.flourishWindowMs / 1000,
        );
      }
    }
  }
}

class _PendingFlick {
  const _PendingFlick(
    this.noteId,
    this.direction,
    this.atSeconds,
    this.expiresAt,
  );
  final String noteId;
  final FlourishDirection direction;
  final double atSeconds;
  final double expiresAt;
}
