import 'dart:math' as math;

enum CrowdGuestState {
  occupied,
  curious,
  following,
  participating,
  celebrating,
}

/// Each tag names an authored multi-frame group, including movement between
/// seated and standing poses. The renderer must not substitute canvas bobbing.
enum CrowdClip {
  seatedIdle,
  notice,
  seatedFollow,
  standUp,
  standingIdle,
  stepTouch,
  clap,
  cheer,
  sitDown,
}

class CrowdStageProfile {
  const CrowdStageProfile(
    this.roomId,
    this.interested,
    this.following,
    this.standing,
    this.cheering,
  );
  final String roomId;

  /// Cumulative budgets at a reference cast size of twelve, so each is a share of
  /// the room: a budget of 12 is everyone in a room of six or of thirty. They cap
  /// what a room's cast can do at all. Owner's ruling, 2026-11-06: every shipped
  /// room can end fully engaged, so how far a run gets is decided by play
  /// ([CrowdEngagement]), and these stay as data for a later room to differ.
  final int interested;
  final int following;
  final int standing;
  final int cheering;

  static const garden = CrowdStageProfile('garden', 12, 12, 12, 12);
  static const bar = CrowdStageProfile('bar', 12, 12, 12, 12);
  static const coolCrowd = CrowdStageProfile('cool-crowd', 12, 12, 12, 12);
  static const restroom = CrowdStageProfile('restroom', 12, 12, 12, 12);
  static const vip = CrowdStageProfile('vip', 12, 12, 12, 12);
  static const stages = [garden, bar, coolCrowd, restroom, vip];

  /// The budgets by room. A level file carries its own; an id
  /// that is in neither is an error, never another room's numbers.
  static CrowdStageProfile forRoom(String id) => stages.firstWhere(
    (profile) => profile.roomId == id,
    orElse: () =>
        throw ArgumentError.value(id, 'id', 'No crowd profile for this room'),
  );

  CrowdGuestState ceiling(int rank, int count) {
    int budget(int value) => (value * count / 12).ceil();
    if (rank < budget(cheering)) return CrowdGuestState.celebrating;
    if (rank < budget(standing)) return CrowdGuestState.participating;
    if (rank < budget(following)) return CrowdGuestState.following;
    if (rank < budget(interested)) return CrowdGuestState.curious;
    return CrowdGuestState.occupied;
  }
}

/// How one response phrase went, as the session saw it. The crowd reads this
/// and nothing flows back: pass, tier, combo and Pizazz are settled first.
class PhraseReport {
  const PhraseReport({
    required this.notes,
    required this.hits,
    required this.perfects,
    this.gestures = 0,
    this.spreadMs = 0,
  });

  /// Every note hit, tidily, with no PERFECT and no gesture: a plain clean take.
  static const plain = PhraseReport(notes: 1, hits: 1, perfects: 0);

  final int notes;
  final int hits;
  final int perfects;

  /// Accepted optional moves. Optional: zero never lowers a phrase's grade.
  final int gestures;

  /// Mean distance of each tap from the phrase's own average timing. A player
  /// who is steadily late by 150 ms has a spread near zero, because latency
  /// calibration isn't built (roadmap item 02) and lag isn't sloppiness.
  final double spreadMs;

  static double spreadOf(List<int> deltasMs) {
    if (deltasMs.length < 2) return 0;
    final mean = deltasMs.reduce((a, b) => a + b) / deltasMs.length;
    return deltasMs.map((d) => (d - mean).abs()).reduce((a, b) => a + b) /
        deltasMs.length;
  }
}

enum PhraseGrade {
  /// Below the required hits. The only grade that isn't a pass.
  failed,

  /// Passed, with at least one note dropped.
  scrappy,

  /// Every note hit, but the timing wandered past
  /// [CrowdEngagement.sloppySpreadMs].
  loose,

  /// Every note hit, tidily.
  clean,

  /// Clean, plus half the notes PERFECT or an accepted optional move.
  excellent,
}

