import 'dart:math' as math;
import 'accent_voice.dart';
import 'game_audio_contract.dart';
import 'rendered_music.dart';
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
  const TempoSection(
    this.beat,
    this.seconds,
    this.tier,
    this.bpm, {
    this.clip,
    this.originBeat = 0,
    this.take,
    this.fadeInSeconds = RenderedLevel.defaultJoinSeconds,
  });
  final double beat;
  final double seconds;
  final int tier;
  final double bpm;

  /// The rendered audio under this section. Null means the synth plays the
  /// score's notes here, which is also what keeps a run alive after a failure.
  final RenderedClip? clip;

  /// The absolute beat at which [clip]'s first beat falls. A pure answer to
  /// where in the file any beat is, so pause and resume land by arithmetic.
  final double originBeat;

  /// The take this section is, or the one its transition is heading for.
  final String? take;
  final double fadeInSeconds;
}

/// What a transport plays when it plays rendered audio. Either a level's ladder
/// of takes or one clip, such as a success tag or a bridge.
class RenderedPlan {
  RenderedPlan.ladder(
    RenderedLevel this.level,
    this.deck, {
    this.entryBar = 0,
  }) : clip = null;
  RenderedPlan.single(RenderedClip this.clip, this.deck)
    : level = null,
      entryBar = 0;
  final RenderedLevel? level;
  final RenderedClip? clip;
  final ClipDeck deck;

  /// The bar of the first take that beat 0 lands on, as a bridge asks.
  final int entryBar;
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
    this.starvationGraceSeconds = .025,
    this.rendered,
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
  final MusicScore score;
  final MusicAudioBackend backend;
  final double lookaheadSeconds;
  final bool loop;
  final bool silenceOnCompletion;

  /// Absent, or with nothing decoded, this is the synth transport it always was.
  /// With it, the score's tempos should be the plan's, so that a fallback to the
  /// synth keeps every chart time.
  final RenderedPlan? rendered;
  ClipVoice? _voice;
  RenderedClip? _voiceClip;
  double _voiceOrigin = 0;
  double _voiceStartedAt = 0;
  int _clipCursor = 0;
  TempoSection? _resumeSection;

  /// How long the queue may run dry before the transport gives up and pauses.
  /// Inside this grace, notes whose time has passed are dropped, never played
  /// late, and music picks up again on the audio clock.
  final double starvationGraceSeconds;
  double _retireSeconds = double.infinity;
  final List<TempoSection> _sections = [];
  final List<TempoSection> _pendingSections = [];
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

  /// The tempo at the playhead, which during a transition is the transition's.
  double get currentBpm {
    if (_sections.isNotEmpty) return _sectionAtBeat(positionBeats).bpm;
    return _resumeSection?.bpm ?? score.tempos[_resumeTier];
  }

  /// The rendered clip at the playhead, or null while the synth is playing.
  RenderedClip? get currentClip => _sections.isEmpty
      ? _resumeSection?.clip
      : _sectionAtBeat(positionBeats).clip;

