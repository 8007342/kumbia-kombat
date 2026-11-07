import 'challenger_choreography.dart';
import 'rhythm.dart';

/// One drawn dance clip. Loops index from the absolute music beat, so a groove
/// keeps its phase however it is entered. One-shots index from their own start.
class DanceClip {
  DanceClip._(this.frames, this.durations, this.phase);
  final List<String> frames;
  final List<double> durations;
  final double phase;
  late final double lengthBeats = durations.fold(0.0, (a, b) => a + b);

  factory DanceClip.fromJson(String name, Map<String, dynamic> data) {
    final frames = List<String>.from(data['frames'] as List);
    final each = (data['beatsPerFrame'] as num?)?.toDouble();
    final beats = (data['beats'] as List?)
        ?.map((b) => (b as num).toDouble())
        .toList();
    final durations = beats ?? [for (final _ in frames) each ?? 1.0];
    if (frames.isEmpty ||
        durations.length != frames.length ||
        durations.any((d) => !d.isFinite || d <= 0)) {
      throw FormatException('Invalid dance clip $name');
    }
    return DanceClip._(
      List.unmodifiable(frames),
      List.unmodifiable(durations),
      (data['phase'] as num?)?.toDouble() ?? 0,
    );
  }

  String _at(double position) {
    var remaining = position;
    for (var i = 0; i < frames.length; i++) {
      remaining -= durations[i];
      if (remaining < 0) return frames[i];
    }
    return frames.last;
  }

  String loop(double beat) => _at((beat + phase) % lengthBeats);
  String once(double age) => _at(age < 0 ? 0 : age);
  String along(double progress) =>
      frames[(progress * frames.length).floor().clamp(0, frames.length - 1)];
}

class DanceAccent {
  const DanceAccent(this.everyBeats, this.atBeat, this.minTier, this.clip);
  final double everyBeats;
  final double atBeat;
  final int minTier;
  final String clip;
}

class _Dancer {
  _Dancer(this.clips, this.frames, this.accents, this.handoffMoves);
  final Map<String, DanceClip> clips;
  final Map<String, String> frames;

  /// This dancer's own flares. They come ahead of the shared accents.
  final List<DanceAccent> accents;

  /// Finishes danced on the mark as the call ends, by the lowest tier for each.
  final List<DanceHandoffMove> handoffMoves;

  DanceClip? handoffClip(int tier) {
    for (final move in handoffMoves) {
      if (tier >= move.minTier) return clips[move.clip];
    }
    return null;
  }
}

class DanceHandoffMove {
  const DanceHandoffMove(this.minTier, this.clip);
  final int minTier;
  final String clip;
}

/// The art layer over the call: groove, accents, travel and celebration, read
/// from `assets/art/ensemble/choreography.json`. Each result is a pure function
/// of the music beat and the sampled pose, so frame skips lose nothing and a
/// frozen transport freezes the dance (B1). The session never reads it, and a
/// call's accent passes through untouched, so it cannot change notes or score.
class DanceGrammar {
  DanceGrammar._(this._data, this._dancers);
  final Map<String, dynamic> _data;
  final Map<String, _Dancer> _dancers;

  Map<String, dynamic> get _rules => _data['rules'] as Map<String, dynamic>;
  static List<DanceAccent> _accentsFrom(List raw) => [
    for (final a in raw)
      DanceAccent(
        (a['everyBeats'] as num).toDouble(),
        (a['atBeat'] as num).toDouble(),
        a['minTier'] as int,
        a['clip'] as String,
      ),
  ];
  late final List<DanceAccent> _accents = _accentsFrom(
    _rules['accents'] as List,
  );
  List<DanceAccent> get accents => _accents;

