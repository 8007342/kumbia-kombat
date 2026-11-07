/// The rendered music's data, read from `assets/music/rendered/manifest.json`.
/// Pure Dart: nothing here touches a browser, so tests read it directly.
library;

import 'dart:math' as math;

/// A manifest entry is wrong. The game falls back to the synth rather than
/// playing music whose timing it can't trust.
class RenderedManifestError implements Exception {
  const RenderedManifestError(this.path, this.message);
  final String path;
  final String message;
  @override
  String toString() => 'RenderedManifestError at $path: $message';
}

/// One run of a job per key, shared by whoever asks while it's in progress. In
/// plain Dart so a test can run it: the web backend can't run under `flutter test`.
class SingleFlight {
  final _running = <String, Future<void>>{};

  Future<void> run(String key, Future<void> Function() job) =>
      _running[key] ??= job().whenComplete(() {
        // A block, not an arrow: `remove` returns this very future, and
        // whenComplete would wait for it, which is to say forever.
        _running.remove(key);
      });
}

double dbToGain(double db) => math.pow(10, db / 20).toDouble();

/// One audio file on the music clock: a looping take, a transition, a success
/// tag or a bridge. Constant tempo and whole bars, so a beat always has one time.
class RenderedClip {
  RenderedClip({
    required this.id,
    required this.bpm,
    required this.bars,
    required this.beatsPerBar,
    required this.files,
    this.startSeconds = 0,
    this.loopEndSeconds,
    this.endSeconds,
    this.decodeOffsetSamples = const {},
    this.gainDb = 0,
  });

  final String id;

  /// With loop points, the tempo the loop really runs at, so that the beat clock
  /// and a natively looping buffer can't drift apart however long a run lasts.
  final double bpm;
  final int bars;
  final int beatsPerBar;

  /// Format name (`opus`, `aac`) to asset path.
  final Map<String, String> files;

  /// Where beat 0 is in the file. Audio before and after is padding, there to
  /// keep codec edges off the loop and to give fades something to fade over.
  final double startSeconds;
  final double? loopEndSeconds;

  /// A clip that doesn't loop stops here, which may be past its last beat.
  final double? endSeconds;

  /// What a format's decoder adds at the head of the file, in 48 kHz samples.
  final Map<String, int> decodeOffsetSamples;
  double gainDb;

  bool get loops => loopEndSeconds != null;
  double get lengthBeats => (bars * beatsPerBar).toDouble();
  double get secondsPerBeat => 60 / bpm;
  double get lengthSeconds => lengthBeats * secondsPerBeat;

  /// Where in the file a beat counted from the clip's start falls.
  double fileSecondsAt(double beats) {
    final within = loops ? beats % lengthBeats : beats;
    return startSeconds + math.max(0.0, within) * secondsPerBeat;
  }

  double decodeOffsetSeconds(String format) =>
      (decodeOffsetSamples[format] ?? 0) / 48000;

