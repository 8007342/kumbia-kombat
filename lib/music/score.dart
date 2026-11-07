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
  });
  final String track;
  final double beat;
  final int pitch;
  final double duration;
  final int velocity;
  final int minTier;
  final int maxTier;

  factory ScoreNote.fromJson(Map<String, dynamic> json) => ScoreNote(
    track: json['track'] as String,
    beat: (json['beat'] as num).toDouble(),
    pitch: json['pitch'] as int,
    duration: (json['duration'] as num).toDouble(),
    velocity: json['velocity'] as int,
    minTier: json['minTier'] as int? ?? 0,
    maxTier: json['maxTier'] as int? ?? 4,
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
    List<int> sectionBars = const [],
  }) : tempos = List.unmodifiable(tempos),
       notes = List.unmodifiable(notes),
       sectionBars = List.unmodifiable(sectionBars) {
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

  /// First bar of each named section, in score order. Empty when not authored.
  final List<int> sectionBars;
  double get lengthBeats => (bars * beatsPerBar).toDouble();
  double get phraseBeats => (phraseBars * beatsPerBar).toDouble();

  /// The section playing at an absolute beat, wrapping with the score's loop.
  int sectionAt(double beat) {
    var index = 0;
    final bar = (beat % lengthBeats) / beatsPerBar;
    for (var i = 0; i < sectionBars.length; i++) {
      if (sectionBars[i] <= bar) index = i;
    }
    return index;
  }

  /// The same score with [extra] mixed in, for hits tied to the picture.
  MusicScore withNotes(List<ScoreNote> extra) => MusicScore(
    id: id,
    beatsPerBar: beatsPerBar,
    bars: bars,
    phraseBars: phraseBars,
    tempos: tempos,
    notes: [...notes, ...extra]..sort((a, b) => a.beat.compareTo(b.beat)),
    sectionBars: sectionBars,
  );

  /// The same song at other tempos: a level's rendered takes set the clock, and
  /// the synth falling back from them must keep that clock's chart times.
  MusicScore withTempos(List<double> values) => MusicScore(
    id: id,
    beatsPerBar: beatsPerBar,
    bars: bars,
    phraseBars: phraseBars,
    tempos: values,
    notes: notes,
    sectionBars: sectionBars,
  );

  /// An empty score the length of a rendered clip, to hold its clock and cues.
  factory MusicScore.silent({
    required String id,
    required int beatsPerBar,
    required int bars,
    required double bpm,
  }) => MusicScore(
    id: id,
    beatsPerBar: beatsPerBar,
    bars: bars,
    phraseBars: bars,
    tempos: List.filled(5, bpm),
    notes: const [],
  );

  factory MusicScore.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported music score version');
    }
    return MusicScore(
      id: json['id'] as String,
      beatsPerBar: json['beatsPerBar'] as int,
      bars: json['bars'] as int,
      phraseBars: json['phraseBars'] as int,
      tempos: (json['tiers'] as List)
          .map((t) => (t['bpm'] as num).toDouble())
          .toList(),
      notes: (json['events'] as List)
          .map((n) => ScoreNote.fromJson(n as Map<String, dynamic>))
          .toList(),
      sectionBars: [
        for (final section in json['sections'] as List? ?? const [])
          section['bar'] as int,
      ],
    );
  }
}