  factory DanceGrammar.fromJson(Map<String, dynamic> data) {
    final raw = data['dancers'];
    if (data['version'] != 1 || raw is! Map) {
      throw const FormatException('Unsupported choreography data');
    }
    Map<String, DanceClip> clips(Map? source) => {
      for (final entry in (source ?? const {}).entries)
        entry.key as String: DanceClip.fromJson(
          entry.key as String,
          Map<String, dynamic>.from(entry.value as Map),
        ),
    };
    final shared = clips(data['clips'] as Map);
    final dancers = <String, _Dancer>{};
    for (final entry in raw.entries) {
      final dancer = Map<String, dynamic>.from(entry.value as Map);
      dancers[entry.key as String] = _Dancer(
        {...shared, ...clips(dancer['clips'] as Map?)},
        Map<String, String>.from(dancer['frames'] as Map? ?? const {}),
        _accentsFrom(dancer['accents'] as List? ?? const []),
        [
          for (final m in dancer['handoffMoves'] as List? ?? const [])
            DanceHandoffMove(m['minTier'] as int, m['clip'] as String),
        ],
      );
    }
    final grammar = DanceGrammar._(data, dancers);
    grammar._checkRules();
    return grammar;
  }

  void _checkRules() {
    final rules = _rules;
    final byTier = rules['responseByTier'] as List;
    if ((rules['restByTier'] as List).length != 5 ||
        (rules['finishByTier'] as List).length != 5 ||
        byTier.length != 5 ||
        byTier.any((cells) => (cells as List).isEmpty)) {
      throw const FormatException('Choreography needs all five tiers');
    }
    final named = {
      rules['idle'],
      rules['approve'],
      rules['recover'],
      ...rules['restByTier'] as List,
      for (final cells in byTier) ...cells as List,
      for (final a in accents) a.clip,
      for (final s in rules['celebrationIntro'] as List) s['clip'],
      for (final s in rules['celebrationLoop'] as List) s['clip'],
      'yield_out',
      'return_in',
    };
    for (final dancer in _dancers.values) {
      for (final name in [
        ...named,
        ...dancer.accents.map((a) => a.clip),
        ...dancer.handoffMoves.map((m) => m.clip),
      ]) {
        if (!dancer.clips.containsKey(name)) {
          throw FormatException('Choreography rule names missing clip $name');
        }
      }
    }
    for (final a in accents) {
      if (!a.everyBeats.isFinite || a.everyBeats <= 0 || a.minTier < 0) {
        throw const FormatException('Invalid choreography accent');
      }
    }
  }

  /// How long [dancer] holds the mark past the call's last note at [tier], for
  /// the sampler. Zero when this dancer has no finish for that tier.
  double handoffBeats(String dancer, int tier) =>
      _require(dancer).handoffClip(tier.clamp(0, 4))?.lengthBeats ?? 0;

  /// A named clip's drawing at [beat], looped from the absolute beat.
  String clipFrame(String dancer, String clip, double beat) {
    final d = _require(dancer);
    return _alias(d, _requireClip(d, clip).loop(beat));
  }

  /// A named clip's drawing, [progress] of the way along, for a walk.
  String clipAlong(String dancer, String clip, double progress) {
    final d = _require(dancer);
    return _alias(d, _requireClip(d, clip).along(progress));
  }

  /// The one still drawing for someone standing by under reduced motion.
  String calmFrame(String dancer) =>
      _alias(_require(dancer), _rules['reducedMotionHold'] as String);

  /// How long one pass of this dancer's clip is, in beats.
  double clipBeats(String dancer, String clip) =>
      _requireClip(_require(dancer), clip).lengthBeats;

  /// Fails closed when a level names a clip this dancer doesn't have.
  void requireClips(String dancer, Iterable<String> clips) {
    final d = _require(dancer);
    for (final clip in clips) {
      _requireClip(d, clip);
    }
  }

  DanceClip _requireClip(_Dancer d, String clip) =>
      d.clips[clip] ?? (throw StateError('No dance clip $clip'));

