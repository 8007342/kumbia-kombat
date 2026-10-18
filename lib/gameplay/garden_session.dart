import '../music/transport.dart';
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
  });
  final List<Limb> limbs;
  final List<double> offsets;
  final double callBeats;
  final double introBeats;
  final Limb flourishDestination;
  double get cycleBeats => callBeats * 2;
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
  );
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
  );
}

/// Garden vertical-slice controller. All judgments read the audio clock.
/// Pump transport separately at 20 ms; call advance before painting/input.
class GardenSession {
  GardenSession(
    this.transport,
    this.backend, {
    FightDefinition? definition,
    this.chart = FightChart.garden,
  }) : progress = FightProgress(definition ?? fights.first),
       _cycleStart = chart.introBeats {
    if (chart.limbs.isEmpty ||
        chart.limbs.length != chart.offsets.length ||
        chart.callBeats <= 0 ||
        chart.introBeats < 0 ||
        !chart.callBeats.isFinite ||
        !chart.introBeats.isFinite) {
      throw ArgumentError('Invalid fight chart');
    }
    var previous = -1.0;
    for (final offset in chart.offsets) {
      if (!offset.isFinite ||
          offset < 0 ||
          offset <= previous ||
          offset >= chart.callBeats) {
        throw ArgumentError('Invalid chart offsets');
      }
      previous = offset;
    }
  }
  final MusicTransport transport;
  final MusicAudioBackend backend;
  final FightProgress progress;
  final FightChart chart;
  GardenPhase phase = GardenPhase.ready;
  TapGrade? lastGrade;
  ChallengeOutcome? lastOutcome;
  int pizazz = 0;
  int perfects = 0;
  int combo = 0;
  int passedPhrases = 0;
  double? completedAtSeconds;
  double _cycleStart;
  RhythmJudge? _judge;
  bool _resolved = false;
  bool _missed = false;
  int _hits = 0;
  int _responseTier = 0;
  final Set<String> _credited = {};
  final Set<String> _perfectCredited = {};
  final Set<String> _hit = {};
  String _phraseIdentity = '0:0';

  double get positionBeats => transport.positionBeats;
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

  void _prepareCycle() {
    _judge = null;
    _resolved = false;
    _missed = false;
    _hits = 0;
    _hit.clear();
    _phraseIdentity =
        '${progress.definition.id}:${progress.tier}:${progress.successesAtTier}:${progress.fullTierSuccesses}';
  }

  RhythmJudge _makeJudge() => RhythmJudge([
    for (var i = 0; i < chart.limbs.length; i++)
      RhythmNote(
        '$_phraseIdentity:$i',
        chart.limbs[i],
        (transport.secondsAt(_cycleStart + chart.callBeats + chart.offsets[i]) *
                1000)
            .round(),
        flourishTo: i == chart.limbs.length - 1
            ? chart.flourishDestination
            : null,
      ),
  ]);

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
      for (var i = 0; i < chart.limbs.length; i++) {
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
              limb: chart.limbs[i],
              beat: target,
              progress: ((beat - target + 2) / 2).clamp(0, 1),
              demonstration: demonstration,
              flourishTo: !demonstration && i == chart.limbs.length - 1
                  ? chart.flourishDestination
                  : null,
            ),
          );
        }
      }
    }
    return cues;
  }

  void advance() {
    if (phase == GardenPhase.ready ||
        phase == GardenPhase.paused ||
        phase == GardenPhase.cleared) {
      return;
    }
    if (transport.state == TransportState.paused) {
      pause();
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
      _prepareCycle();
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
    if (progress.cleared) {
      if (_nowMs >
          judge.notes.last.atMs +
              RhythmJudge.goodWindowMs +
              RhythmJudge.flourishWindowMs) {
        phase = GardenPhase.cleared;
      }
      return;
    }
    if (judge.expire(_nowMs).isNotEmpty) {
      _missed = true;
      combo = 0;
    }
    if (!_resolved &&
        _nowMs > judge.notes.last.atMs + RhythmJudge.goodWindowMs) {
      _resolved = true;
      final passed = !_missed && _hits == judge.notes.length;
      // Full-arrangement sustain cannot score while its request is pending.
      if (passed && progress.tier == 4 && _responseTier < 4) return;
      lastOutcome = progress.resolve(passed: passed);
      if (passed) passedPhrases++;
      if (progress.cleared) {
        completedAtSeconds = backend.nowSeconds;
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
    if (phase != GardenPhase.response || _judge == null) return false;
    final accepted = _judge!.flourish(noteId, destination, _nowMs);
    if (accepted && _credited.add('${progress.definition.id}:$noteId')) {
      pizazz += 100;
    }
    return accepted;
  }

  void pause() {
    if (phase == GardenPhase.ready ||
        phase == GardenPhase.cleared ||
        phase == GardenPhase.paused) {
      return;
    }
    final replayBeat = phase == GardenPhase.intro ? 0.0 : _cycleStart;
    transport.seek(replayBeat, tier: progress.tier);
    _prepareCycle();
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
