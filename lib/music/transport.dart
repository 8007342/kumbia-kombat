import 'dart:math' as math;
import 'score.dart';

/// Audio device/context time is the sole transport authority. Implementations
/// synthesize voices; MIDI files and pre-rendered stems are not runtime clocks.
abstract interface class MusicAudioBackend {
  double get nowSeconds;
  bool get ready;

  /// Schedule both attack and release on the backend's audio timeline.
  /// The note's beat is local to its score; atSeconds is authoritative in loops.
  void schedule(ScoreNote note, double atSeconds, double durationSeconds);

  /// Cancel queued attacks and release all sounding voices (short clickless fade).
  void silence();
}

enum TransportState { stopped, playing, paused, completed }

class TempoSection {
  const TempoSection(this.beat, this.seconds, this.tier, this.bpm);
  final double beat;
  final double seconds;
  final int tier;
  final double bpm;
}

/// Call pump roughly every 20 ms; rendering frames never advance song time.
/// Looping repeats the complete authored form on an absolute beat timeline.
/// Explicit seek/restart may move that position backwards; ordinary loops do not.
class MusicTransport {
  MusicTransport(
    this.score,
    this.backend, {
    this.lookaheadSeconds = .12,
    this.loop = false,
    this.silenceOnCompletion = true,
  }) {
    if (!lookaheadSeconds.isFinite || lookaheadSeconds <= 0) {
      throw ArgumentError.value(lookaheadSeconds, 'lookaheadSeconds');
    }
  }
  final MusicScore score;
  final MusicAudioBackend backend;
  final double lookaheadSeconds;
  final bool loop;
  final bool silenceOnCompletion;
  double _retireSeconds = double.infinity;
  final List<TempoSection> _sections = [];
  final List<({double beat, int tier})> _pendingSections = [];
  TransportState state = TransportState.stopped;
  double _cursorBeat = 0;
  double _pausedBeat = 0;
  double _scheduledUntilSeconds = 0;
  int _resumeTier = 0;
  int droppedNotes = 0;

  List<TempoSection> get sections => List.unmodifiable(_sections);
  double get scheduledThroughSeconds => _scheduledUntilSeconds;
  double get retirementSeconds => _retireSeconds;
  double get nextPhraseBoundaryBeat =>
      ((math.max(positionBeats, _cursorBeat) / score.phraseBeats).floor() + 1) *
      score.phraseBeats;
  int tierAt(double beat) => _sectionAtBeat(beat).tier;
  double get positionBeats => state == TransportState.playing
      ? _boundedBeat(math.max(_sections.first.beat, beatAt(backend.nowSeconds)))
      : _pausedBeat;
  double get scorePositionBeats =>
      loop ? positionBeats % score.lengthBeats : positionBeats;
  int get currentTier =>
      _sections.isEmpty ? _resumeTier : _sectionAtBeat(positionBeats).tier;

  /// Judgment stays disabled while a start/resume anchor is still in the future.
  bool get countingIn =>
      state == TransportState.playing &&
      backend.nowSeconds < _sections.first.seconds;

  double _boundedBeat(double beat) => loop
      ? math.max(0.0, beat)
      : beat.clamp(0.0, score.lengthBeats).toDouble();
  TempoSection _sectionAtBeat(double beat) =>
      _sections.lastWhere((s) => s.beat <= beat, orElse: () => _sections.first);
  double secondsAt(double beat) {
    if (_sections.isEmpty) throw StateError('Transport has no audio anchor');
    final section = _sectionAtBeat(beat);
    return section.seconds + (beat - section.beat) * 60 / section.bpm;
  }

  double beatAt(double seconds) {
    if (_sections.isEmpty) return _pausedBeat;
    final section = _sections.lastWhere(
      (s) => s.seconds <= seconds,
      orElse: () => _sections.first,
    );
    return section.beat + (seconds - section.seconds) * section.bpm / 60;
  }

  void start({int tier = 0, double leadSeconds = .12}) {
    _checkTier(tier);
    _checkLead(leadSeconds);
    if (!backend.ready) throw StateError('Audio requires user activation');
    backend.silence();
    state = TransportState.stopped;
    startAt(backend.nowSeconds + leadSeconds, tier: tier);
  }

