import '../music/transport.dart';
import 'crowd_interest.dart';
import 'gesture_shapes.dart';
import 'progression.dart';
import 'rhythm.dart';

enum GardenPhase { ready, intro, call, response, paused, cleared }

/// What a note invites after its tap. A sideways drag everywhere at first, and
/// from tier 1 a phrase's last note, the only one with room for a longer shape,
/// asks for its limb's own move: a hand waves, a foot stomps. A full circle comes
/// last. Each is only an invitation: any move drawn on any eligible note counts.
GestureKind gestureOffer({
  required Limb limb,
  required bool lastNote,
  required int tier,
}) {
  if (!lastNote || tier == 0) return GestureKind.spin;
  if (limb == Limb.leftFoot || limb == Limb.rightFoot) return GestureKind.stomp;
  return tier >= 3 ? GestureKind.circle : GestureKind.wave;
}

/// How long a phrase's last note leaves for its move, in beats from the press,
/// so a fast room isn't harder than the shape asks. Mid-phrase notes get
/// [RhythmJudge.flourishWindowMs], which their clearance rule was built around.
const lastNoteMoveBeats = 2.0;
const lastNoteCircleBeats = 2.5;

/// A stroke judged on the frame after its deadline still counts: its points came
/// in time, and a stalled frame isn't the player's fault.
const moveDeadlineGraceMs = 100;

/// An optional move that landed. This is the hook for anything that reacts to
/// one, such as a partner on the floor: read [GardenSession.lastOptionalMove].
/// Nothing here feeds back into notes, timing or clearing.
class OptionalMove {
  const OptionalMove({
    required this.noteId,
    required this.limb,
    required this.kind,
    required this.offered,
    required this.direction,
    required this.beat,
    required this.credited,
  });
  final String noteId;
  final Limb limb;

  /// What the thumb actually drew.
  final GestureKind kind;

  /// What the note invited. It may differ from [kind]; both count.
  final GestureKind? offered;

  /// Which way it went: picks the ornament and the look.
  final FlourishDirection direction;

  /// When it landed, on the transport's beat.
  final double beat;

  /// False when this exact performance was already paid for, as after a pause.
  final bool credited;
}

/// One accepted tap's chance at a move. It outlives the judge, because at speed
/// a late tap's move can still be in the air when the phrase rolls over.
class _OpenMove {
  _OpenMove(
    this.limb,
    this.offered,
    this.tappedMs,
    this.endsMs,
    this.sequence,
    this.creditKey,
  );
  final Limb limb;
  final GestureKind? offered;
  final int tappedMs;
  final int endsMs;
  final int sequence;
  final String creditKey;
  bool landed = false;
}

class GardenCue {
  const GardenCue({
    required this.id,
    required this.limb,
    required this.beat,
    required this.progress,
    required this.demonstration,
    this.flourishTo,
    this.offer,
  });
  final String id;
  final Limb limb;
  final double beat;
  final double progress;
  final bool demonstration;
  bool get demo => demonstration;
  final Limb? flourishTo;

  /// The move this note invites: what its glyph draws.
  final GestureKind? offer;
}

/// Two-bar demonstrations and responses. Bar currently runs about 90–95 s
/// for ten clean responses; its 80 s design budget remains a tuning target.
class FightChart {
  const FightChart({
    required this.limbs,
    required this.offsets,
    this.callBeats = 8,
    this.introBeats = 4,
    this.flourishDestination = Limb.rightFoot,
    this.variants = const [],
  });
  final List<Limb> limbs;
  final List<double> offsets;
  final double callBeats;
  final double introBeats;
  final Limb flourishDestination;
  final List<List<Limb>> variants;
  List<Limb> limbsFor(int tier, int peakPhrase) => variants.isEmpty || tier == 0
      ? limbs
      : variants[(tier == 4 ? 3 + peakPhrase : tier - 1) % variants.length];
  double get cycleBeats => callBeats * 2;

