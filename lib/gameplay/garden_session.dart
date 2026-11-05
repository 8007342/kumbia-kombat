import '../music/transport.dart';
import 'crowd_interest.dart';
import 'progression.dart';
import 'rhythm.dart';

enum GardenPhase { ready, intro, call, response, paused, cleared }

class GardenCue {
  const GardenCue({
    required this.id,
    required this.limb,
    required this.beat,
    required this.progress,
    required this.demonstration,
    this.flourishTo,
  });
  final String id;
  final Limb limb;
  final double beat;
  final double progress;
  final bool demonstration;
  bool get demo => demonstration;
  final Limb? flourishTo;
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
    offsets: [0, 1, 2, 2.5, 4, 5, 6, 6.5],
    variants: [
      [
        Limb.rightFoot,
        Limb.leftFoot,
        Limb.rightHand,
        Limb.leftHand,
        Limb.rightFoot,
        Limb.leftFoot,
        Limb.leftHand,
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
  }) : progress = FightProgress(definition ?? fights.first),
       crowd = CrowdInterestModel(
         rampPhrases: 4 * (definition ?? fights.first).successesPerTier,
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
  FlourishDirection? _lastStyleDirection;
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
  int _responseTier = 0;
  int _phraseTier = 0;
  int _responseSequence = 0;
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
      ),
  ]);

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
      if (result.grade == TapGrade.perfect &&
          _perfectCredited.add(result.note!.id)) {
        perfects++;
      }
    }
    return result;
  }

  /// Host verifies same pointer and minimum swipe distance before invoking.
  bool flourish(String noteId, Limb destination) {
    if ((phase != GardenPhase.response && phase != GardenPhase.call) ||
        transport.countingIn ||
        _judge == null) {
      return false;
    }
    final accepted = _judge!.flourish(noteId, destination, _nowMs);
    _creditFlourish(noteId, accepted);
    return accepted;
  }

  bool flourishGesture(String noteId, FlourishDirection direction) {
    if ((phase != GardenPhase.response && phase != GardenPhase.call) ||
        transport.countingIn ||
        _judge == null) {
      return false;
    }
    final accepted = _judge!.flourishGesture(noteId, _nowMs);
    _creditFlourish(noteId, accepted, direction: direction);
    return accepted;
  }

  void _creditFlourish(
    String noteId,
    bool accepted, {
    FlourishDirection? direction,
  }) {
    if (accepted && _credited.add('${progress.definition.id}:$noteId')) {
      pizazz += 100;
      final elapsed = positionBeats - _lastStyleBeat;
      final varied =
          direction != null &&
          _lastStyleDirection != null &&
          direction != _lastStyleDirection &&
          elapsed >= 0 &&
          elapsed <= styleChainWindowBeats;
      styleCombo = varied ? (styleCombo + 1).clamp(1, 4) : 1;
      _lastStyleDirection = direction;
      _lastStyleBeat = positionBeats;
      crowd.adorn(
        _responseSequence % crowd.guestCount,
        positionBeats,
        chain: styleCombo,
      );
    }
  }

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
    _lastStyleDirection = null;
    _lastStyleBeat = -100;
    phase = GardenPhase.paused;
    combo = 0;
  }

  void resume() {
    if (phase != GardenPhase.paused) throw StateError('Garden is not paused');
    transport.resume(
      leadSeconds:
          transport.score.beatsPerBar *
          60 /
          transport.score.tempos[transport.currentTier],
    );
    phase = positionBeats < chart.introBeats
        ? GardenPhase.intro
        : GardenPhase.call;
  }
}