/// The owner's ruling: be lenient, because players should enjoy the game at full
/// animations, and even a poor run that clears gets warm interest. The room is
/// the meter, so a bigger room is a bigger reward: every line here is a share of
/// the cast, whatever its size. What a room shows depends on the level's average
/// phrase credit (a clean phrase 1, a loose one .75, a scrappy one .5, a failed
/// one 0), written out for a cast of twelve:
///
/// | Average | Example | The room at the clear |
/// |---|---|---|
/// | Below .50 | Failures and scrapes | 5 dancing, 7 seated and following |
/// | .50 | A scrape on every phrase | The same 5 and 7 |
/// | .60 | Eight scrapes and two clean, of ten | 8 dancing, 4 following |
/// | .70 | Six scrapes and four clean, of ten | All 12 dancing |
/// | .75 | Every phrase loose | All 12 dancing, 6 of them celebrating |
/// | .80 | Two drops, of six; or four, of ten | Full swing: 12 celebrating, props on the beat |
/// | 1.0 | Every phrase clean | Full swing |
///
/// The average that counts is the one at the phrase before the clear, because
/// movement takes a phrase to land.
///
/// This reads the score and never changes it. The numbers are artistic starting
/// values for tuning, not findings.
abstract final class CrowdEngagement {
  /// Timing spread that makes a fully hit phrase [PhraseGrade.loose]. Taps
  /// scattered evenly over +/-140 ms give about this; a steady player sits well
  /// under it.
  static const sloppySpreadMs = 70.0;

  /// Share of PERFECT notes that makes a tidy phrase excellent without a gesture.
  /// The same line as the progression report's "at least half PERFECT".
  static const excellentPerfectShare = .5;

  /// Gains scale a guest's clean step, which is sized to bring the least receptive
  /// guest to this interest in the phrases set by [phrasesToFull].
  static const engagedInterest = .74;
  static const leastReceptive = .94;

  /// The first guest is fully engaged this far through a clean run. The last gets
  /// there one phrase before the clear, so the final proof phrase plays to a full
  /// room and every reaction lands before the exit shot samples the guests.
  static const firstGuestArcShare = .5;

  /// How fast guests climb to what the average allows. They barely differ, because
  /// the ceilings below are what cool the room, not the pace. Sized so that a run
  /// reaching [fullSwingAverage] late has the last guest on their feet already,
  /// with time to celebrate before the clear.
  static const scrappyGain = 1.1;
  static const looseGain = 1.2;
  static const cleanGain = 1.35;

  /// Faster than clean, and never needed: a clean run gets to the same place.
  static const excellentGain = 1.5;

  /// An optional move on a phrase that isn't clean still adds this much interest.
  static const gestureFlair = .15;

  /// What each phrase is worth to the room, averaged over every phrase played in
  /// the level. It's an average so that retrying can't buy the room back: a poor
  /// run lasts longer, and would otherwise climb on length alone.
  static const failedCredit = 0.0;
  static const scrappyCredit = .5;
  static const looseCredit = .75;

  /// An optional move lifts a scrappy or loose phrase's credit by this much. Clean
  /// phrases are already worth 1, so ignoring optional moves locks nothing away.
  static const gestureCredit = .1;

  /// How much of a band's sense of the player's form the latest phrase replaces.
  /// A clean run reaches .9 in about eight phrases of a level's eleven.
  static const formWeight = .25;

  /// The warm floor, in a cast of [CrowdInterestModel.castSize]: this many dance at
  /// any clear, however poor the run. Four leaves the room lopsided, because the
  /// order fills the left side first; the fifth guest balances it at three to two.
  /// A room of another size keeps the proportion: see [warmFloorOf].
  static const warmFloorOfTwelve = 5;

  /// Where the floor's last guest falls in the order, 0 first to 1 last.
  static const warmFloorPosition =
      (warmFloorOfTwelve - 1) / (CrowdInterestModel.castSize - 1);

  /// How many of a [guests] strong cast dance at any clear.
  static int warmFloorOf(int guests) {
    if (guests <= 1) return guests;
    var count = 0;
    for (var rank = 0; rank < guests; rank++) {
      if (rank / (guests - 1) <= warmFloorPosition) count++;
    }
    return count;
  }

  /// Everyone past the floor sits and follows at any clear, and nobody is left
  /// occupied. Above every guest's following line, under the .64 where a guest
  /// who has stood sits back down.
  static const warmFollowingInterest = .60;

  /// From this average the guests past the floor start to stand, one after
  /// another, until every guest is up at [allStandingAverage].
  static const warmAverage = .5;
  static const allStandingAverage = .70;

