import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';

void main() {
  final level = LevelDefinition.fromJson(
    jsonDecode(File('levels/bar.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final shot = level.exitShot!;
  final macron = shot.actors[1];

  test('every drawing the gulp names ships', () {
    for (final image in shot.images) {
      expect(File('assets/art/$image').existsSync(), isTrue, reason: image);
    }
  });

  test('the glass changes hands on the contact beat, the bridge downbeat', () {
    final score = jsonDecode(
      File('assets/music/scores/bar_swag_success.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final length = (score['bars'] as int) * (score['beatsPerBar'] as int);
    expect(shot.contactBeat, length);
    final before = shot.sample(shot.contactBeat - .5, reducedMotion: false);
    expect(before[0].image, 'closeups/oil-gulp-bt-offer.png');
    expect(before[1].image, 'closeups/oil-gulp-mc2-reach.png');
    final hit = shot.sample(shot.contactBeat, reducedMotion: false);
    expect(hit[0].image, 'closeups/oil-gulp-bt-empty.png');
    expect(hit[1].image, 'closeups/oil-gulp-mc2-gulp1.png');
    expect(hit[1].offset.distance, 0);
  });

  test('he drains it in sub-second steps, each on an accent or between them', () {
    expect(macron.frames.map((f) => f.image.split('-').last), [
      'gulp1.png',
      'gulp2.png',
      'gulp3.png',
      'gulp4.png',
      'gulp5.png',
      'relief.png',
    ]);
    for (var i = 1; i < macron.frames.length; i++) {
      expect(macron.frames[i].beat - macron.frames[i - 1].beat, .5);
    }
    for (final cue in shot.cue.where((c) => c.track == 'glug')) {
      expect(macron.frames.any((f) => f.beat == cue.beat), isTrue);
    }
    expect(macron.frames.last.beat, lessThan(shot.closeupTo));
  });

  test('frameAt holds each drawing until the next starts', () {
    expect(macron.frameAt(shot.closeupFrom), macron.approach);
    expect(macron.frameAt(8.25), 'closeups/oil-gulp-mc2-gulp1.png');
    expect(macron.frameAt(8.5), 'closeups/oil-gulp-mc2-gulp2.png');
    expect(macron.frameAt(11), 'closeups/oil-gulp-mc2-relief.png');
  });

  test('Mācron fits the game\'s 180-unit-wide view', () {
    expect(416 * macron.scale, lessThan(180));
    final left = 180 * shot.contactPoint.dx - macron.contact.dx * macron.scale;
    expect(left, greaterThanOrEqualTo(0));
    expect(left + 416 * macron.scale, lessThanOrEqualTo(180));
  });

  test('the counter hides the bottom edge of his torso', () {
    final counter = shot.actors.last;
    final torsoBottom = (416 - macron.contact.dy) * macron.scale;
    final counterTop = -counter.contact.dy * counter.scale;
    expect(counterTop, lessThanOrEqualTo(torsoBottom));
    expect(counter.entry.distance, 0, reason: 'the counter stays put');
  });

  test('calm camera holds one still, mid-gulp', () {
    final places = shot.sample(shot.closeupFrom, reducedMotion: true);
    expect(places[1].image, 'closeups/oil-gulp-mc2-gulp3.png');
    expect(places[1].offset.distance, 0);
  });
}