  void validate() {
    if (limbs.isEmpty ||
        limbs.length != offsets.length ||
        callBeats <= 0 ||
        introBeats < 0 ||
        !callBeats.isFinite ||
        !introBeats.isFinite) {
      throw ArgumentError('Invalid fight chart');
    }
    var previous = -1.0;
    for (final offset in offsets) {
      if (!offset.isFinite ||
          offset < 0 ||
          offset <= previous ||
          offset >= callBeats) {
        throw ArgumentError('Invalid chart offsets');
      }
      previous = offset;
    }
    if (variants.any((pattern) => pattern.length != limbs.length)) {
      throw ArgumentError('Chart variants must preserve note count');
    }
  }

  /// Frozen reference for `levels/garden.json`, which is what the game plays.
  static const garden = FightChart(
    limbs: [
      Limb.leftHand,
      Limb.rightHand,
      Limb.leftHand,
      Limb.leftHand,
      Limb.leftFoot,
      Limb.rightFoot,
      Limb.rightHand,
      Limb.leftHand,
    ],
    offsets: [0, 1, 2, 2.5, 4, 5, 6, 6.5],
    variants: [
      [
        Limb.leftFoot,
        Limb.rightFoot,
        Limb.leftHand,
        Limb.rightHand,
        Limb.leftFoot,
        Limb.rightFoot,
        Limb.rightHand,
        Limb.leftHand,
      ],
      [
        Limb.rightHand,
        Limb.leftFoot,
        Limb.leftHand,
        Limb.rightFoot,
        Limb.rightHand,
        Limb.leftHand,
        Limb.leftFoot,
        Limb.rightFoot,
      ],
      [
        Limb.leftHand,
        Limb.rightHand,
        Limb.rightFoot,
        Limb.leftFoot,
        Limb.rightHand,
        Limb.leftHand,
        Limb.leftFoot,
        Limb.rightFoot,
      ],
      [
        Limb.leftFoot,
        Limb.rightHand,
        Limb.rightFoot,
        Limb.leftHand,
        Limb.leftFoot,
        Limb.rightFoot,
        Limb.leftHand,
        Limb.rightHand,
      ],
      [
        Limb.rightHand,
        Limb.leftHand,
        Limb.leftFoot,
        Limb.rightFoot,
        Limb.leftHand,
        Limb.rightHand,
        Limb.rightFoot,
        Limb.leftFoot,
      ],
    ],
  );

  /// Frozen reference for `levels/bar.json`, which is what the game plays.
  static const bar = FightChart(
    flourishDestination: Limb.leftHand,
    limbs: [
      Limb.rightHand,
      Limb.leftHand,
      Limb.rightHand,
      Limb.rightFoot,
      Limb.leftFoot,
      Limb.rightHand,
      Limb.leftHand,
      Limb.rightFoot,
    ],
    offsets: [.5, 1, 2.25, 3, 4.5, 5.25, 6, 6.75],
    variants: [
      [
        Limb.rightFoot,
        Limb.leftFoot,
        Limb.rightHand,
        Limb.leftHand,
        Limb.rightFoot,
        Limb.leftHand,
        Limb.leftFoot,
        Limb.rightHand,
      ],
      [
        Limb.leftHand,
        Limb.rightFoot,
        Limb.rightHand,
        Limb.leftFoot,
        Limb.leftHand,
        Limb.rightHand,
        Limb.rightFoot,
        Limb.leftFoot,
      ],
      [
        Limb.rightHand,
        Limb.leftHand,
        Limb.leftFoot,
        Limb.rightFoot,
        Limb.leftHand,
        Limb.rightHand,
        Limb.rightFoot,
        Limb.leftFoot,
      ],
      [
        Limb.rightFoot,
        Limb.leftHand,
        Limb.leftFoot,
        Limb.rightHand,
        Limb.rightFoot,
        Limb.leftFoot,
        Limb.rightHand,
        Limb.leftHand,
      ],
      [
        Limb.leftHand,
        Limb.rightHand,
        Limb.rightFoot,
        Limb.leftFoot,
        Limb.rightHand,
        Limb.leftHand,
        Limb.leftFoot,
        Limb.rightFoot,
      ],
    ],
  );
}