  /// Guests who may stand stop here: on their feet, not celebrating, and under the
  /// .82 where a celebrating guest settles back. High enough that one failed phrase
  /// doesn't seat them.
  static const standingCeiling = .80;

  /// From this average guests begin to celebrate, one after another, until every
  /// guest is celebrating at [fullSwingAverage].
  static const firstGuestCelebratesAt = .70;

  /// The top: the whole room celebrating, and the props dancing on the beat. A
  /// clean run is 1.0. On six phrases this allows two drops, or a failure and a
  /// loose phrase. On ten, four drops. Every phrase loose is .75, just short of it.
  static const fullSwingAverage = .80;

  /// Where a guest allowed to celebrate gets to, clear of the .90 line.
  static const celebratingInterest = .95;

  /// Per phrase, on guests above what the room's average supports. Slow on purpose,
  /// and each state's floor adds hysteresis on top.
  static const overCeilingDrain = .04;
  static const failedRoomDrain = .05;

  /// The props' reveal can start once this share of a clean run's passes is in.
  static const swingStartShare = 1 / 3;

  /// How long props take to settle back if the average falls below the top.
  static const swingFadeBeats = 48.0;

  static double credit(PhraseGrade grade, {bool gesture = false}) {
    final flair = gesture ? gestureCredit : 0.0;
    return switch (grade) {
      PhraseGrade.failed => failedCredit,
      PhraseGrade.scrappy => scrappyCredit + flair,
      PhraseGrade.loose => looseCredit + flair,
      PhraseGrade.clean || PhraseGrade.excellent => 1.0,
    };
  }

  /// The average at which this guest may stand, [position] 0 first in to 1 last.
  /// Zero for the warm floor's guests, who may stand at any average.
  static double standsAt(double position) {
    if (position <= warmFloorPosition) return 0;
    final t = (position - warmFloorPosition) / (1 - warmFloorPosition);
    return warmAverage + (allStandingAverage - warmAverage) * t;
  }

  /// The average at which this guest may celebrate.
  static double celebratesAt(double position) =>
      firstGuestCelebratesAt +
      (fullSwingAverage - firstGuestCelebratesAt) * position;

  static PhraseGrade grade(bool passed, PhraseReport report) {
    if (!passed) return PhraseGrade.failed;
    if (report.hits < report.notes) return PhraseGrade.scrappy;
    if (report.spreadMs > sloppySpreadMs) return PhraseGrade.loose;
    if (report.gestures > 0 ||
        report.perfects >= report.notes * excellentPerfectShare) {
      return PhraseGrade.excellent;
    }
    return PhraseGrade.clean;
  }

  /// Clean phrases that fully engage a guest, [position] 0 first in to 1 last.
  static double phrasesToFull(double position, int arcPhrases) {
    final first = arcPhrases * firstGuestArcShare;
    final last = math.max(first, arcPhrases - 1.0);
    return math.max(1.0, first + (last - first) * position);
  }

  /// Quintic smootherstep: no speed at either end, per the fifth round's method.
  static double reveal(double t) {
    final x = t.clamp(0.0, 1.0);
    return x * x * x * (x * (x * 6 - 15) + 10);
  }
}

/// Room-level state of the arc, saved and restored with the crowd checkpoint.
class _RoomArc {
  int phrases = 0;
  int passes = 0;
  double credit = 0;

  /// The player's recent form, 0 to 1: unlike [average], it forgets, so a player
  /// who improves shows it. Only a band reads it.
  double form = 0;
  PhraseGrade? lastGrade;
  bool lastHadGesture = false;
  double swingFrom = 0;
  double swingTo = 0;
  double swingStart = 0;
  double swingBeats = 1;

  double get average => phrases == 0 ? 0 : credit / phrases;

  double swingAt(double beat) =>
      swingFrom +
      (swingTo - swingFrom) *
          CrowdEngagement.reveal((beat - swingStart) / swingBeats);

  void moveSwing(double beat, double to, double beats) {
    swingFrom = swingAt(beat);
    swingTo = to;
    swingStart = beat;
    swingBeats = beats;
  }