  static RenderedClip fromJson(String id, String path, Object? raw) {
    final json = _object(path, raw);
    final bars = json['bars'];
    final beatsPerBar = json['beatsPerBar'] ?? 4;
    if (bars is! int || bars <= 0 || beatsPerBar is! int || beatsPerBar <= 0) {
      throw RenderedManifestError(path, 'bars must be a whole number');
    }
    final declared = _number('$path.bpm', json['bpm'], min: 20, max: 400);
    final end = json['loopEndSeconds'];
    final startRaw = json['loopStartSeconds'] ?? json['startSeconds'];
    final start = startRaw == null
        ? 0.0
        : _number('$path.startSeconds', startRaw, min: 0);
    var bpm = declared;
    double? loopEnd;
    if (end != null) {
      loopEnd = _number('$path.loopEndSeconds', end);
      final seconds = loopEnd - start;
      if (seconds <= 0) {
        throw RenderedManifestError(path, 'the loop ends before it starts');
      }
      bpm = bars * beatsPerBar * 60 / seconds;
      if ((bpm - declared).abs() > declared * .005) {
        throw RenderedManifestError(
          path,
          'loop points give $bpm BPM, but it declares $declared',
        );
      }
    }
    final files = _object('$path.files', json['files']);
    if (files.isEmpty) throw RenderedManifestError(path, 'lists no files');
    return RenderedClip(
      id: id,
      bpm: bpm,
      bars: bars,
      beatsPerBar: beatsPerBar,
      files: {
        for (final entry in files.entries)
          entry.key: _text('$path.files.${entry.key}', entry.value),
      },
      startSeconds: start,
      loopEndSeconds: loopEnd,
      endSeconds: json['endSeconds'] == null
          ? null
          : _number('$path.endSeconds', json['endSeconds'], min: start),
      decodeOffsetSamples: {
        for (final entry
            in _object(
              '$path.decodeOffsetSamples',
              json['decodeOffsetSamples'] ?? const <String, Object?>{},
            ).entries)
          entry.key: _number(
            '$path.decodeOffsetSamples.${entry.key}',
            entry.value,
          ).round(),
      },
      gainDb: json['gainDb'] == null
          ? 0
          : _number('$path.gainDb', json['gainDb'], min: -60, max: 24),
    );
  }

  /// The first format this browser says it can play, in the manifest's order.
  String? pathFor(bool Function(String format) canPlay) {
    for (final entry in files.entries) {
      if (canPlay(entry.key)) return entry.value;
    }
    return null;
  }
}

/// A written join between two takes.
class RenderedTransition {
  RenderedTransition({
    required this.from,
    required this.to,
    required this.clip,
    this.entryBar = 0,
    this.crossfadeSeconds = RenderedLevel.defaultJoinSeconds,
  });
  final String from;
  final String to;
  final RenderedClip clip;

  /// The bar of the destination's loop this lands on.
  final int entryBar;
  final double crossfadeSeconds;
}

/// A join with no audio of its own: the outgoing take plays right up to the
/// boundary, so leaving at any bar can't jump, and the incoming take starts at the
/// bar written for that exit. The table comes from `tool/music/mix/`, which picks
/// the closest harmony, spectrum and level for each exit bar.
class RenderedCut {
  RenderedCut({
    required this.from,
    required this.to,
    required this.entryBars,
    this.exitStep = 2,
    this.fadeInBeats = 0,
    this.fadeOutBeats = 1,
  }) {
    if (entryBars.isEmpty || exitStep <= 0) {
      throw RenderedManifestError('$from-$to', 'needs an entry for each exit');
    }
  }
  final String from;
  final String to;

  /// The incoming bar for each exit, one entry per [exitStep] bars of the loop.
  final List<int> entryBars;
  final int exitStep;
  final double fadeInBeats;
  final double fadeOutBeats;

  int entryFor(int exitBar) =>
      entryBars[(exitBar ~/ exitStep) % entryBars.length];

  static RenderedCut fromJson(String path, Object? raw) {
    final json = _object(path, raw);
    final bars = json['entryBars'];
    if (bars is! List || bars.any((bar) => bar is! int || bar < 0)) {
      throw RenderedManifestError(path, 'entryBars must be whole bars');
    }
    return RenderedCut(
      from: _text('$path.from', json['from']),
      to: _text('$path.to', json['to']),
      entryBars: bars.cast<int>(),
      exitStep: json['exitStep'] as int? ?? 2,
      fadeInBeats: json['fadeInBeats'] == null
          ? 0
          : _number('$path.fadeInBeats', json['fadeInBeats'], min: 0, max: 32),
      fadeOutBeats: json['fadeOutBeats'] == null
          ? 1
          : _number('$path.fadeOutBeats', json['fadeOutBeats'], min: 0, max: 32),
    );
  }
}