  /// Every drawing this grammar can name for [dancer], before art lookups.
  Set<String> framesFor(String dancer) {
    final d = _require(dancer);
    final hit = _data['hit'] as Map<String, dynamic>;
    final rules = _rules;
    return {
      for (final clip in d.clips.values)
        ...clip.frames.map((f) => _alias(d, f)),
      ...d.frames.values,
      for (final template in hit.values)
        for (final limb in [
          'left_hand',
          'right_hand',
          'left_foot',
          'right_foot',
        ])
          (template as String).replaceAll('{limb}', limb),
      ...((_data['pairHit'] as Map?)?.values.cast<String>() ?? const <String>[]),
      ...List<String>.from(rules['finishByTier'] as List),
      rules['reducedMotionHold'] as String,
      rules['reducedMotionCelebration'] as String,
    };
  }

  /// Fails closed like the sprite manifest: a typo must not paint nothing.
  void requireFrames(String dancer, Iterable<String> available) {
    final missing = framesFor(dancer).difference(available.toSet());
    if (missing.isNotEmpty) {
      throw FormatException('Choreography for $dancer misses $missing');
    }
    // Accent drawings stay reserved for the call, so a groove can't read as one.
    final reserved = [
      for (final limb in ['left_hand', 'right_hand', 'left_foot', 'right_foot'])
        for (final id in [limb, '${limb}_peak']) id,
    ];
    final clips = _require(dancer).clips;
    final groove = {
      _rules['idle'],
      ..._rules['restByTier'] as List,
      for (final cells in _rules['responseByTier'] as List) ...cells as List,
    };
    for (final name in groove) {
      if (clips[name]!.frames.any(reserved.contains)) {
        throw FormatException('Clip $name shows a call accent as groove');
      }
    }
  }

  _Dancer _require(String dancer) {
    final d = _dancers[dancer];
    if (d == null) throw StateError('No choreography for dancer $dancer');
    return d;
  }

  String _alias(_Dancer d, String frame) => d.frames[frame] ?? frame;

  /// Returns [pose] with its drawing chosen by this layer. Only `frameId`
  /// changes, so marks, timing, roles and the hero's staging stay the sampler's.
  ChallengerPose dress(
    ChallengerPose pose, {
    required String dancer,
    required double beat,
    required double callStartBeat,
    double callBeats = 8,
    int tier = 0,
    int section = 0,
    double? outcomeBeat,
    bool reducedMotion = false,
  }) {
    final d = _require(dancer);
    final pair = _pairFrame(pose);
    if (pair != null) return pose.withFrame(_alias(d, pair));
    if (pose.movePhase == DanceMovePhase.accent) return pose;
    final frame = _frame(
      d,
      pose,
      beat,
      beat - callStartBeat - callBeats,
      tier.clamp(0, 4),
      section,
      outcomeBeat == null ? null : beat - outcomeBeat,
      reducedMotion,
    );
    return pose.withFrame(_alias(d, frame));
  }

  /// Both hands at once: the clap every dancer already has, with its contact on
  /// the note. Any other pair dances its own limb's accent.
  String? _pairFrame(ChallengerPose pose) {
    bool hand(Limb? l) => l == Limb.leftHand || l == Limb.rightHand;
    if (!hand(pose.limb) || !hand(pose.partnerLimb)) return null;
    return (_data['pairHit'] as Map?)?[pose.movePhase.name] as String?;
  }