  _RoomArc copy() => _RoomArc()
    ..phrases = phrases
    ..passes = passes
    ..credit = credit
    ..form = form
    ..lastGrade = lastGrade
    ..lastHadGesture = lastHadGesture
    ..swingFrom = swingFrom
    ..swingTo = swingTo
    ..swingStart = swingStart
    ..swingBeats = swingBeats;
}

class CrowdGuestSnapshot {
  const CrowdGuestSnapshot({
    required this.interest,
    required this.state,
    required this.styleEnergy,
    required this.reactionBeat,
    required this.clip,
    required this.clipBeat,
    required this.clipDurationBeats,
    required this.transitioning,
    required this.standing,
    required this.archetypeIndex,
    required this.paletteIndex,
    required this.phaseOffset,
    this.noticedBy,
  });
  final double interest;
  final CrowdGuestState state;
  final double styleEnergy;
  final double reactionBeat;
  final int? noticedBy;
  final CrowdClip clip;
  final double clipBeat;
  final double clipDurationBeats;
  final bool transitioning;
  final bool standing;
  final int archetypeIndex;
  final int paletteIndex;
  final double phaseOffset;
}

class _Motion {
  const _Motion(this.clip, this.start, this.duration, this.before, this.after);
  final CrowdClip clip;
  final double start;
  final double duration;
  final CrowdGuestState before;
  final CrowdGuestState after;
}

class _Pose {
  const _Pose(
    this.state,
    this.clip,
    this.beat,
    this.duration,
    this.transitioning,
    this.standing,
  );
  final CrowdGuestState state;
  final CrowdClip clip;
  final double beat;
  final double duration;
  final bool transitioning;
  final bool standing;
}

class _Guest {
  _Guest(this.interest, this.rank, this.phaseOffset);
  double interest;
  final int rank;
  final double phaseOffset;
  CrowdGuestState base = CrowdGuestState.occupied;
  CrowdGuestState target = CrowdGuestState.occupied;
  List<_Motion> motions = [];
  double reactionBeat = 0;
  double styleBeat = -100;
  double styleStrength = 0;
  double styleDuration = 4;
  int? noticedBy;
  _Guest copy() => _Guest(interest, rank, phaseOffset)
    ..base = base
    ..target = target
    ..motions = List.of(motions)
    ..reactionBeat = reactionBeat
    ..styleBeat = styleBeat
    ..styleStrength = styleStrength
    ..styleDuration = styleDuration
    ..noticedBy = noticedBy;
}

/// A bounded in-memory save, not a durable run-save implementation.
class CrowdCheckpoint {
  CrowdCheckpoint._(this._guests, this._lastSequence, this._support, this._arc);
  final List<_Guest> _guests;
  final int _lastSequence;
  final double _support;
  final _RoomArc _arc;
}

class CrowdInterestModel {
  /// Budgets and the room's timing are written against this many guests. A cast
  /// of any other size keeps their proportions: see [_referenceRank].
  static const castSize = 12;

  /// The most guests a level may seat. A limit on phone drawing, not on the rules.
  static const maxGuests = 48;

  CrowdInterestModel({
    required this.rampPhrases,
    this.profile = CrowdStageProfile.garden,
    int guestCount = castSize,
    int? arcPhrases,
    this.phraseBeats = 16,
  }) : arcPhrases = arcPhrases ?? rampPhrases + 2 {
    if (rampPhrases <= 0 || guestCount <= 0 || this.arcPhrases <= 0) {
      throw ArgumentError('Crowd needs positive ramp and guest counts');
    }
    // Interleave depth/side slots so the first supporters are not one solid row.
    _order = [
      for (var column = 0; column < 4; column++)
        for (var i = column; i < guestCount; i += 4) i,
    ];
    _guests = List.generate(
      guestCount,
      (i) => _Guest(.025 + (i % 5) * .005, _order.indexOf(i), (i * .371) % 4),
    );
  }
  final int rampPhrases;

  /// Phrases in a clean run of this level: what the crowd arc is laid over.
  final int arcPhrases;
  final double phraseBeats;
  final CrowdStageProfile profile;
  late final List<int> _order;
  late List<_Guest> _guests;
  int _lastSequence = -1;
  double _support = 0;
  _RoomArc _arc = _RoomArc();
  int get guestCount => _guests.length;

