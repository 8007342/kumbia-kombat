import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/exit_shot.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/music/score.dart';

void main() {
  final level = LevelDefinition.fromJson(
    jsonDecode(File('levels/garden.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final shot = level.exitShot!;

  test('the fists meet exactly on the contact beat, in the impact drawing', () {
    final hit = shot.sample(shot.contactBeat, reducedMotion: false);
    expect(hit, hasLength(2));
    for (final place in hit) {
      expect(place.offset, ui.Offset.zero);
      expect(place.image, place.actor.impact);
    }
  });

  test('the fists start apart and only ever close before the hit', () {
    double gap(double beat) {
      final places = shot.sample(beat, reducedMotion: false);
      return (places[0].offset - places[1].offset).distance;
    }

    var previous = double.infinity;
    for (var beat = shot.closeupFrom; beat <= shot.contactBeat; beat += .05) {
      final now = gap(beat);
      expect(now, lessThanOrEqualTo(previous));
      previous = now;
    }
    expect(gap(shot.closeupFrom), greaterThan(150));
  });

  test('the close-up cuts in and out on its beats', () {
    expect(shot.closeupAt(shot.closeupFrom - .01), isFalse);
    expect(shot.closeupAt(shot.closeupFrom), isTrue);
    expect(shot.closeupAt(shot.closeupTo - .01), isTrue);
    expect(shot.closeupAt(shot.closeupTo), isFalse);
  });

  test('reduced motion keeps the beats, with nothing sliding', () {
    for (var beat = shot.closeupFrom; beat < shot.contactBeat; beat += .25) {
      for (final place in shot.sample(beat, reducedMotion: true)) {
        expect(place.offset, ui.Offset.zero);
      }
    }
    expect(shot.motes(shot.contactBeat, reducedMotion: true), isEmpty);
    expect(Celebration.at(1, reducedMotion: true).hop, 0);
  });

  test('the hero walks to his step and the route waits for the wide shot', () {
    expect(shot.stepAt(shot.walkFrom), 0);
    expect(shot.stepAt(shot.walkTo), 1);
    expect(shot.walkTo, lessThanOrEqualTo(shot.closeupFrom));
    expect(shot.routeAt(shot.closeupTo, 16), 0);
    expect(shot.routeAt(16, 16), 1);
  });

  test('the celebration lands: every jump starts and ends on the floor', () {
    for (final t in [.5, 1.5, 2.5, 3.0, 5.0, 6.0, 7.0]) {
      expect(Celebration.at(t, reducedMotion: false).hop, closeTo(0, 1e-9));
    }
    expect(Celebration.at(1, reducedMotion: false).hop, greaterThan(.1));
  });

  test('a cue mixes into a score in time order', () {
    final score = MusicScore(
      id: 'test',
      beatsPerBar: 4,
      bars: 2,
      phraseBars: 2,
      tempos: const [100, 100, 100, 100, 100],
      notes: const [
        ScoreNote(track: 'bass', beat: 2, pitch: 40, duration: 1, velocity: 80),
      ],
    );
    final mixed = score.withNotes(const [
      ScoreNote(track: 'pulse', beat: 0, pitch: 36, duration: .25, velocity: 127),
    ]);
    expect(mixed.notes.map((n) => n.beat), [0, 2]);
    expect(score.notes, hasLength(1));
  });
}
