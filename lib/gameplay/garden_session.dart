import 'dart:math' as math;

import '../music/transport.dart';
import 'crowd_interest.dart';
import 'gesture_shapes.dart';
import 'progression.dart';
import 'rhythm.dart';
import 'thumb_layout.dart';

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
    this.index = 0,
    this.step = 0,
    this.move,
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

  /// This note's place in the phrase, and the step it belongs to.
  final int index;
  final int step;

  /// The richer move this note is part of, if any. Two cues of one step are drawn
  /// linked: see `cue_links.dart`.
  final RichMove? move;
}

/// Richer moves inside a beat, the owner's twelfth round. Each is one step of a
/// phrase with two presses:
/// - [doubleTap]: the same spot twice.
/// - [pair]: two spots at once, one thumb on each.
/// - [split]: one spot, then a spot on the other side.
enum RichMove { doubleTap, pair, split }

/// How close together a chart may ask for presses. The grip assumed is one thumb
/// on each side of the phone. Every number is a starting value that a level can
/// tune, and none of them has met a real thumb: see
/// `plan/double-moves-2026-11-07.md`.
class MoveLimits {
  const MoveLimits({
    this.pairToleranceMs = 80,
    this.sameSpotMs = 285,
    this.thumbHopMs = 330,
    this.crossThumbMs = 170,
    this.sameLimbMs = 400,
    this.phraseEndMs = 100,
  });

  /// Two presses of a pair this close share the better grade, because they are
  /// one gesture to the player. Each press counts whatever this is: a pair's
  /// notes each keep the judge's whole window.
  final int pairToleranceMs;

  /// One thumb, one spot, inside one step. The progression report's 285 ms.
  final int sameSpotMs;

  /// One thumb moving to the other spot on its own side.
  final int thumbHopMs;

  /// Two thumbs, one after the other, unless they are a pair.
  final int crossThumbMs;

  /// One limb in two different steps. Above twice the guaranteed window, so an
  /// on-time-ish tap is never judged against a note of the wrong step. In the
  /// good window's outer 40 ms a tap can reach the neighbour: the judge takes
  /// whichever note is nearer, as it always has.
  final int sameLimbMs;

  /// How long before the phrase ends the session decides it. The validator asks
  /// that the last note's [RhythmJudge.guaranteedWindowMs] ends by then; the
  /// rest of its good window, and any latency compensation, is cut there.
  final int phraseEndMs;
}

/// One step of a richer pattern. A step with no [move] is a single plain note.
class ChartStep {
  const ChartStep(
    this.at,
    this.limb, {
    this.move,
    this.partner,
    this.gap = 0,
    this.offer,
  });
  final double at;
  final Limb limb;
  final RichMove? move;

  /// The second limb of a pair or a split.
  final Limb? partner;

  /// Beats from the first press to the second, for a double or a split.
  final double gap;

  /// The move this step's last press invites, in place of the usual one: how a
  /// room gets a signature, such as a cue stroke up the floor. Only an invitation,
  /// as every move is, and only where the next note leaves room for it.
  final GestureKind? offer;
}

/// One phrase as it is played: its notes in time order, each knowing its step.
/// A step is what clearing counts, so a richer phrase asks for no more than a
/// plain one. The second press of a step is there for skilful play.
class ChartPattern {
  ChartPattern._(
    this.limbs,
    this.offsets,
    this.stepOf,
    this.moves,
    this.steps,
    this.offers,
  );

  factory ChartPattern.plain(List<Limb> limbs, List<double> offsets) =>
      ChartPattern._(
        limbs,
        offsets,
        [for (var i = 0; i < limbs.length; i++) i],
        List.filled(limbs.length, null),
        limbs.length,
        List.filled(limbs.length, null),
      );

  factory ChartPattern.rich(List<ChartStep> steps) {
    final limbs = <Limb>[];
    final offsets = <double>[];
    final stepOf = <int>[];
    final moves = <RichMove?>[];
    final offers = <GestureKind?>[];
    for (final (index, step) in steps.indexed) {
      void note(Limb limb, double at) {
        limbs.add(limb);
        offsets.add(at);
        stepOf.add(index);
        moves.add(step.move);
        offers.add(null);
      }

      note(step.limb, step.at);
      switch (step.move) {
        case null:
          break;
        case RichMove.doubleTap:
          note(step.limb, step.at + step.gap);
        case RichMove.pair:
          note(step.partner!, step.at);
        case RichMove.split:
          note(step.partner!, step.at + step.gap);
      }
      offers[offers.length - 1] = step.offer;
    }
    return ChartPattern._(
      List.unmodifiable(limbs),
      List.unmodifiable(offsets),
      List.unmodifiable(stepOf),
      List.unmodifiable(moves),
      steps.length,
      List.unmodifiable(offers),
    );
  }