  /// Where this rank would fall in a cast of [castSize]. Everything that spreads
  /// through the room in beats reads this, so a bigger room gets up in the same
  /// time, with more people moving at once, and a run still lands before the clear.
  double _referenceRank(int rank) =>
      guestCount > 1 ? rank * (castSize - 1) / (guestCount - 1) : 0;

  /// The level's average phrase credit so far. Decides nothing but the room's look.
  double get averageCredit => _arc.average;

  /// How well the last few phrases went, 0 to 1. Decides nothing but a band's look.
  double get recentForm => _arc.form;

  /// Whether the average is at the top right now.
  bool get fullSwingEarned => _arc.average >= CrowdEngagement.fullSwingAverage;
  PhraseGrade? get lastGrade => _arc.lastGrade;

  /// How far the top of the ladder has arrived, 0 to 1: staff and props dancing.
  /// A pure function of the music beat, so it freezes on pause. Only the renderer
  /// reads it.
  double partySwing(double beat) => _arc.swingAt(beat);

  /// Musical readiness, independent of how expressive this room's guests are.
  /// Never an additional clearance requirement.
  bool get peakSupported => _support >= .9;
  double get earnedSupport => _support;

  List<CrowdGuestSnapshot> get guests => List.generate(
    guestCount,
    (i) => guest(
      i,
      _guests[i].motions.isEmpty
          ? 0
          : _guests[i].motions.last.start + _guests[i].motions.last.duration,
    ),
    growable: false,
  );

  /// Pure beat sampling, including a staggered return to each guest's own seat.
  /// Supply the conductor's continuous beat at the beginning of the exit coda.
  CrowdGuestSnapshot guest(int index, double beat, {double? exitBeat}) {
    final g = _guests[index];
    var pose = _sample(index, beat);
    final styleAge = beat - g.styleBeat;
    final energy = styleAge >= 0 && styleAge < g.styleDuration
        ? g.styleStrength * (1 - styleAge / g.styleDuration)
        : 0.0;
    if (exitBeat != null && beat >= exitBeat) {
      final atExit = _sample(index, exitBeat);
      final reference = _referenceRank(g.rank);
      final escort = reference < 2 && atExit.state != CrowdGuestState.occupied;
      final sitAt = exitBeat + 2 + reference * .47 + (escort ? 4 : 0);
      if (beat >= sitAt) {
        final duration = atExit.standing ? 2.0 : 1.0;
        pose = beat < sitAt + duration
            ? _Pose(
                atExit.state,
                atExit.standing ? CrowdClip.sitDown : CrowdClip.notice,
                beat - sitAt,
                duration,
                true,
                atExit.standing && beat - sitAt < duration / 2,
              )
            : _loop(CrowdGuestState.occupied, beat - sitAt - duration, index);
      } else {
        pose = _loop(atExit.state, beat - exitBeat, index);
      }
    } else if (energy > .2 && !pose.transitioning) {
      // A flourish can earn a glance from a busy guest, but cannot make a
      // seated holdout jump to a standing pose or breach the room's budget.
      pose = _Pose(
        pose.state,
        pose.standing
            ? CrowdClip.clap
            : pose.state == CrowdGuestState.occupied
            ? CrowdClip.notice
            : CrowdClip.seatedFollow,
        styleAge,
        g.styleDuration,
        false,
        pose.standing,
      );
    }
    return CrowdGuestSnapshot(
      interest: g.interest,
      state: pose.state,
      styleEnergy: energy,
      reactionBeat: g.reactionBeat,
      noticedBy: g.noticedBy,
      clip: pose.clip,
      clipBeat: pose.beat,
      clipDurationBeats: pose.duration,
      transitioning: pose.transitioning,
      standing: pose.standing,
      archetypeIndex: index % 3,
      paletteIndex: (index ~/ 3) % 4,
      phaseOffset: g.phaseOffset,
    );
  }

  CrowdCheckpoint checkpoint() => CrowdCheckpoint._(
    _guests.map((g) => g.copy()).toList(),
    _lastSequence,
    _support,
    _arc.copy(),
  );
  void restore(CrowdCheckpoint checkpoint) {
    if (checkpoint._guests.length != guestCount) {
      throw ArgumentError('Crowd checkpoint belongs to a different cast');
    }
    _guests = checkpoint._guests.map((g) => g.copy()).toList();
    _lastSequence = checkpoint._lastSequence;
    _support = checkpoint._support;
    _arc = checkpoint._arc.copy();
  }