/// Garden vertical-slice controller. All judgments read the audio clock.
/// Pump transport separately at 20 ms; call advance before painting/input.
class GardenSession {
  /// A demonstration between responses must not break an expressive chain.
  static const styleChainWindowBeats = 24;
  GardenSession(
    this.transport,
    this.backend, {
    FightDefinition? definition,
    this.chart = FightChart.garden,
    CrowdStageProfile? crowdProfile,
    int guestCount = CrowdInterestModel.castSize,
  }) : progress = FightProgress(definition ?? fights.first),
       crowd = CrowdInterestModel(
         rampPhrases: 4 * (definition ?? fights.first).successesPerTier,
         arcPhrases:
             4 * (definition ?? fights.first).successesPerTier +
             (definition ?? fights.first).finalChallenges,
         phraseBeats: chart.cycleBeats,
         guestCount: guestCount,
         profile:
             crowdProfile ??
             CrowdStageProfile.forRoom((definition ?? fights.first).id),
       ),
       _cycleStart = chart.introBeats {
    chart.validate();
    _activeLimbs = chart.limbs;
  }
  final MusicTransport transport;
  final MusicAudioBackend backend;
  final FightProgress progress;
  final FightChart chart;
  final CrowdInterestModel crowd;
  late List<Limb> _activeLimbs;
  List<Limb> get activeLimbs => _activeLimbs;
  List<double> get activeOffsets => chart.offsets;
  int get requiredHits => progress.definition.requiredHits(
    _activeLimbs.length,
    atPeak: _phraseTier == 4,
  );
  int get peakChallengesRemaining =>
      progress.definition.finalChallenges - progress.fullTierSuccesses;
  double lastStumbleBeat = -100;
  int lastStumbleGuest = 0;
  GardenPhase phase = GardenPhase.ready;
  TapGrade? lastGrade;
  TapTiming? lastTiming;
  int? lastDeltaMs;
  ChallengeOutcome? lastOutcome;
  double? lastOutcomeBeat;
  int pizazz = 0;
  int styleCombo = 0;
  String? _lastStyleMove;
  double _lastStyleBeat = -100;
  int perfects = 0;
  int combo = 0;
  int passedPhrases = 0;
  double? completedAtSeconds;
  double? completedAtBeat;
  double _cycleStart;
  RhythmJudge? _judge;
  bool _resolved = false;
  int _hits = 0;
  int _phrasePerfects = 0;
  int _phraseGestures = 0;
  final List<int> _phraseDeltasMs = [];
  int _responseTier = 0;
  int _phraseTier = 0;
  int _responseSequence = 0;

  /// Bumps only when the music reaches a new performance of a phrase, never for
  /// a pause's replay. A recovering player's retry is new; a replay isn't.
  int _performance = 0;
  final Map<String, _OpenMove> _openMoves = {};

  /// The latest optional move that landed, by touch, key or AutoPlay. Stable for
  /// anything that reacts to moves: compare it by identity each frame, and use
  /// [OptionalMove.limb] and [OptionalMove.kind]. Null again after a pause.
  OptionalMove? lastOptionalMove;
  CrowdCheckpoint? _crowdCheckpoint;
  final Set<String> _credited = {};
  final Set<String> _perfectCredited = {};
  final Set<String> _hit = {};
  String _phraseIdentity = '0:0';

  double get positionBeats => transport.positionBeats;
  double get callStartBeat => _cycleStart;
  double get phaseBeat => phase == GardenPhase.intro
      ? positionBeats
      : (positionBeats - _cycleStart) % chart.callBeats;
  bool get running =>
      phase != GardenPhase.ready &&
      phase != GardenPhase.paused &&
      phase != GardenPhase.cleared;
  int get _nowMs => (backend.nowSeconds * 1000).round();

  /// Set false when a musical bridge has already anchored this transport.
  void start({bool startTransport = true}) {
    if (phase != GardenPhase.ready) throw StateError('Garden already started');
    if (startTransport) {
      transport.start();
    } else if (transport.state != TransportState.playing) {
      throw StateError('Joining requires an already playing transport');
    }
    phase = GardenPhase.intro;
    _prepareCycle();
  }