  /// When the sounding clip started, and at which beat its first beat falls.
  double get clipStartedAtSeconds => _voiceStartedAt;
  double get clipOriginBeat => _voiceOrigin;

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
    _resumeSection = null;
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
    // Ring-out belongs to clips that end by themselves; a loop stops on time.
    if (_voiceClip?.loops ?? false) _voice?.stopAt(atSeconds, fadeSeconds: .01);
  }

  /// A fresh section for [tier] at [beat], with the take if it is decoded.
  TempoSection _freshSection(int tier, double beat, double seconds) {
    final clip = _clipForTier(tier);
    return TempoSection(
      beat,
      seconds,
      tier,
      clip?.bpm ?? score.tempos[tier],
      clip: clip,
      originBeat: beat == 0 && clip != null
          ? -(rendered!.entryBar * clip.beatsPerBar).toDouble()
          : beat,
      take: clip == null ? null : rendered?.level?.tierTakes[tier],
    );
  }

  RenderedClip? _clipForTier(int tier) {
    final plan = rendered;
    if (plan == null) return null;
    final clip = plan.clip ?? plan.level!.takeForTier(tier);
    return plan.deck.clipReady(clip) ? clip : null;
  }

  void _anchorAt(int tier, double startSeconds) {
    final resume = _resumeSection;
    _resumeSection = null;
    _sections
      ..clear()
      ..add(
        resume == null
            ? _freshSection(tier, _pausedBeat, startSeconds)
            : TempoSection(
                _pausedBeat,
                startSeconds,
                tier,
                resume.bpm,
                clip: resume.clip,
                originBeat: resume.originBeat,
                take: resume.take,
              ),
      );
    for (final pending in _pendingSections) {
      _sections.add(_timed(pending, secondsAt(pending.beat)));
    }
    _pendingSections.clear();
    _cursorBeat = _pausedBeat;
    _scheduledUntilSeconds = startSeconds;
    _clipCursor = 0;
    _forgetVoice();
    state = TransportState.playing;
    pump();
  }

  TempoSection _timed(TempoSection section, double seconds) => TempoSection(
    section.beat,
    seconds,
    section.tier,
    section.bpm,
    clip: section.clip,
    originBeat: section.originBeat,
    take: section.take,
    fadeInSeconds: section.fadeInSeconds,
  );

  void _forgetVoice() {
    _voice = null;
    _voiceClip = null;
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
    var boundary =
        ((committedBeat / score.phraseBeats).floor() + 1) * score.phraseBeats;
    if (!loop && boundary >= score.lengthBeats) return score.lengthBeats;
    // A transition that has started finishes: its end decides the earliest join.
    final committedSeconds = math.max(
      secondsAt(committedBeat),
      _scheduledUntilSeconds,
    );
    for (final (i, section) in _sections.indexed) {
      final join = section.seconds <= committedSeconds &&
          section.clip != null &&
          !section.clip!.loops &&
          i + 1 < _sections.length;
      if (!join) continue;
      final end = _sections[i + 1].beat;
      if (end > boundary) {
        boundary = (end / score.phraseBeats).ceil() * score.phraseBeats;
      }
    }
    _sections.removeWhere((s) => s.beat >= boundary);
    final when = secondsAt(boundary);
    _sections.addAll(_tierChange(tier, boundary, when));
    return boundary;
  }

  /// The sections a tier change makes: the new tier's take, through its written
  /// transition if there is one, staying on what's playing if the take isn't
  /// decoded yet. The clock and the audio are planned here, together.
  List<TempoSection> _tierChange(int tier, double boundary, double when) {
    final level = rendered?.level;
    final previous = _sections.last;
    if (level == null) {
      return [TempoSection(boundary, when, tier, score.tempos[tier])];
    }
    final target = level.tierTakes[tier];
    final clip = level.takeForTier(tier);
    final deck = rendered!.deck;
    if (previous.take == target && previous.clip != null && previous.clip!.loops) {
      return [
        TempoSection(
          boundary,
          when,
          tier,
          previous.bpm,
          clip: previous.clip,
          originBeat: previous.originBeat,
          take: previous.take,
        ),
      ];
    }
    if (!deck.clipReady(clip)) {
      // Held, and pump tries again. On the synth that is the tier's tempo, and
      // on a take it is that take's: music and clock never disagree.
      return [
        TempoSection(
          boundary,
          when,
          tier,
          previous.clip == null ? score.tempos[tier] : previous.bpm,
          clip: previous.clip,
          originBeat: previous.originBeat,
          take: previous.take,
        ),
      ];
    }
    final from = previous.take;
    final join = from == null ? null : level.transition(from, target);
    if (join != null && deck.clipReady(join.clip)) {
      final landBeat = boundary + join.clip.lengthBeats;
      final landSeconds = when + join.clip.lengthSeconds;
      return [
        TempoSection(
          boundary,
          when,
          tier,
          join.clip.bpm,
          clip: join.clip,
          originBeat: boundary,
          take: target,
          fadeInSeconds: join.crossfadeSeconds,
        ),
        TempoSection(
          landBeat,
          landSeconds,
          tier,
          clip.bpm,
          clip: clip,
          originBeat: landBeat - join.entryBar * clip.beatsPerBar,
          take: target,
          fadeInSeconds: join.crossfadeSeconds,
        ),
      ];
    }
    return [
      TempoSection(
        boundary,
        when,
        tier,
        clip.bpm,
        clip: clip,
        originBeat: boundary,
        take: target,
      ),
    ];
  }

  /// Starts whatever rendered audio enters the queue before [horizon]. Native
  /// looping owns the seam, and each start is computed from the beat, so nothing
  /// accumulates. The outgoing clip's end is set at the same moment.
  void _pumpClips(double now, double horizon, double endSeconds) {
    final deck = rendered?.deck;
    if (deck == null) return;
    for (; _clipCursor < _sections.length; _clipCursor++) {
      final section = _sections[_clipCursor];
      if (section.seconds >= horizon || section.seconds >= endSeconds) return;
      final clip = section.clip;
      if (identical(clip, _voiceClip) && section.originBeat == _voiceOrigin) {
        continue;
      }
      final at = math.max(now, section.seconds);
      _voice?.stopAt(at, fadeSeconds: section.fadeInSeconds);
      _forgetVoice();
      if (clip == null) continue;
      if (at >= endSeconds) continue;
      final beat = beatAt(at);
      _voice = deck.playClip(
        clip,
        atSeconds: at,
        offsetSeconds: clip.fileSecondsAt(beat - section.originBeat),
        fadeInSeconds: section.fadeInSeconds,
      );
      _voiceClip = clip;
      _voiceOrigin = section.originBeat;
      _voiceStartedAt = at;
      if (clip.loops && _retireSeconds.isFinite) {
        _voice!.stopAt(_retireSeconds, fadeSeconds: .01);
      }
    }
  }

  /// A tier held back for a take still decoding moves on once the take is ready,
  /// at the next boundary like any other change.
  void _retryHeldTier() {
    final level = rendered?.level;
    if (level == null || _sections.isEmpty) return;
    final last = _sections.last;
    if (last.take == level.tierTakes[last.tier]) return;
    if (_clipForTier(last.tier) == null) return;
    requestTier(last.tier);
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
    if (now > _scheduledUntilSeconds + starvationGraceSeconds) {
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
    _retryHeldTier();
    _pumpClips(now, now + lookaheadSeconds, endSeconds);
    final firstLoop = loop ? (_cursorBeat / score.lengthBeats).floor() : 0;
    for (var iteration = firstLoop; ; iteration++) {
      final offset = iteration * score.lengthBeats;
      if (offset >= endBeat) break;
      for (final note in score.notes) {
        final beat = offset + note.beat;
        if (beat < _cursorBeat) continue;
        if (beat >= endBeat) break;
        final section = _sectionAtBeat(beat);
        if (!note.audibleAt(section.tier)) continue;
        // A take replaces the song's notes. A cue on the picture still sounds.
        if (section.clip != null && !isAccentTrack(note.track)) continue;
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
    final section = _sectionAtBeat(beat);
    _resumeTier = section.tier;
    _resumeSection = section;
    _pendingSections
      ..clear()
      ..addAll(_sections.where((s) => s.beat > beat));
    // Whoever calls without silence flushes the shared queue, voices included.
    _forgetVoice();
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
    final known = _sections.isEmpty ? _resumeSection : _sectionAtBeat(beat);
    backend.silence();
    _forgetVoice();
    _pausedBeat = beat;
    _resumeTier = targetTier;
    // Replaying inside the take that was playing keeps its place in the song;
    // landing on another take starts that take at this beat.
    final fresh = _freshSection(targetTier, beat, 0);
    final keepsPlace =
        known != null &&
        known.clip != null &&
        known.clip!.loops &&
        identical(known.clip, fresh.clip);
    _resumeSection = keepsPlace
        ? TempoSection(
            beat,
            0,
            targetTier,
            known.bpm,
            clip: known.clip,
            originBeat: known.originBeat,
            take: known.take,
          )
        : fresh;
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
    _forgetVoice();
    _resumeSection = null;
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
