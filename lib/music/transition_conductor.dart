import 'dart:math' as math;
import 'score.dart';
import 'transport.dart';

enum ConductorState { idle, playing, paused, completed }

/// Live timing handles: getters follow any coordinated pause/resume shift.
class MusicHandoff {
  MusicHandoff._(this.source, this.success, this.bridge, this.nextTransport);
  final MusicTransport source;
  final MusicTransport success;
  final MusicTransport bridge;
  final MusicTransport nextTransport;
  double get exitAtSeconds => source.retirementSeconds;
  double get bridgeAtSeconds => bridge.secondsAt(0);
  double get nextAtSeconds => nextTransport.secondsAt(0);
}

class MusicFinish {
  MusicFinish._(this.source, this.success);
  final MusicTransport source;
  final MusicTransport success;
  double get exitAtSeconds => source.retirementSeconds;
  double get endAtSeconds => success.secondsAt(success.score.lengthBeats);
}

/// One owner pumps every segment sharing a device clock. Musical handoffs never
/// call silence; only explicit pause, recovery, stop or external device loss do.
/// Preload scores before calling handoff so resource loading cannot insert gaps.
class TransitionConductor {
  TransitionConductor(
    this.backend, {
    this.lookaheadSeconds = .12,
    this.starvationGraceSeconds = .025,
  }) {
    if (!lookaheadSeconds.isFinite || lookaheadSeconds <= 0) {
      throw ArgumentError.value(lookaheadSeconds, 'lookaheadSeconds');
    }
    if (!starvationGraceSeconds.isFinite || starvationGraceSeconds < 0) {
      throw ArgumentError.value(
        starvationGraceSeconds,
        'starvationGraceSeconds',
      );
    }
  }
  final MusicAudioBackend backend;
  final double lookaheadSeconds;
  final double starvationGraceSeconds;
  List<MusicTransport> _transports = [];
  ConductorState _state = ConductorState.idle;
  double _pausedAtSeconds = 0;

  ConductorState get state => _state;
  bool get isPlaying => state == ConductorState.playing;
  bool get isPaused => state == ConductorState.paused;
  bool get completed => state == ConductorState.completed;

  MusicHandoff handoff({
    required MusicTransport source,
    required MusicScore success,
    required MusicScore bridge,
    required MusicScore nextScore,
    int nextTier = 0,
  }) {
    _checkSource(source);
    if (nextTier < 0 || nextTier > 4) {
      throw RangeError.range(nextTier, 0, 4, 'nextTier');
    }
    final exitBeat = source.nextPhraseBoundaryBeat;
    final exitAt = source.secondsAt(exitBeat);
    final tier = source.tierAt(exitBeat);
    final successTransport = _segment(success);
    final bridgeTransport = _segment(bridge);
    final nextTransport = _segment(nextScore, loop: true);
    // Retirement is set before successor notes enter the common device queue.
    source.retireAt(exitAt);
    successTransport.startAt(exitAt, tier: tier);
    final bridgeAt = successTransport.secondsAt(success.lengthBeats);
    bridgeTransport.startAt(bridgeAt);
    final nextAt = bridgeTransport.secondsAt(bridge.lengthBeats);
    nextTransport.startAt(nextAt, tier: nextTier);
    _transports = [source, successTransport, bridgeTransport, nextTransport];
    _state = ConductorState.playing;
    return MusicHandoff._(
      source,
      successTransport,
      bridgeTransport,
      nextTransport,
    );
  }

  MusicFinish finish({
    required MusicTransport source,
    required MusicScore success,
  }) {
    _checkSource(source);
    final exitBeat = source.nextPhraseBoundaryBeat;
    final exitAt = source.secondsAt(exitBeat);
    final tier = source.tierAt(exitBeat);
    final successTransport = _segment(success);
    source.retireAt(exitAt);
    successTransport.startAt(exitAt, tier: tier);
    _transports = [source, successTransport];
    _state = ConductorState.playing;
    return MusicFinish._(source, successTransport);
  }

  MusicTransport _segment(MusicScore score, {bool loop = false}) =>
      MusicTransport(
        score,
        backend,
        loop: loop,
        silenceOnCompletion: false,
        lookaheadSeconds: lookaheadSeconds,
        starvationGraceSeconds: starvationGraceSeconds,
      );

  void _checkSource(MusicTransport source) {
    if (!identical(source.backend, backend)) {
      throw ArgumentError('Source must share the conductor audio backend');
    }
    if (!backend.ready ||
        source.state != TransportState.playing ||
        source.countingIn) {
      throw StateError('Source must be audibly playing before a handoff');
    }
    if (_state == ConductorState.paused) {
      throw StateError('Resume before requesting a handoff');
    }
    // Reuse after the prior destination starts is intentional. Retired decks are
    // discarded without stopping the common backend or the running destination.
    if (_transports.isNotEmpty &&
        !identical(source, _transports.last) &&
        isPlaying) {
      throw StateError('A handoff is already in progress');
    }
  }

  void pump() {
    if (!isPlaying) return;
    if (!backend.ready) {
      pause();
      return;
    }
    final now = backend.nowSeconds;
    var safeTime = now;
    var starved = false;
    for (final transport in _transports) {
      if (transport.state != TransportState.playing || transport.countingIn) {
        continue;
      }
      if (now > transport.scheduledThroughSeconds + starvationGraceSeconds) {
        safeTime = math.min(safeTime, transport.scheduledThroughSeconds);
        starved = true;
      }
    }
    if (starved) {
      _pauseAt(safeTime);
      return;
    }
    for (final transport in _transports) {
      transport.pump();
    }
    if (_transports.every(
      (transport) => transport.state == TransportState.completed,
    )) {
      _state = ConductorState.completed;
    }
  }

  void _pauseAt(double seconds) {
    _pausedAtSeconds = seconds;
    // One cancellation flushes every deck, including notes queued for a future
    // success/bridge/destination. Each transport stores its own relative position.
    backend.silence();
    for (final transport in _transports) {
      transport.pauseAtDeviceTime(seconds, silence: false);
    }
    _state = ConductorState.paused;
  }

  void pause() {
    if (!isPlaying) return;
    _pauseAt(backend.nowSeconds);
  }

  void resume({double leadSeconds = 2}) {
    if (!isPaused) throw StateError('Conductor is not paused');
    if (!leadSeconds.isFinite || leadSeconds < 0) {
      throw ArgumentError.value(leadSeconds, 'leadSeconds');
    }
    if (!backend.ready) throw StateError('Audio requires user activation');
    final resumeAt = backend.nowSeconds + leadSeconds;
    for (final transport in _transports) {
      if (transport.state != TransportState.paused) continue;
      final originalAnchor = transport.secondsAt(transport.positionBeats);
      final remainingLead = math.max(0.0, originalAnchor - _pausedAtSeconds);
      transport.resumeAt(resumeAt + remainingLead);
    }
    _state = ConductorState.playing;
  }

  void stop() {
    // Explicit stop is allowed to cancel the common queue.
    for (final transport in _transports) {
      transport.stop();
    }
    _transports = [];
    _state = ConductorState.idle;
  }
}
