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
  final counter = shot.actors.first;
  final bartender = shot.actors[1];
  final macron = shot.actors[2];

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
    expect(before[1].image, 'closeups/oil-gulp-bt-offer.png');
    expect(before[2].image, 'closeups/oil-gulp-mc3-reach.png');
    final hit = shot.sample(shot.contactBeat, reducedMotion: false);
    expect(hit[1].image, 'closeups/oil-gulp-bt-empty.png');
    expect(hit[2].image, 'closeups/oil-gulp-mc3-gulp1.png');
    expect(hit[2].offset.distance, 0);
  });

  test('he drains it in half-beat steps, with a frame on every glug', () {
    final gulps = macron.frames
        .where((f) => f.image.split('-').last.startsWith('gulp'))
        .toList();
    expect(gulps.map((f) => f.image.split('-').last), [
      'gulp1.png',
      'gulp2.png',
      'gulp3.png',
      'gulp4.png',
      'gulp5.png',
    ]);
    expect(gulps.first.beat, shot.contactBeat);
    for (var i = 1; i < gulps.length; i++) {
      expect(gulps[i].beat - gulps[i - 1].beat, .5);
    }
    for (final cue in shot.cue.where((c) => c.track == 'glug')) {
      expect(gulps.any((f) => f.beat == cue.beat), isTrue);
    }
  });

  test('the frames run in order and he hops before the cut back', () {
    for (var i = 1; i < macron.frames.length; i++) {
      expect(macron.frames[i].beat, greaterThan(macron.frames[i - 1].beat));
    }
    expect(macron.frames.first.beat, shot.closeupFrom);
    expect(macron.frames.last.image, endsWith('-hop.png'));
    expect(macron.frames.last.beat, lessThan(shot.closeupTo));
  });

  test('frameAt holds each drawing until the next starts', () {
    expect(macron.frameAt(7.75), 'closeups/oil-gulp-mc3-reach.png');
    expect(macron.frameAt(8.25), 'closeups/oil-gulp-mc3-gulp1.png');
    expect(macron.frameAt(8.5), 'closeups/oil-gulp-mc3-gulp2.png');
    expect(macron.frameAt(10.6), 'closeups/oil-gulp-mc3-relief.png');
  });

  // The game's view on a 390x844 phone is 180 units wide and 390 tall.
  const viewWidth = 180.0, viewHeight = 390.0;
  const art = (width: 560.0, height: 520.0, floor: 506.0);

  test('Mācron fits the view, with room for his raised arms', () {
    final left = viewWidth * shot.contactPoint.dx - macron.contact.dx * macron.scale;
    expect(left, greaterThanOrEqualTo(0));
    expect(left + art.width * macron.scale, lessThanOrEqualTo(viewWidth));
  });

  test('he stands on the bar with nothing cut off, above the title', () {
    final meet = viewHeight * shot.contactPoint.dy;
    final feet = meet + (art.floor - macron.contact.dy) * macron.scale;
    final barTop = meet - counter.contact.dy * counter.scale;
    // Soles on the bar's lit top edge, 12 art px deep at this scale.
    expect(feet, greaterThanOrEqualTo(barTop));
    expect(feet, lessThanOrEqualTo(barTop + 12 * counter.scale + 2));
    // The bar is drawn first, so it can't hide his feet.
    expect(counter.approach, 'closeups/oil-gulp-counter.png');
    expect(counter.entry.distance, 0, reason: 'the counter stays put');
    expect(meet + (art.height - macron.contact.dy) * macron.scale, lessThan(viewHeight * .58));
    expect(bartender.approach, 'closeups/oil-gulp-bt-offer.png');
  });

  test('calm camera holds one still, mid-gulp', () {
    final places = shot.sample(shot.closeupFrom, reducedMotion: true);
    expect(places[2].image, 'closeups/oil-gulp-mc3-gulp3.png');
    expect(places[2].offset.distance, 0);
  });
}