/// One level's music. Five game tiers map onto its takes through [tierTakes], so
/// tempo is data: nothing assumes a higher tier is a faster take.
class RenderedLevel {
  RenderedLevel({
    required this.id,
    required this.tierTakes,
    required this.takes,
    this.transitions = const [],
    this.success,
    this.bridge,
    this.bridgeTo,
    this.bridgeEntryBar = 0,
    this.mix,
    this.cuts = const [],
    this.layerFadeBeats,
  }) {
    if (tierTakes.length != 5) {
      throw RenderedManifestError(id, 'tierTakes must name five takes');
    }
    for (final take in tierTakes) {
      if (!takes.containsKey(take)) {
        throw RenderedManifestError(id, 'tierTakes names unknown take $take');
      }
    }
    for (final join in transitions) {
      if (!takes.containsKey(join.from) || !takes.containsKey(join.to)) {
        throw RenderedManifestError(id, 'a transition names an unknown take');
      }
    }
    for (final cut in cuts) {
      if (!takes.containsKey(cut.from) || !takes.containsKey(cut.to)) {
        throw RenderedManifestError(id, 'a cut names an unknown take');
      }
      if (cut.entryBars.any((bar) => bar >= takes[cut.to]!.bars)) {
        throw RenderedManifestError(id, 'a cut lands past the end of ${cut.to}');
      }
    }
    if (layerFadeBeats != null) {
      final bars = {for (final take in takes.values) take.bars};
      if (bars.length != 1) {
        throw RenderedManifestError(id, 'layered takes must share their bars');
      }
    }
  }

  /// A join with nothing written for it: quick enough not to double a beat.
  static const defaultJoinSeconds = .02;

  final String id;
  final List<String> tierTakes;
  final Map<String, RenderedClip> takes;
  final List<RenderedTransition> transitions;
  final RenderedClip? success;
  final RenderedClip? bridge;

  /// The level [bridge] leads to, and the bar of its first take it lands on.
  final String? bridgeTo;
  final int bridgeEntryBar;
  final RenderedMix? mix;
  final List<RenderedCut> cuts;

  /// Set when the takes are one performance on one grid: a change of tier stays
  /// on the same bar, crossfading over this many beats, with no clip of its own.
  final double? layerFadeBeats;
  bool get layered => layerFadeBeats != null;

  RenderedClip takeForTier(int tier) => takes[tierTakes[tier]]!;
  List<double> get tempos => [for (var t = 0; t < 5; t++) takeForTier(t).bpm];

  RenderedTransition? transition(String from, String to) {
    for (final join in transitions) {
      if (join.from == from && join.to == to) return join;
    }
    return null;
  }

  RenderedCut? cut(String from, String to) {
    for (final cut in cuts) {
      if (cut.from == from && cut.to == to) return cut;
    }
    return null;
  }

  Iterable<RenderedClip> get clips => [
    ...takes.values,
    ...transitions.map((join) => join.clip),
    ?success,
    ?bridge,
  ];

  factory RenderedLevel.fromJson(String id, String path, Object? raw) {
    final json = _object(path, raw);
    final takes = _object('$path.takes', json['takes']);
    final tierTakes = json['tierTakes'];
    if (tierTakes is! List) {
      throw RenderedManifestError(path, 'tierTakes must be a list');
    }
    RenderedClip? single(String key) => json[key] == null
        ? null
        : RenderedClip.fromJson('$id/$key', '$path.$key', json[key]);
    return RenderedLevel(
      id: id,
      tierTakes: [for (final take in tierTakes) '$take'],
      takes: {
        for (final entry in takes.entries)
          entry.key: RenderedClip.fromJson(
            '$id/${entry.key}',
            '$path.takes.${entry.key}',
            entry.value,
          ),
      },
      transitions: [
        for (final (i, raw) in ((json['transitions'] as List?) ?? []).indexed)
          _transition(id, '$path.transitions[$i]', raw),
      ],
      success: single('success'),
      bridge: single('bridge'),
      bridgeTo: json['bridge'] == null
          ? null
          : _object('$path.bridge', json['bridge'])['to'] as String?,
      bridgeEntryBar: json['bridge'] == null
          ? 0
          : _object('$path.bridge', json['bridge'])['entryBar'] as int? ?? 0,
      mix: json['mix'] == null
          ? null
          : RenderedMix.fromJson('$path.mix', json['mix']),
      cuts: [
        for (final (i, raw) in ((json['cuts'] as List?) ?? []).indexed)
          RenderedCut.fromJson('$path.cuts[$i]', raw),
      ],
      layerFadeBeats: json['layerFadeBeats'] == null
          ? null
          : _number('$path.layerFadeBeats', json['layerFadeBeats'], min: 0, max: 32),
    );
  }

