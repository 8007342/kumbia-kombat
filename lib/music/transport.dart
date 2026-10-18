import 'dart:math' as math;
import 'score.dart';

/// Audio device/context time is the sole transport authority. Implementations
/// synthesize voices; MIDI files and pre-rendered stems are not runtime clocks.
abstract interface class MusicAudioBackend {
  double get nowSeconds;
  bool get ready;

  /// Schedule both attack and release on the backend's audio timeline.
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
/// The backend must schedule at sample accuracy inside a 120 ms lookahead.
class MusicTransport {
  MusicTransport(this.score, this.backend, {this.lookaheadSeconds = .12}) {
    if (!lookaheadSeconds.isFinite || lookaheadSeconds <= 0) {
      throw ArgumentError.value(lookaheadSeconds, 'lookaheadSeconds');
    }
  }
  final MusicScore score;
  final MusicAudioBackend backend;
  final double lookaheadSeconds;
  final List<TempoSection> _sections = [];
  TransportState state = TransportState.stopped;
  double _cursorBeat = 0;
  double _pausedBeat = 0;
  double _scheduledUntilSeconds = 0;
  int _resumeTier = 0;
  int droppedNotes = 0;

  List<TempoSection> get sections => List.unmodifiable(_sections);
  double get positionBeats => state == TransportState.playing
      ? beatAt(
          backend.nowSeconds,
        ).clamp(_sections.first.beat, score.lengthBeats)
      : _pausedBeat;
  int get currentTier =>
      _sections.isEmpty ? _resumeTier : _sectionAtBeat(positionBeats).tier;

  TempoSection _sectionAtBeat(double beat) =>
      _sections.lastWhere((s) => s.beat <= beat, orElse: () => _sections.first);
  double secondsAt(double beat) {
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
    _pausedBeat = 0;
    droppedNotes = 0;
    _anchor(tier, leadSeconds);
  }

  void _anchor(int tier, double leadSeconds) {
    final startSeconds = backend.nowSeconds + leadSeconds;
    _sections
      ..clear()
      ..add(TempoSection(_pausedBeat, startSeconds, tier, score.tempos[tier]));
    _cursorBeat = _pausedBeat;
    _scheduledUntilSeconds = startSeconds;
    state = TransportState.playing;
    pump();
  }

  /// Returns the exact phrase boundary chosen. Changes never invalidate attacks
  /// already handed to the device. Repeated requests before that boundary coalesce.
  double requestTier(int tier) {
    _checkTier(tier);
    if (state != TransportState.playing) {
      throw StateError('Transport is not playing');
    }
    final committedBeat = math.max(positionBeats, _cursorBeat);
    final boundary =
        ((committedBeat / score.phraseBeats).floor() + 1) * score.phraseBeats;
    if (boundary >= score.lengthBeats) return score.lengthBeats;
    // Only pending sections beyond the scheduling horizon may be replaced.
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
    if (now >= secondsAt(score.lengthBeats)) {
      backend.silence();
      _pausedBeat = score.lengthBeats;
      state = TransportState.completed;
      return;
    }
    // A blocked UI or lost audio device must not create a late-note avalanche.
    if (now > _scheduledUntilSeconds + .025) {
      final safeBeat = beatAt(
        _scheduledUntilSeconds,
      ).clamp(0.0, score.lengthBeats).toDouble();
      pause();
      _pausedBeat = safeBeat;
      _resumeTier = _sectionAtBeat(safeBeat).tier;
      return;
    }
    final endBeat = beatAt(
      now + lookaheadSeconds,
    ).clamp(0.0, score.lengthBeats).toDouble();
    for (final note in score.notes) {
      if (note.beat < _cursorBeat) continue;
      if (note.beat >= endBeat) break;
      if (!note.audibleAt(_sectionAtBeat(note.beat).tier)) continue;
      final at = secondsAt(note.beat);
      if (at < now - .002) {
        droppedNotes++;
        continue;
      }
      backend.schedule(
        note,
        math.max(now, at),
        secondsAt(note.beat + note.duration) - at,
      );
    }
    _cursorBeat = math.max(_cursorBeat, endBeat);
    _scheduledUntilSeconds = math.max(
      _scheduledUntilSeconds,
      now + lookaheadSeconds,
    );
  }

  void pause() {
    if (state != TransportState.playing) return;
    _pausedBeat = positionBeats;
    _resumeTier = currentTier;
    backend.silence();
    state = TransportState.paused;
  }

  /// Host supplies a one-bar count-in and disables judgment until music resumes.
  /// Truncated held notes are not retriggered; the next authored attack resumes.
  void resume({double leadSeconds = 2}) {
    _checkLead(leadSeconds);
    if (state != TransportState.paused) {
      throw StateError('Transport is not paused');
    }
    if (!backend.ready) throw StateError('Audio requires user activation');
    _anchor(_resumeTier, leadSeconds);
  }

  void stop() {
    backend.silence();
    state = TransportState.stopped;
    _pausedBeat = 0;
    _sections.clear();
    _resumeTier = 0;
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