  /// One call per resolved phrase, so interest moves with the phrase structure
  /// and never per note. Without a [report], a pass counts as a plain clean take.
  bool resolvePhrase({
    required int sequence,
    required bool passed,
    required double beat,
    bool cleared = false,
    PhraseReport? report,
  }) {
    if (sequence <= _lastSequence) return false;
    _lastSequence = sequence;
    _support = (_support + (passed ? 1 / rampPhrases : -.035)).clamp(0.0, 1.0);
    final phrase = report ?? PhraseReport.plain;
    final grade = CrowdEngagement.grade(passed, phrase);
    _arc.phrases++;
    if (passed) _arc.passes++;
    _arc.lastGrade = grade;
    _arc.lastHadGesture = phrase.gestures > 0;
    final credit = CrowdEngagement.credit(grade, gesture: _arc.lastHadGesture);
    _arc.credit += credit;
    _arc.form += (credit - _arc.form) * CrowdEngagement.formWeight;
    _moveSwing(beat);
    final flair = _arc.lastHadGesture ? CrowdEngagement.gestureFlair : 0.0;
    _moveGuests(beat, grade, switch (grade) {
      PhraseGrade.failed => 0,
      PhraseGrade.scrappy => CrowdEngagement.scrappyGain + flair,
      PhraseGrade.loose => CrowdEngagement.looseGain + flair,
      PhraseGrade.clean => CrowdEngagement.cleanGain,
      PhraseGrade.excellent => CrowdEngagement.excellentGain,
    });
    if (!passed) stumble(sequence % guestCount, beat);
    // Approval intentionally does not override individual stage ceilings.
    return true;
  }

  /// The last note's flick can land after its phrase resolved. It still counts
  /// for that phrase, once. Returns whether it counted.
  bool gestureAfterPhrase({required int sequence, required double beat}) {
    final grade = _arc.lastGrade;
    if (sequence != _lastSequence ||
        grade == null ||
        grade == PhraseGrade.failed ||
        _arc.lastHadGesture) {
      return false;
    }
    _arc.lastHadGesture = true;
    switch (grade) {
      case PhraseGrade.clean:
        _arc.lastGrade = PhraseGrade.excellent;
        _moveGuests(
          beat,
          PhraseGrade.excellent,
          CrowdEngagement.excellentGain - CrowdEngagement.cleanGain,
        );
      case PhraseGrade.scrappy:
      case PhraseGrade.loose:
        _arc.credit += CrowdEngagement.gestureCredit;
        _moveSwing(beat);
        _moveGuests(beat, grade, CrowdEngagement.gestureFlair, drain: false);
      case PhraseGrade.excellent:
      case PhraseGrade.failed:
        break;
    }
    return true;
  }

  /// Props follow the average. A slip that leaves it at the top changes nothing.
  /// One that takes it below starts a slow fade, and climbing back reverses it.
  void _moveSwing(double beat) {
    if (!fullSwingEarned) {
      if (_arc.swingTo > 0) {
        _arc.moveSwing(beat, 0, CrowdEngagement.swingFadeBeats);
      }
      return;
    }
    final start = (arcPhrases * CrowdEngagement.swingStartShare).ceil();
    if (_arc.swingTo >= 1 || _arc.passes < start) return;
    // One long entrance timed to arrive a phrase before the clear, so the last
    // proof phrase is the moment a player looks up and finds it all dancing.
    _arc.moveSwing(
      beat,
      1,
      math.max(1, arcPhrases - 1 - _arc.passes) * phraseBeats,
    );
  }

  void _moveGuests(
    double beat,
    PhraseGrade grade,
    double gain, {
    bool drain = true,
  }) {
    for (var i = 0; i < guestCount; i++) {
      final g = _guests[i];
      final position = guestCount > 1 ? g.rank / (guestCount - 1) : 0.0;
      final ceiling = profile.ceiling(g.rank, guestCount);
      final maxInterest = ceiling == CrowdGuestState.occupied ? .07 : 1.0;
      final receptiveness = const [1.06, .94, 1.02, .97, 1.0][i % 5];
      final cleanStep =
          CrowdEngagement.engagedInterest /
          (CrowdEngagement.phrasesToFull(position, arcPhrases) *
              CrowdEngagement.leastReceptive) *
          receptiveness;
      final limit = _ceiling(position);
      var next = g.interest;
      if (grade == PhraseGrade.failed) {
        next -= CrowdEngagement.failedRoomDrain;
      } else {
        if (next < limit) {
          next = math.min(limit, next + cleanStep * gain);
        } else if (drain) {
          next = math.max(limit, next - CrowdEngagement.overCeilingDrain);
        }
        next = math.max(next, _earned(position, limit));
      }
      g.interest = next.clamp(0.0, maxInterest);
      _change(i, beat);
    }
  }