  void _prepareCycle({bool newOccurrence = false}) {
    if (newOccurrence) _responseSequence++;
    _judge = null;
    _resolved = false;
    _hits = 0;
    _phrasePerfects = 0;
    _phraseGestures = 0;
    _phraseDeltasMs.clear();
    _hit.clear();
    _phraseTier = progress.tier;
    _activeLimbs = List.unmodifiable(
      chart.limbsFor(_phraseTier, progress.fullTierSuccesses),
    );
    _crowdCheckpoint = crowd.checkpoint();
    _phraseIdentity =
        '${progress.definition.id}:${progress.tier}:${progress.successesAtTier}:${progress.fullTierSuccesses}';
  }

  RhythmJudge _makeJudge() => RhythmJudge([
    for (var i = 0; i < _activeLimbs.length; i++)
      RhythmNote(
        '$_phraseIdentity:$i',
        _activeLimbs[i],
        (transport.secondsAt(_cycleStart + chart.callBeats + chart.offsets[i]) *
                1000)
            .round(),
        flourishTo: _flourishDestination(i),
        offer: _offerAt(i),
      ),
  ]);

  GestureKind? _offerAt(int index) => _flourishDestination(index) == null
      ? null
      : gestureOffer(
          limb: _activeLimbs[index],
          lastNote: index == _activeLimbs.length - 1,
          tier: _phraseTier,
        );

  Limb? _flourishDestination(int index) {
    if (index == _activeLimbs.length - 1) return chart.flourishDestination;
    final response = _cycleStart + chart.callBeats;
    final gapMs =
        (transport.secondsAt(response + chart.offsets[index + 1]) -
            transport.secondsAt(response + chart.offsets[index])) *
        1000;
    // Leave the full late tap + ornament + next early tap windows unobstructed.
    return gapMs >=
            2 * RhythmJudge.goodWindowMs + RhythmJudge.flourishWindowMs + 40
        ? chart.flourishDestination
        : null;
  }

  List<GardenCue> get visibleCues {
    if (phase == GardenPhase.ready ||
        phase == GardenPhase.paused ||
        phase == GardenPhase.cleared ||
        transport.countingIn) {
      return const [];
    }
    final beat = positionBeats;
    final cues = <GardenCue>[];
    for (final demonstration in [true, false]) {
      for (var i = 0; i < _activeLimbs.length; i++) {
        final target =
            _cycleStart +
            (demonstration ? 0 : chart.callBeats) +
            chart.offsets[i];
        final id = '$_phraseIdentity:$i';
        if (!demonstration && _hit.contains(id)) continue;
        if (beat >= target - 2 &&
            backend.nowSeconds <=
                transport.secondsAt(target) + RhythmJudge.goodWindowMs / 1000) {
          cues.add(
            GardenCue(
              id: id,
              limb: _activeLimbs[i],
              beat: target,
              progress: ((beat - target + 2) / 2).clamp(0, 1),
              demonstration: demonstration,
              flourishTo: _flourishDestination(i),
              offer: _offerAt(i),
            ),
          );
        }
      }
    }
    return cues;
  }