  /// Join an existing audio timeline without silencing sibling transports.
  /// Callers must retire the previous owner before handing over this backend.
  void startAt(double atSeconds, {int tier = 0}) {
    _checkTier(tier);
    _checkDeviceTime(atSeconds);
    if (!backend.ready) throw StateError('Audio requires user activation');
    if (state == TransportState.playing || state == TransportState.paused) {
      throw StateError('startAt requires a fresh or completed transport');
    }
    _pausedBeat = 0;
    _retireSeconds = double.infinity;
    _pendingSections.clear();
    droppedNotes = 0;
    _anchorAt(tier, atSeconds);
  }

  /// End this transport at an exact uncommitted device time. Retirement never
  /// invokes backend.silence: successor notes may already share the queue.
  void retireAt(double atSeconds) {
    if (state != TransportState.playing) {
      throw StateError('Transport is not playing');
    }
    if (!atSeconds.isFinite ||
        atSeconds < math.max(backend.nowSeconds, _scheduledUntilSeconds)) {
      throw ArgumentError.value(
        atSeconds,
        'atSeconds',
        'Retirement must follow committed audio',
      );
    }
    _retireSeconds = atSeconds;
  }

  void _anchorAt(int tier, double startSeconds) {
    _sections
      ..clear()
      ..add(TempoSection(_pausedBeat, startSeconds, tier, score.tempos[tier]));
    for (final pending in _pendingSections) {
      final when = secondsAt(pending.beat);
      _sections.add(
        TempoSection(
          pending.beat,
          when,
          pending.tier,
          score.tempos[pending.tier],
        ),
      );
    }
    _pendingSections.clear();
    _cursorBeat = _pausedBeat;
    _scheduledUntilSeconds = startSeconds;
    state = TransportState.playing;
    pump();
  }

  /// Returns an absolute phrase boundary, including boundaries in future loops.
  /// Changes never invalidate attacks already handed to the device. Repeated
  /// requests before that boundary coalesce to the latest intent.
  double requestTier(int tier) {
    _checkTier(tier);
    if (state != TransportState.playing) {
      throw StateError('Transport is not playing');
    }
    final committedBeat = math.max(positionBeats, _cursorBeat);
    final boundary =
        ((committedBeat / score.phraseBeats).floor() + 1) * score.phraseBeats;
    if (!loop && boundary >= score.lengthBeats) return score.lengthBeats;
    _sections.removeWhere((s) => s.beat >= boundary);
    final when = secondsAt(boundary);
    _sections.add(TempoSection(boundary, when, tier, score.tempos[tier]));
    return boundary;
  }

  void pump() {
    if (state != TransportState.playing) return;
    final now = backend.nowSeconds;
    if (!backend.ready) {
      pause();
      return;
    }
    final endSeconds = math.min(
      _retireSeconds,
      loop ? double.infinity : secondsAt(score.lengthBeats),
    );
    if (now >= endSeconds) {
      if (!_retireSeconds.isFinite && silenceOnCompletion) backend.silence();
      _pausedBeat = _boundedBeat(beatAt(endSeconds));
      state = TransportState.completed;
      return;
    }
    // A blocked UI or lost audio device must not create a late-note avalanche.
    if (now > _scheduledUntilSeconds + .025) {
      _pauseAt(
        _boundedBeat(
          math.max(_sections.first.beat, beatAt(_scheduledUntilSeconds)),
        ),
      );
      return;
    }
    final endBeat = _boundedBeat(
      beatAt(math.min(now + lookaheadSeconds, endSeconds)),
    );
    final firstLoop = loop ? (_cursorBeat / score.lengthBeats).floor() : 0;
    for (var iteration = firstLoop; ; iteration++) {
      final offset = iteration * score.lengthBeats;
      if (offset >= endBeat) break;
      for (final note in score.notes) {
        final beat = offset + note.beat;
        if (beat < _cursorBeat) continue;
        if (beat >= endBeat) break;
        if (!note.audibleAt(_sectionAtBeat(beat).tier)) continue;
        final at = secondsAt(beat);
        // Beat/second inversion can put the exclusive loop endpoint a few
        // floating-point ulps inside endBeat. Device time owns the boundary.
        if (at >= endSeconds - 1e-9) continue;
        if (at < now - .002) {
          droppedNotes++;
          continue;
        }
        final scheduledStart = math.max(now, at);
        final release = math.min(secondsAt(beat + note.duration), endSeconds);
        final duration = release - scheduledStart;
        if (duration <= 0) {
          droppedNotes++;
          continue;
        }
        backend.schedule(note, scheduledStart, duration);
      }
      if (!loop) break;
    }
    _cursorBeat = math.max(_cursorBeat, endBeat);
    _scheduledUntilSeconds = math.max(
      _scheduledUntilSeconds,
      math.min(now + lookaheadSeconds, endSeconds),
    );
  }