  static RenderedTransition _transition(String id, String path, Object? raw) {
    final json = _object(path, raw);
    final from = _text('$path.from', json['from']);
    final to = _text('$path.to', json['to']);
    return RenderedTransition(
      from: from,
      to: to,
      clip: RenderedClip.fromJson('$id/$from-$to', path, raw),
      entryBar: json['entryBar'] as int? ?? 0,
      crossfadeSeconds: json['crossfadeSeconds'] == null
          ? defaultJoinSeconds
          : _number('$path.crossfadeSeconds', json['crossfadeSeconds'], min: 0),
    );
  }
}

/// The buses' levels, in decibels. Only gain: nothing here reaches the clock.
class RenderedMix {
  const RenderedMix({
    this.masterDb = 0,
    this.musicDb = 0,
    this.accentsDb = 0,
    this.rewardsDb = 0,
  });
  final double masterDb;
  final double musicDb;
  final double accentsDb;
  final double rewardsDb;

  RenderedMix copyWith({
    double? masterDb,
    double? musicDb,
    double? accentsDb,
    double? rewardsDb,
  }) => RenderedMix(
    masterDb: masterDb ?? this.masterDb,
    musicDb: musicDb ?? this.musicDb,
    accentsDb: accentsDb ?? this.accentsDb,
    rewardsDb: rewardsDb ?? this.rewardsDb,
  );

  Map<String, double> toJson() => {
    'masterDb': masterDb,
    'musicDb': musicDb,
    'accentsDb': accentsDb,
    'rewardsDb': rewardsDb,
  };

  factory RenderedMix.fromJson(String path, Object? raw) {
    final json = _object(path, raw);
    double level(String key) => json[key] == null
        ? 0
        : _number('$path.$key', json[key], min: -60, max: 24);
    return RenderedMix(
      masterDb: level('masterDb'),
      musicDb: level('musicDb'),
      accentsDb: level('accentsDb'),
      rewardsDb: level('rewardsDb'),
    );
  }
}

class RenderedManifest {
  const RenderedManifest({
    this.mix = const RenderedMix(),
    this.levels = const {},
  });
  final RenderedMix mix;
  final Map<String, RenderedLevel> levels;

  RenderedMix mixFor(String level) => levels[level]?.mix ?? mix;

  factory RenderedManifest.fromJson(Object? raw) {
    final json = _object('manifest', raw);
    if (json['schemaVersion'] != 1) {
      throw const RenderedManifestError('manifest', 'unsupported version');
    }
    final levels = _object('manifest.levels', json['levels'] ?? const {});
    return RenderedManifest(
      mix: json['mix'] == null
          ? const RenderedMix()
          : RenderedMix.fromJson('manifest.mix', json['mix']),
      levels: {
        for (final entry in levels.entries)
          entry.key: RenderedLevel.fromJson(
            entry.key,
            'manifest.levels.${entry.key}',
            entry.value,
          ),
      },
    );
  }
}

Map<String, Object?> _object(String path, Object? raw) {
  if (raw is Map<String, Object?>) return raw;
  throw RenderedManifestError(path, 'expected an object, found $raw');
}

String _text(String path, Object? raw) {
  if (raw is String && raw.isNotEmpty) return raw;
  throw RenderedManifestError(path, 'expected text, found $raw');
}

double _number(String path, Object? raw, {double? min, double? max}) {
  if (raw is! num || !raw.isFinite) {
    throw RenderedManifestError(path, 'expected a number, found $raw');
  }
  final value = raw.toDouble();
  if ((min != null && value < min) || (max != null && value > max)) {
    throw RenderedManifestError(path, '$value is out of range');
  }
  return value;
}