  /// How high this guest can go, from the level's average so far.
  double _ceiling(double position) {
    final average = _arc.average;
    if (average >= CrowdEngagement.celebratesAt(position)) return 1;
    return average >= CrowdEngagement.standsAt(position)
        ? CrowdEngagement.standingCeiling
        : CrowdEngagement.warmFollowingInterest;
  }

  /// The least a guest holds after a pass: their ceiling, earned one pass at a time
  /// over the arc. This is what makes the ladder hold at the clear, however the
  /// run got there. Failures can't hold a guest under it for long, because a clear
  /// takes at least [arcPhrases] passes, and a failure leaves at least two passes
  /// to go, so one can't land right before the exit shot. A late recovery catches
  /// up here too.
  double _earned(double position, double ceiling) =>
      math.min(ceiling, CrowdEngagement.celebratingInterest) *
      math.min(
        1.0,
        _arc.passes / CrowdEngagement.phrasesToFull(position, arcPhrases),
      );

  void stumble(int index, double beat) {
    // One guest takes it hardest, and the same share of the room notices.
    final reach = math.min(guestCount, (2 * guestCount / castSize).ceil());
    for (var neighbor = 0; neighbor < math.max(2, reach); neighbor++) {
      final i = (index + neighbor) % guestCount;
      final g = _guests[i];
      g.interest = math.max(0, g.interest - (neighbor == 0 ? .09 : .035));
      _change(i, beat);
    }
  }

  void adorn(int index, double beat, {int chain = 1}) {
    final bounded = chain.clamp(1, 4);
    // The same share of the room looks over, in the same time.
    final share = guestCount / castSize;
    final reach = ((bounded >= 3 ? bounded : 2) * share).ceil();
    for (
      var neighbor = 0;
      neighbor < math.min(guestCount, math.max(2, reach));
      neighbor++
    ) {
      final g = _guests[(index + neighbor) % guestCount];
      final reference = neighbor / math.max(1.0, share);
      g.styleBeat = beat + reference * .23;
      g.styleStrength = neighbor == 0
          ? 1
          : reference <= 1
          ? .45 + bounded * .15
          : .5 - (reference - 2) * .15;
      g.styleDuration = 3.0 + bounded;
    }
  }

  void clearStyle() {
    for (final g in _guests) {
      g.styleStrength = 0;
    }
  }

  _Pose _loop(CrowdGuestState state, double beat, int index) {
    final local = beat + _guests[index].phaseOffset;
    final clip = switch (state) {
      CrowdGuestState.occupied => CrowdClip.seatedIdle,
      CrowdGuestState.curious => CrowdClip.notice,
      CrowdGuestState.following => CrowdClip.seatedFollow,
      CrowdGuestState.participating => const [
        CrowdClip.standingIdle,
        CrowdClip.stepTouch,
        CrowdClip.clap,
      ][(local / 4).floor() % 3],
      CrowdGuestState.celebrating =>
        (local / 4).floor().isEven ? CrowdClip.cheer : CrowdClip.clap,
    };
    final duration = switch (clip) {
      CrowdClip.seatedIdle => 8.0,
      CrowdClip.notice => 4.0,
      _ => 2.0,
    };
    return _Pose(
      state,
      clip,
      local,
      duration,
      false,
      state.index >= CrowdGuestState.participating.index,
    );
  }