  void _pauseAt(double beat, {bool silence = true}) {
    _pausedBeat = beat;
    _resumeTier = _sectionAtBeat(beat).tier;
    _pendingSections
      ..clear()
      ..addAll(
        _sections
            .where((s) => s.beat > beat)
            .map((s) => (beat: s.beat, tier: s.tier)),
      );
    if (silence) backend.silence();
    state = TransportState.paused;
  }

  /// Coordinate a shared-backend pause at a common safe audio checkpoint.
  void pauseAtDeviceTime(double seconds, {bool silence = true}) {
    if (state != TransportState.playing) return;
    if (!seconds.isFinite || seconds > backend.nowSeconds) {
      throw ArgumentError.value(seconds, 'seconds');
    }
    _pauseAt(
      _boundedBeat(
        math.max(
          _sections.first.beat,
          beatAt(math.min(seconds, _retireSeconds)),
        ),
      ),
      silence: silence,
    );
  }

  void pause() {
    if (state != TransportState.playing) return;
    _pauseAt(positionBeats);
  }

  /// Cancel audio and move to an explicit absolute beat, leaving playback paused.
  /// Seeking clears pending tier changes. Supply a tier to restore a gameplay
  /// checkpoint; otherwise the target beat's known tier is used.
  void seek(double beat, {int? tier}) {
    if (!beat.isFinite || beat < 0 || (!loop && beat > score.lengthBeats)) {
      throw ArgumentError.value(beat, 'beat');
    }
    if (tier != null) _checkTier(tier);
    final targetTier =
        tier ?? (_sections.isEmpty ? _resumeTier : _sectionAtBeat(beat).tier);
    backend.silence();
    _pausedBeat = beat;
    _resumeTier = targetTier;
    _cursorBeat = beat;
    _retireSeconds = double.infinity;
    _sections.clear();
    _pendingSections.clear();
    state = TransportState.paused;
  }

  /// Replay the current absolute phrase with a new count-in. This is an explicit
  /// gameplay checkpoint rewind, not the automatic looping behavior.
  void restartPhrase({int? tier, double leadSeconds = 2}) {
    _checkLead(leadSeconds);
    if (tier != null) _checkTier(tier);
    if (!backend.ready) throw StateError('Audio requires user activation');
    final phraseBeat =
        (positionBeats / score.phraseBeats).floor() * score.phraseBeats;
    seek(phraseBeat, tier: tier ?? currentTier);
    resume(leadSeconds: leadSeconds);
  }

  /// Host supplies a one-bar count-in and disables judgment until music resumes.
  /// Truncated held notes are not retriggered; the next authored attack resumes.
  void resume({double leadSeconds = 2}) {
    _checkLead(leadSeconds);
    if (state != TransportState.paused) {
      throw StateError('Transport is not paused');
    }
    if (!backend.ready) throw StateError('Audio requires user activation');
    resumeAt(backend.nowSeconds + leadSeconds);
  }

  /// Resume at an exact audio time, preserving any planned retirement offset.
  void resumeAt(double atSeconds) {
    _checkDeviceTime(atSeconds);
    if (state != TransportState.paused) {
      throw StateError('Transport is not paused');
    }
    if (!backend.ready) throw StateError('Audio requires user activation');
    final retirementOffset = _retireSeconds.isFinite
        ? _retireSeconds - secondsAt(_pausedBeat)
        : double.infinity;
    _retireSeconds = atSeconds + retirementOffset;
    _anchorAt(_resumeTier, atSeconds);
  }

  void stop() {
    backend.silence();
    state = TransportState.stopped;
    _pausedBeat = 0;
    _sections.clear();
    _pendingSections.clear();
    _resumeTier = 0;
    _retireSeconds = double.infinity;
  }

  void _checkDeviceTime(double value) {
    if (!value.isFinite || value < backend.nowSeconds) {
      throw ArgumentError.value(
        value,
        'atSeconds',
        'Audio start cannot be in the past',
      );
    }
  }

  void _checkTier(int tier) {
    if (tier < 0 || tier >= score.tempos.length) {
      throw RangeError.range(tier, 0, 4, 'tier');
    }
  }

  void _checkLead(double value) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(value, 'leadSeconds');
    }
  }
}