  String _frame(
    _Dancer d,
    ChallengerPose pose,
    double beat,
    double responseAge,
    int tier,
    int section,
    double? outcomeAge,
    bool reduced,
  ) {
    final rules = _rules;
    String loopOf(String clip) => d.clips[clip]!.loop(beat);

    // Hit: the drawn clip for that limb around the exact accent.
    final limb = pose.limb;
    if (limb != null && pose.movePhase != DanceMovePhase.idle) {
      if (pose.restBeats != null && !reduced) {
        return loopOf((rules['restByTier'] as List)[tier] as String);
      }
      final template = (_data['hit'] as Map)[pose.movePhase.name] as String;
      return template.replaceAll('{limb}', limbAccentFrame(limb));
    }

    // Celebration: no judged input can reach this.
    if (pose.playerRole == PlayerDanceRole.celebrating) {
      if (reduced) return rules['reducedMotionCelebration'] as String;
      return _celebration(d, beat, outcomeAge ?? 0);
    }

    switch (pose.state) {
      case ChallengerDanceState.occupied:
        return reduced ? pose.frameId : loopOf(rules['idle'] as String);
      case ChallengerDanceState.finish:
        return (rules['finishByTier'] as List)[tier] as String;
      case ChallengerDanceState.cede:
      case ChallengerDanceState.invite:
        final until = (_data['travelOutUntilYield'] as num).toDouble();
        if (!reduced && pose.floorYield < until) {
          return d.clips['yield_out']!.along(pose.floorYield / until);
        }
        return pose.frameId;
      case ChallengerDanceState.ready:
        if (!reduced && pose.floorYield > 0) {
          return d.clips['return_in']!.along(1 - pose.floorYield);
        }
        return pose.frameId;
      case ChallengerDanceState.approve:
        return reduced
            ? pose.frameId
            : d.clips[rules['approve'] as String]!.once(outcomeAge ?? 0);
      case ChallengerDanceState.recover:
        return reduced
            ? pose.frameId
            : d.clips[rules['recover'] as String]!.once(outcomeAge ?? 0);
      case ChallengerDanceState.handoffMove:
        return d.handoffClip(tier)?.once(pose.moveAge) ?? pose.frameId;
      case ChallengerDanceState.watch:
        if (reduced) return rules['reducedMotionHold'] as String;
        final hold = (_data['inviteHoldBeats'] as num).toDouble();
        if (responseAge >= 0 && responseAge < hold) return 'invite';
        for (final accent in [...d.accents, ...accents]) {
          if (tier < accent.minTier) continue;
          final clip = d.clips[accent.clip]!;
          // The clip's phase is the lead-in to its beat.
          final since = (beat - accent.atBeat + clip.phase) % accent.everyBeats;
          if (since < clip.lengthBeats) return clip.once(since);
        }
        final cells = (rules['responseByTier'] as List)[tier] as List;
        final cellBeats = (rules['responseCellBeats'] as num).toDouble();
        final cell = (beat / cellBeats).floor() + section;
        return loopOf(cells[cell % cells.length] as String);
      case ChallengerDanceState.demonstrate:
      case ChallengerDanceState.settle:
        return pose.frameId;
    }
  }

  String _celebration(_Dancer d, double beat, double age) {
    var remaining = age < 0 ? 0.0 : age;
    final intro = _rules['celebrationIntro'] as List;
    var introBeats = 0.0;
    for (final step in intro) {
      final length = (step['beats'] as num).toDouble();
      introBeats += length;
      if (remaining < length) {
        final clip = d.clips[step['clip']]!;
        return clip.once(remaining * clip.lengthBeats / length);
      }
      remaining -= length;
    }
    // Hold the intro's last drawing up to a whole beat, so the loop enters on
    // the grid instead of flashing a cut-off frame.
    final lastIntro = d.clips[intro.last['clip']]!;
    if (beat < (beat - age + introBeats).ceilToDouble()) {
      return lastIntro.frames.last;
    }
    final steps = _rules['celebrationLoop'] as List;
    final total = steps.fold<double>(
      0,
      (sum, s) => sum + (s['beats'] as num).toDouble(),
    );
    var position = beat % total;
    for (final step in steps) {
      final length = (step['beats'] as num).toDouble();
      if (position < length) return d.clips[step['clip']]!.loop(beat);
      position -= length;
    }
    return d.clips[steps.last['clip']]!.loop(beat);
  }
}
