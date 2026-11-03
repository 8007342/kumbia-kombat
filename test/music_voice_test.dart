import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/voice_recipes.dart';

Map<String, dynamic> score(List<Map<String, dynamic>> tracks) => {
  'schemaVersion': 1,
  'id': 'fixture',
  'beatsPerBar': 4,
  'bars': 2,
  'phraseBars': 2,
  'tiers': [for (var i = 0; i < 5; i++) {'bpm': 100 + i}],
  'tracks': tracks,
  'events': [
    {'track': 'lead', 'beat': 0, 'pitch': 60, 'duration': 1, 'velocity': 80},
  ],
};

void main() {
  test('notes take their track voice from the score', () {
    final parsed = MusicScore.fromJson(
      score([
        {'id': 'lead', 'voice': 'pedalSteel'},
      ]),
    );
    expect(parsed.notes.single.voice, 'pedalSteel');
    expect(voiceRecipes[parsed.notes.single.voice], isNotNull);
  });

  test('a shipped voice has no recipe, so it keeps its track-based sound', () {
    final parsed = MusicScore.fromJson(
      score([
        {'id': 'lead', 'voice': 'reed'},
      ]),
    );
    expect(voiceRecipes[parsed.notes.single.voice], isNull);
  });

  test('a score without voices still parses', () {
    final parsed = MusicScore.fromJson(score([]));
    expect(parsed.notes.single.voice, isNull);
  });

  test('recipes stay single-oscillator and cheap', () {
    for (final entry in voiceRecipes.entries) {
      final recipe = entry.value;
      expect(
        ['sine', 'triangle', 'square', 'sawtooth'],
        contains(recipe.wave),
        reason: entry.key,
      );
      expect(recipe.gain, lessThanOrEqualTo(1.5), reason: entry.key);
      expect(recipe.attack, greaterThan(0), reason: entry.key);
    }
    expect(
      voiceRecipes.values.where((r) => r.drive).length,
      1,
      reason: 'only one voice pays for the extra shaper node',
    );
  });
}