  void advance() {
    if (positionBeats - _lastStyleBeat > styleChainWindowBeats) styleCombo = 0;
    if (phase == GardenPhase.ready ||
        phase == GardenPhase.paused ||
        phase == GardenPhase.cleared) {
      return;
    }
    if (transport.state == TransportState.paused) {
      pause();
      return;
    }
    // The win is decided. At a fast tempo the last swipe's window outlasts the
    // phrase, so settle it here, before the next cycle can replace the judge.
    if (progress.cleared && _judge != null) {
      if (_nowMs >
          _judge!.notes.last.atMs +
              RhythmJudge.goodWindowMs +
              RhythmJudge.flourishWindowMs) {
        phase = GardenPhase.cleared;
      }
      return;
    }
    final beat = positionBeats;
    if (beat < chart.introBeats) {
      phase = GardenPhase.intro;
      return;
    }
    // A long interruption is replayed rather than auto-failing many phrases.
    if (beat >= _cycleStart + chart.cycleBeats * 2) {
      pause();
      return;
    }
    if (beat >= _cycleStart + chart.cycleBeats) {
      _cycleStart += chart.cycleBeats;
      _performance++;
      _prepareCycle(newOccurrence: true);
    }
    // Use the same millisecond precision as judgment. At a handoff the beat
    // inverse may be 11.99999999999 at the exact response timestamp.
    final responseAtMs =
        (transport.secondsAt(_cycleStart + chart.callBeats) * 1000).round();
    phase = _nowMs < responseAtMs ? GardenPhase.call : GardenPhase.response;
    if (phase != GardenPhase.response) return;
    if (_judge == null) {
      _responseTier = transport.currentTier;
      _judge = _makeJudge();
    }
    final judge = _judge!;
    if (judge.expire(_nowMs).isNotEmpty) {
      combo = 0;
    }
    if (!_resolved &&
        _nowMs > judge.notes.last.atMs + RhythmJudge.goodWindowMs) {
      _resolved = true;
      final passed = _hits >= requiredHits;
      // Full-arrangement sustain cannot score while its request is pending.
      if (passed && progress.tier == 4 && _responseTier < 4) return;
      lastOutcome = progress.resolve(passed: passed);
      if (passed) passedPhrases++;
      final resolvedBeat = transport.beatAt(
        (judge.notes.last.atMs + RhythmJudge.goodWindowMs) / 1000,
      );
      lastOutcomeBeat = resolvedBeat;
      crowd.resolvePhrase(
        sequence: _responseSequence,
        passed: passed,
        beat: resolvedBeat,
        cleared: progress.cleared,
        report: PhraseReport(
          notes: _activeLimbs.length,
          hits: _hits,
          perfects: _phrasePerfects,
          gestures: _phraseGestures,
          spreadMs: PhraseReport.spreadOf(_phraseDeltasMs),
        ),
      );
      if (!passed) {
        lastStumbleBeat = resolvedBeat;
        lastStumbleGuest = _responseSequence % crowd.guestCount;
      }
      _crowdCheckpoint = crowd.checkpoint();
      if (progress.cleared) {
        completedAtSeconds = backend.nowSeconds;
        completedAtBeat = positionBeats;
        // Required timing is frozen now. Keep the gesture surface alive until
        // the final optional swipe's complete (late-tap-inclusive) window ends.
        // The host then keeps pumping the groove through its musical bridge.
      } else {
        transport.requestTier(progress.tier);
      }
    }
  }

  TapResult tap(Limb limb) {
    advance();
    if (transport.countingIn) {
      return const TapResult(TapGrade.miss, null);
    }
    final firstResponseMs = phase == GardenPhase.call
        ? (transport.secondsAt(_cycleStart + chart.callBeats) * 1000).round()
        : 0;
    final earlyResponse =
        phase == GardenPhase.call &&
        _nowMs >= firstResponseMs - RhythmJudge.goodWindowMs &&
        _nowMs < firstResponseMs;
    if ((phase != GardenPhase.response && !earlyResponse) ||
        _resolved ||
        progress.cleared) {
      return const TapResult(TapGrade.miss, null);
    }
    if (_judge == null) {
      _responseTier = transport.currentTier;
      _judge = _makeJudge();
    }
    final result = _judge!.tap(limb, _nowMs);
    lastGrade = result.grade;
    lastTiming = result.timing;
    lastDeltaMs = result.deltaMs;
    if (result.note != null) {
      _hits++;
      combo++;
      _hit.add(result.note!.id);
      _phraseDeltasMs.add(result.deltaMs);
      _openMove(result.note!);
      if (result.grade == TapGrade.perfect) _phrasePerfects++;
      if (result.grade == TapGrade.perfect &&
          _perfectCredited.add(result.note!.id)) {
        perfects++;
      }
    }
    return result;
  }

  void _openMove(RhythmNote note) {
    _openMoves.removeWhere(
      (_, open) => _nowMs > open.endsMs + moveDeadlineGraceMs,
    );
    if (note.flourishTo == null) return;
    final last = identical(note, _judge!.notes.last);
    var windowMs = RhythmJudge.flourishWindowMs;
    if (last) {
      final beats = note.offer == GestureKind.circle
          ? lastNoteCircleBeats
          : lastNoteMoveBeats;
      final beat = transport.beatAt(note.atMs / 1000);
      final ms =
          ((transport.secondsAt(beat + beats) - transport.secondsAt(beat)) *
                  1000)
              .round();
      if (ms > windowMs) windowMs = ms;
    }
    _openMoves[note.id] = _OpenMove(
      note.limb,
      note.offer,
      _nowMs,
      _nowMs + windowMs,
      _responseSequence,
      '${progress.definition.id}:${note.id}:$_performance',
    );
  }