  final List<Limb> limbs;
  final List<double> offsets;
  final List<int> stepOf;
  final List<RichMove?> moves;
  final int steps;

  /// What each note invites in place of the usual move, if the chart says.
  final List<GestureKind?> offers;

  /// How many steps ask for a second press.
  int get richSteps => limbs.length - steps;
}

/// What finishing a richer step adds to the score. An optional move adds 100.
const richStepPizazz = 50;

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
    this.richPatterns = const {},
    this.limits = const MoveLimits(),
  });
  final List<Limb> limbs;
  final List<double> offsets;
  final double callBeats;
  final double introBeats;
  final Limb flourishDestination;
  final List<List<Limb>> variants;

  /// Patterns played as richer steps instead of their plain limbs and offsets:
  /// key 0 is [limbs], and key n is `variants[n - 1]`. Empty on a plain chart.
  final Map<int, List<ChartStep>> richPatterns;
  final MoveLimits limits;

  /// 0 is [limbs], and n is `variants[n - 1]`.
  int patternIndex(int tier, int peakPhrase) => variants.isEmpty || tier == 0
      ? 0
      : 1 + (tier == 4 ? 3 + peakPhrase : tier - 1) % variants.length;
  List<Limb> limbsFor(int tier, int peakPhrase) =>
      patternFor(tier, peakPhrase).limbs;
  ChartPattern patternFor(int tier, int peakPhrase) =>
      pattern(patternIndex(tier, peakPhrase));
  ChartPattern pattern(int index) {
    final rich = richPatterns[index];
    if (rich != null) return ChartPattern.rich(rich);
    return ChartPattern.plain(index == 0 ? limbs : variants[index - 1], offsets);
  }

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
    richPatterns.forEach(_validateRich);
  }

  /// Every pattern keeps the same number of steps, so "one dropped step in eight"
  /// means the same thing at every tier, however many presses a step holds.
  void _validateRich(int index, List<ChartStep> steps) {
    if (index < 0 || index > variants.length) {
      throw ArgumentError('Rich pattern $index has no plain pattern to replace');
    }
    if (steps.length != limbs.length) {
      throw ArgumentError('Rich pattern $index must keep ${limbs.length} steps');
    }
    var previous = -1.0;
    for (final (i, step) in steps.indexed) {
      final where = 'Rich pattern $index step $i';
      if (!step.at.isFinite || step.at <= previous) {
        throw ArgumentError('$where must start after the last press before it');
      }
      final move = step.move;
      final partner = step.partner;
      final timed = move == RichMove.doubleTap || move == RichMove.split;
      final paired = move == RichMove.pair || move == RichMove.split;
      if (paired != (partner != null)) {
        throw ArgumentError('$where names its second limb only for a pair or split');
      }
      if (timed != (step.gap > 0) || !step.gap.isFinite) {
        throw ArgumentError('$where has a gap only for a double or split');
      }
      // One thumb on each side: it can't press both, or jump across the phone.
      if (paired && limbIsLeft(partner!) == limbIsLeft(step.limb)) {
        throw ArgumentError('$where must use both sides of the phone');
      }
      previous = step.at + step.gap;
      if (previous >= callBeats) {
        throw ArgumentError('$where runs past the call');
      }
    }
  }

  /// Which fairness limits a pattern breaks at [bpm]. Tempo belongs to the music,
  /// so this is for tests and tools, not for loading. Empty when all is well.
  List<String> fairnessProblems(int index, double bpm) {
    final beatMs = 60000 / bpm;
    final played = pattern(index);
    final problems = <String>[];
    for (var i = 0; i < played.limbs.length; i++) {
      for (var j = i + 1; j < played.limbs.length; j++) {
        final a = played.limbs[i];
        final b = played.limbs[j];
        final beats = played.offsets[j] - played.offsets[i];
        final ms = beats * beatMs;
        final sameStep = played.stepOf[i] == played.stepOf[j];
        if (beats == 0) continue;
        final String rule;
        final int floor;
        if (a == b) {
          (rule, floor) = sameStep
              ? ('same spot', limits.sameSpotMs)
              : ('same limb', limits.sameLimbMs);
        } else if (limbIsLeft(a) == limbIsLeft(b)) {
          (rule, floor) = ('thumb hop', limits.thumbHopMs);
        } else {
          (rule, floor) = ('cross thumb', limits.crossThumbMs);
        }
        if (ms < floor) {
          problems.add(
            'pattern $index at $bpm BPM: $rule, beats '
            '${played.offsets[i]} and ${played.offsets[j]}, '
            '${ms.round()} ms under $floor',
          );
        }
      }
    }
    // A move a step invites needs the session's room for a move after its press,
    // or the invitation would never show.
    for (var i = 0; i + 1 < played.limbs.length; i++) {
      if (played.offers[i] == null) continue;
      final roomMs = (played.offsets[i + 1] - played.offsets[i]) * beatMs;
      if (roomMs <
          2 * RhythmJudge.guaranteedWindowMs + RhythmJudge.flourishWindowMs + 40) {
        problems.add(
          'pattern $index at $bpm BPM: no room for the move offered on beat '
          '${played.offsets[i]}',
        );
      }
    }
    final end =
        (callBeats - played.offsets.last) * beatMs -
        RhythmJudge.guaranteedWindowMs;
    if (end < limits.phraseEndMs) {
      problems.add('pattern $index at $bpm BPM: last note ends the phrase late');
    }
    return problems;
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
    _pattern = chart.pattern(0);
  }
  final MusicTransport transport;
  final MusicAudioBackend backend;
  final FightProgress progress;
  final FightChart chart;
  final CrowdInterestModel crowd;
  late ChartPattern _pattern;

  /// Every note of this phrase, in time order. A pair's two notes share an offset.
  List<Limb> get activeLimbs => _pattern.limbs;
  List<double> get activeOffsets => _pattern.offsets;

  /// The step each active note belongs to, and that step's richer move if any.
  List<int> get activeSteps => _pattern.stepOf;
  List<RichMove?> get activeMoves => _pattern.moves;
  int get stepCount => _pattern.steps;

  /// Steps needed to pass, not notes: a richer phrase asks for no more than a
  /// plain one. See [ChartPattern].
  int get requiredHits => progress.definition.requiredHits(
    stepCount,
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

  /// Both presses of a richer step landed, this run. Never reset by a replay of
  /// the same performance, and read by whatever wants to celebrate one.
  int richStepsCompleted = 0;

  /// The other limb of the pair the latest press completed, or null.
  Limb? lastPairPartner;
  int passedPhrases = 0;
  double? completedAtSeconds;
  double? completedAtBeat;
  double _cycleStart;
  RhythmJudge? _judge;
  bool _resolved = false;
  final Set<int> _stepsLanded = {};
  final Set<int> _stepsPerfect = {};
  final Map<int, int> _pressedMs = {};
  final Map<int, String> _pressedPlain = {};
  int _phraseRich = 0;
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

  /// The most output latency the session will compensate. A report past this
  /// is a broken estimate, not a phone.
  static const maxOutputLatencySeconds = .5;
  int _latencyMs = 0;
  int _inputLatencyMs = 0;

  /// How long after the audio clock the player hears it: Web Audio's
  /// `outputLatency`, or the `?latency=` override. Taps are judged, and response
  /// cues drawn, on the audible clock, which is the audio clock minus this. The
  /// music is still scheduled on the audio clock. Zero off the web and in tests.
  double get outputLatencySeconds => _latencyMs / 1000;
  set outputLatencySeconds(double value) {
    if (!value.isFinite) return;
    _latencyMs = (value.clamp(0.0, maxOutputLatencySeconds) * 1000).round();
  }

  /// How long after a thumb lands the tap reaches the game: the touch screen's
  /// own delay. Judging only, since it has nothing to do with what's drawn.
  double get inputLatencySeconds => _inputLatencyMs / 1000;
  set inputLatencySeconds(double value) {
    if (!value.isFinite) return;
    _inputLatencyMs = (value.clamp(0.0, .2) * 1000).round();
  }

  /// What the player is hearing now, in audio-clock seconds.
  double get audibleSeconds => backend.nowSeconds - _latencyMs / 1000;

  /// The time, in the judge's milliseconds, a tap arriving now is judged at: the
  /// audible clock, less the touch delay.
  int get judgedNowMs => _nowMs - _latencyMs - _inputLatencyMs;

  /// The latest a response can be decided, on the audio clock: the chart's
  /// phrase-end margin before the next call. A phone's latency, or the last
  /// note's late window at a slow tempo, can't push the decision past it, so the
  /// next tier is still asked for in time. A tap after it costs nothing.
  int get _decideByMs =>
      (transport.secondsAt(_cycleStart + chart.cycleBeats) * 1000).round() -
      chart.limits.phraseEndMs;

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
    _stepsLanded.clear();
    _stepsPerfect.clear();
    _pressedMs.clear();
    _pressedPlain.clear();
    _phraseRich = 0;
    lastPairPartner = null;
    _phraseGestures = 0;
    _phraseDeltasMs.clear();
    _hit.clear();
    _phraseTier = progress.tier;
    _pattern = chart.patternFor(_phraseTier, progress.fullTierSuccesses);
    _crowdCheckpoint = crowd.checkpoint();
    _phraseIdentity =
        '${progress.definition.id}:${progress.tier}:${progress.successesAtTier}:${progress.fullTierSuccesses}';
  }

  RhythmJudge _makeJudge() => RhythmJudge([
    for (var i = 0; i < activeLimbs.length; i++)
      RhythmNote(
        '$_phraseIdentity:$i',
        activeLimbs[i],
        (transport.secondsAt(_cycleStart + chart.callBeats + activeOffsets[i]) *
                1000)
            .round(),
        flourishTo: _flourishDestination(i),
        offer: _offerAt(i),
      ),
  ]);

  GestureKind? _offerAt(int index) => _flourishDestination(index) == null
      ? null
      : _pattern.offers[index] ?? gestureOffer(
          limb: activeLimbs[index],
          lastNote: index == activeLimbs.length - 1,
          tier: _phraseTier,
        );

  Limb? _flourishDestination(int index) {
    if (index == activeLimbs.length - 1) return chart.flourishDestination;
    final response = _cycleStart + chart.callBeats;
    final gapMs =
        (transport.secondsAt(response + activeOffsets[index + 1]) -
            transport.secondsAt(response + activeOffsets[index])) *
        1000;
    // Leave the full late tap + ornament + next early tap windows unobstructed.
    return gapMs >=
            2 * RhythmJudge.guaranteedWindowMs + RhythmJudge.flourishWindowMs + 40
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
    // Drawn on the audible clock, so a cue lands when its beat is heard.
    final beat = _latencyMs == 0
        ? positionBeats
        : transport.beatAt(audibleSeconds);
    final cues = <GardenCue>[];
    for (final demonstration in [true, false]) {
      for (var i = 0; i < activeLimbs.length; i++) {
        final target =
            _cycleStart +
            (demonstration ? 0 : chart.callBeats) +
            activeOffsets[i];
        final id = '$_phraseIdentity:$i';
        if (!demonstration && _hit.contains(id)) continue;
        if (beat >= target - 2 &&
            audibleSeconds <=
                transport.secondsAt(target) + RhythmJudge.lateWindowMs / 1000) {
          cues.add(
            GardenCue(
              id: id,
              limb: activeLimbs[i],
              beat: target,
              progress: ((beat - target + 2) / 2).clamp(0, 1),
              demonstration: demonstration,
              flourishTo: _flourishDestination(i),
              offer: _offerAt(i),
              index: i,
              step: activeSteps[i],
              move: activeMoves[i],
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
      if (judgedNowMs >
          _judge!.notes.last.atMs +
              RhythmJudge.lateWindowMs +
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
    // A step's second press is for skilful play, so missing it breaks nothing.
    // The combo breaks once a whole step has gone by with neither press.
    for (final missed in judge.expire(judgedNowMs)) {
      final step = activeSteps[_indexOf(missed)];
      final lastOfStep =
          _indexOf(missed) == activeSteps.lastIndexOf(step);
      if (lastOfStep && !_stepsLanded.contains(step)) combo = 0;
    }
    if (!_resolved &&
        (judgedNowMs > judge.notes.last.atMs + RhythmJudge.lateWindowMs ||
            _nowMs > _decideByMs)) {
      _resolved = true;
      final passed = _stepsLanded.length >= requiredHits;
      // Full-arrangement sustain cannot score while its request is pending.
      if (passed && progress.tier == 4 && _responseTier < 4) return;
      lastOutcome = progress.resolve(passed: passed);
      if (passed) passedPhrases++;
      final resolvedBeat = transport.beatAt(
        math.min(
              judge.notes.last.atMs +
                  RhythmJudge.lateWindowMs +
                  _latencyMs +
                  _inputLatencyMs,
              _decideByMs,
            ) /
            1000,
      );
      lastOutcomeBeat = resolvedBeat;
      crowd.resolvePhrase(
        sequence: _responseSequence,
        passed: passed,
        beat: resolvedBeat,
        cleared: progress.cleared,
        report: PhraseReport(
          notes: stepCount,
          hits: _stepsLanded.length,
          perfects: _stepsPerfect.length,
          // A finished richer step is skill the room can see, like a move.
          gestures: _phraseGestures + _phraseRich,
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

  /// The challenger is dancing and the player's turn hasn't opened, not even
  /// its early grace before the first response note. A tap now is out of turn:
  /// it's shown a cross, and costs nothing.
  bool get opponentsTurn {
    if (phase != GardenPhase.call || transport.countingIn) return false;
    final firstResponseMs =
        (transport.secondsAt(_cycleStart + chart.callBeats) * 1000).round();
    return judgedNowMs < firstResponseMs - RhythmJudge.earlyWindowMs;
  }

  /// The latest tap came during [opponentsTurn]. It was ignored, never a miss.
  bool lastTapOutOfTurn = false;

  TapResult tap(Limb limb) {
    advance();
    lastTapOutOfTurn = opponentsTurn;
    if (transport.countingIn) {
      return const TapResult(TapGrade.miss, null);
    }
    final firstResponseMs = phase == GardenPhase.call
        ? (transport.secondsAt(_cycleStart + chart.callBeats) * 1000).round()
        : 0;
    final earlyResponse =
        phase == GardenPhase.call &&
        judgedNowMs >= firstResponseMs - RhythmJudge.earlyWindowMs &&
        judgedNowMs < firstResponseMs;
    if ((phase != GardenPhase.response && !earlyResponse) ||
        _resolved ||
        progress.cleared) {
      return const TapResult(TapGrade.miss, null);
    }
    if (_judge == null) {
      _responseTier = transport.currentTier;
      _judge = _makeJudge();
    }
    final result = _togetherGrade(_judge!.tap(limb, judgedNowMs));
    lastGrade = result.grade;
    lastTiming = result.timing;
    lastDeltaMs = result.deltaMs;
    lastPairPartner = null;
    if (result.note != null) {
      final index = _indexOf(result.note!);
      final step = activeSteps[index];
      final firstOfStep = !_stepsLanded.contains(step);
      _stepsLanded.add(step);
      combo++;
      _hit.add(result.note!.id);
      _phraseDeltasMs.add(result.deltaMs);
      _openMove(result.note!);
      if (result.grade == TapGrade.perfect) {
        _stepsPerfect.add(step);
        _creditPerfect(result.note!.id);
      }
      if (!firstOfStep) _richStepLanded(index, step);
      _pressedMs[step] = _nowMs;
      if (result.grade != TapGrade.perfect) {
        _pressedPlain[step] = result.note!.id;
      }
    }
    return result;
  }

  int _indexOf(RhythmNote note) => _judge!.notes.indexOf(note);

  void _creditPerfect(String noteId) {
    if (_perfectCredited.add(noteId)) perfects++;
  }

  /// Two thumbs a few milliseconds apart are one gesture, so a pair's presses
  /// that land together share the better grade, either way round.
  TapResult _togetherGrade(TapResult result) {
    final note = result.note;
    if (note == null) return result;
    final index = _indexOf(note);
    if (activeMoves[index] != RichMove.pair) return result;
    final step = activeSteps[index];
    final other = _pressedMs[step];
    if (other == null ||
        (_nowMs - other).abs() > chart.limits.pairToleranceMs) {
      return result;
    }
    final otherPlain = _pressedPlain[step];
    if (result.grade == TapGrade.perfect) {
      // The first press was the one just outside: its credit comes now.
      if (otherPlain != null) _creditPerfect(otherPlain);
      return result;
    }
    if (otherPlain != null) return result;
    return TapResult(
      TapGrade.perfect,
      note,
      deltaMs: result.deltaMs,
      timing: TapTiming.perfect,
    );
  }

  /// Both presses of a step landed. It pays like a smaller optional move, and only
  /// once per performance, so a pause's replay can't farm it.
  void _richStepLanded(int index, int step) {
    _phraseRich++;
    if (activeMoves[index] == RichMove.pair) {
      final first = activeSteps.indexOf(step);
      lastPairPartner = activeLimbs[index == first ? index + 1 : first];
    }
    final key = '${progress.definition.id}:$_phraseIdentity:rich:$step:$_performance';
    if (_credited.add(key)) {
      richStepsCompleted++;
      pizazz += richStepPizazz;
      crowd.adorn(_responseSequence % crowd.guestCount, positionBeats);
    }
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
