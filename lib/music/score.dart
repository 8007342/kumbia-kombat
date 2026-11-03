/// Immutable, tick-independent score data shared by every synthesis backend.
class ScoreNote {
  const ScoreNote({
    required this.track,
    required this.beat,
    required this.pitch,
    required this.duration,
    required this.velocity,
    this.minTier = 0,
    this.maxTier = 4,
    this.voice,
  });
  final String track;
  final double beat;
  final int pitch;
  final double duration;
  final int velocity;
  final int minTier;
  final int maxTier;

  /// The track's synth voice, when its score names one.
  final String? voice;

  factory ScoreNote.fromJson(Map<String, dynamic> json) => ScoreNote(
    track: json['track'] as String,
    beat: (json['beat'] as num).toDouble(),
    pitch: json['pitch'] as int,
    duration: (json['duration'] as num).toDouble(),
    velocity: json['velocity'] as int,
    minTier: json['minTier'] as int? ?? 0,
    maxTier: json['maxTier'] as int? ?? 4,
    voice: json['voice'] as String?,
  );

  bool audibleAt(int tier) => minTier <= tier && tier <= maxTier;
}

class MusicScore {
  MusicScore({
    required this.id,
    required this.beatsPerBar,
    required this.bars,
    required this.phraseBars,
    required List<double> tempos,
    required List<ScoreNote> notes,
  }) : tempos = List.unmodifiable(tempos),
       notes = List.unmodifiable(notes) {
    if (bars <= 0 ||
        beatsPerBar <= 0 ||
        phraseBars <= 0 ||
        bars % phraseBars != 0 ||
        tempos.length != 5 ||
        tempos.any((t) => !t.isFinite || t <= 0)) {
      throw ArgumentError('Invalid score structure or tempo tiers');
    }
    var previous = -1.0;
    for (final n in this.notes) {
      if (!n.beat.isFinite ||
          !n.duration.isFinite ||
          n.beat < previous ||
          n.beat < 0 ||
          n.duration <= 0 ||
          n.beat + n.duration > lengthBeats ||
          n.pitch < 0 ||
          n.pitch > 127 ||
          n.velocity < 1 ||
          n.velocity > 127 ||
          n.minTier < 0 ||
          n.maxTier > 4 ||
          n.minTier > n.maxTier) {
        throw ArgumentError('Invalid or unsorted note in $id');
      }
      previous = n.beat;
    }
  }
  final String id;
  final int beatsPerBar;
  final int bars;
  final int phraseBars;
  final List<double> tempos;
  final List<ScoreNote> notes;
  double get lengthBeats => (bars * beatsPerBar).toDouble();
  double get phraseBeats => (phraseBars * beatsPerBar).toDouble();

  factory MusicScore.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported music score version');
    }
    final voices = <String, String>{
      for (final t in (json['tracks'] as List? ?? const []))
        if ((t as Map)['voice'] != null) t['id'] as String: t['voice'] as String,
    };
    return MusicScore(
      id: json['id'] as String,
      beatsPerBar: json['beatsPerBar'] as int,
      bars: json['bars'] as int,
      phraseBars: json['phraseBars'] as int,
      tempos: (json['tiers'] as List)
          .map((t) => (t['bpm'] as num).toDouble())
          .toList(),
      notes: (json['events'] as List)
          .map(
            (n) => ScoreNote.fromJson({
              ...n as Map<String, dynamic>,
              'voice': voices[n['track']],
            }),
          )
          .toList(),
    );
  }
}