  /// When the note's chance at a move ends, in audio seconds, or null if none.
  double? moveEndsAt(String noteId) {
    final open = _openMoves[noteId];
    return open == null || open.landed ? null : open.endsMs / 1000;
  }

  /// The one route for every optional move: touch, keyboard and AutoPlay. Touches
  /// nothing a required note reads: not hits, combo, grades, tier or the clock.
  OptionalMove? optionalMove(
    String noteId,
    GestureKind kind,
    FlourishDirection direction,
  ) {
    if (phase == GardenPhase.ready ||
        phase == GardenPhase.paused ||
        transport.countingIn) {
      return null;
    }
    final open = _openMoves[noteId];
    if (open == null ||
        open.landed ||
        _nowMs <= open.tappedMs ||
        _nowMs > open.endsMs + moveDeadlineGraceMs) {
      return null;
    }
    open.landed = true;
    // Counted per phrase, so a replay rebuilds it from nothing and the crowd
    // can't be farmed; the Pizazz ledger below keeps its own stricter key.
    if (open.sequence == _responseSequence && !_resolved) {
      _phraseGestures++;
    } else if (crowd.gestureAfterPhrase(
      sequence: open.sequence,
      beat: positionBeats,
    )) {
      _crowdCheckpoint = crowd.checkpoint();
    }
    final credited = _credited.add(open.creditKey);
    if (credited) {
      pizazz += 100;
      final elapsed = positionBeats - _lastStyleBeat;
      final move = '${kind.name}:${direction.name}';
      final varied =
          _lastStyleMove != null &&
          move != _lastStyleMove &&
          elapsed >= 0 &&
          elapsed <= styleChainWindowBeats;
      styleCombo = varied ? (styleCombo + 1).clamp(1, 4) : 1;
      _lastStyleMove = move;
      _lastStyleBeat = positionBeats;
      crowd.adorn(
        open.sequence % crowd.guestCount,
        positionBeats,
        chain: styleCombo,
      );
    }
    return lastOptionalMove = OptionalMove(
      noteId: noteId,
      limb: open.limb,
      kind: kind,
      offered: open.offered,
      direction: direction,
      beat: positionBeats,
      credited: credited,
    );
  }

  /// A plain directional flick: sideways is a spin, and up or down the flick.
  /// This is what the arrow keys perform.
  bool flourishGesture(String noteId, FlourishDirection direction) =>
      optionalMove(
        noteId,
        direction == FlourishDirection.left ||
                direction == FlourishDirection.right
            ? GestureKind.spin
            : GestureKind.flick,
        direction,
      ) !=
      null;

  void pause() {
    if (phase == GardenPhase.ready ||
        phase == GardenPhase.cleared ||
        phase == GardenPhase.paused) {
      return;
    }
    final replayBeat = phase == GardenPhase.intro ? 0.0 : _cycleStart;
    transport.seek(replayBeat, tier: progress.tier);
    if (_crowdCheckpoint != null) crowd.restore(_crowdCheckpoint!);
    crowd.clearStyle();
    _prepareCycle(newOccurrence: _resolved);
    lastStumbleBeat = -100;
    styleCombo = 0;
    _lastStyleMove = null;
    _openMoves.clear();
    lastOptionalMove = null;
    _lastStyleBeat = -100;
    phase = GardenPhase.paused;
    combo = 0;
  }

  void resume() {
    if (phase != GardenPhase.paused) throw StateError('Garden is not paused');
    transport.resume(
      leadSeconds:
          transport.score.beatsPerBar * 60 / transport.currentBpm,
    );
    phase = positionBeats < chart.introBeats
        ? GardenPhase.intro
        : GardenPhase.call;
  }
}