  _Pose _sample(int index, double beat) {
    final g = _guests[index];
    var state = g.base;
    var loopStart = 0.0;
    for (final motion in g.motions) {
      if (beat < motion.start) break;
      if (beat < motion.start + motion.duration) {
        final age = beat - motion.start;
        final standing = motion.clip == CrowdClip.standUp
            ? age >= motion.duration * .65
            : motion.clip == CrowdClip.sitDown
            ? age < motion.duration * .5
            : motion.before.index >= CrowdGuestState.participating.index;
        return _Pose(
          motion.before,
          motion.clip,
          age,
          motion.duration,
          true,
          standing,
        );
      }
      state = motion.after;
      loopStart = motion.start + motion.duration;
    }
    return _loop(state, beat - loopStart, index);
  }

  void _change(int index, double beat) {
    final g = _guests[index];
    final ceiling = profile.ceiling(g.rank, guestCount);
    final reference = _referenceRank(g.rank);
    var next = g.interest >= .90
        ? CrowdGuestState.celebrating
        : g.interest >= .72
        ? CrowdGuestState.participating
        : g.interest >= .38 + math.min(reference, 6) * .015
        ? CrowdGuestState.following
        : g.interest >= .15 + math.min(reference, 8) * .035
        ? CrowdGuestState.curious
        : CrowdGuestState.occupied;
    if (next.index > ceiling.index) next = ceiling;
    final current = _sample(index, beat);
    if (next.index < current.state.index) {
      final floor = switch (current.state) {
        CrowdGuestState.celebrating => .82,
        CrowdGuestState.participating => .64,
        CrowdGuestState.following => .30,
        CrowdGuestState.curious => .08,
        CrowdGuestState.occupied => 0.0,
      };
      if (g.interest >= floor) next = current.state;
    }
    if (next == g.target) return;
    while (g.motions.isNotEmpty &&
        g.motions.first.start + g.motions.first.duration <= beat) {
      g.base = g.motions.first.after;
      g.motions.removeAt(0);
    }
    // Fractional delays spread the room over about twelve beats, whatever its size;
    // about a third of it begins a reaction in any four-beat bar. The last guest's
    // stand-up finishes inside the next phrase, ahead of a clear one phrase later.
    var cursor = beat + .35 + reference * 1.1 + ((index * 7) % 5) * .07;
    var state = current.state;
    final retained = <_Motion>[];
    if (g.motions.isNotEmpty &&
        next.index > g.target.index &&
        g.motions.last.start + g.motions.last.duration > beat) {
      // Finish the already promised look/lean/stand before adding enthusiasm.
      retained.addAll(g.motions);
      state = g.target;
      cursor = g.motions.last.start + g.motions.last.duration;
    } else {
      final active = g.motions.indexWhere(
        (motion) =>
            beat >= motion.start && beat < motion.start + motion.duration,
      );
      if (active >= 0) {
        // A setback may change the destination, never cut a standing motion
        // halfway through and teleport the guest back into their chair.
        retained.addAll(g.motions.take(active + 1));
        state = retained.last.after;
        cursor = retained.last.start + retained.last.duration;
      }
    }
    if (retained.isEmpty) g.base = current.state;
    g.target = next;
    g.motions = retained;
    g.reactionBeat = retained.isEmpty ? cursor : retained.first.start;
    g.noticedBy = g.rank == 0 ? null : _order[g.rank - 1];
    void add(CrowdClip clip, double duration, CrowdGuestState after) {
      g.motions.add(_Motion(clip, cursor, duration, state, after));
      cursor += duration;
      state = after;
    }

    if (state.index >= CrowdGuestState.participating.index &&
        next.index < CrowdGuestState.participating.index) {
      add(CrowdClip.sitDown, 2, next);
      return;
    }
    if (next.index < state.index) {
      add(
        next.index >= CrowdGuestState.participating.index
            ? CrowdClip.clap
            : next == CrowdGuestState.occupied
            ? CrowdClip.seatedIdle
            : CrowdClip.notice,
        1,
        next,
      );
      return;
    }
    while (state.index < next.index) {
      final after = CrowdGuestState.values[state.index + 1];
      switch (after) {
        case CrowdGuestState.curious:
          add(CrowdClip.notice, 2, after);
        case CrowdGuestState.following:
          add(CrowdClip.seatedFollow, 2, after);
        case CrowdGuestState.participating:
          add(CrowdClip.standUp, 2, after);
        case CrowdGuestState.celebrating:
          add(CrowdClip.clap, 1, state);
          add(CrowdClip.cheer, 1, after);
        case CrowdGuestState.occupied:
          break;
      }
    }
  }
}
