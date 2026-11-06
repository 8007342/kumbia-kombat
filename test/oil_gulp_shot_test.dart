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

  test('every drawing the gulp names ships, and the gulp draws on top', () {
    for (final image in shot.images) {
      expect(File('assets/art/$image').existsSync(), isTrue, reason: image);
    }
    expect(shot.actors.last.impact, 'closeups/oil-gulp-mc-gulp.png');
  });

  test('the glass changes hands on the contact beat, the bridge downbeat', () {
    final score = jsonDecode(
      File('assets/music/scores/bar_swag_success.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final length = (score['bars'] as int) * (score['beatsPerBar'] as int);
    expect(shot.contactBeat, length);
    final [offer, reach, gulp] = shot.sample(
      shot.contactBeat - .5,
      reducedMotion: false,
    );
    expect(offer.image, 'closeups/oil-gulp-bt-offer.png');
    expect(reach.image, 'closeups/oil-gulp-mc-reach.png');
    expect(gulp.offset.distance, greaterThan(1000), reason: 'still offscreen');

    final hit = shot.sample(shot.contactBeat, reducedMotion: false);
    expect(hit[0].image, 'closeups/oil-gulp-bt-empty.png');
    expect(hit[1].image, 'closeups/oil-gulp-empty.png');
    expect(hit[2].image, 'closeups/oil-gulp-mc-gulp.png');
    expect(hit[2].offset.distance, 0);
  });

  test('he drains it after a long pull, with her full glass long gone', () {
    final drained = shot.contactBeat + shot.impactBeats;
    final [offer, reach, gulp] = shot.sample(drained, reducedMotion: false);
    expect(gulp.image, 'closeups/oil-gulp-mc-low.png');
    // The drawings return to their approach here, so both must be far offscreen.
    expect(offer.offset.distance, greaterThan(300));
    expect(reach.offset.distance, greaterThan(300));
    expect(
      shot.sample(drained - .1, reducedMotion: false).last.image,
      'closeups/oil-gulp-mc-gulp.png',
    );
  });

  test('calm camera holds one still, the gulp', () {
    final places = shot.sample(shot.closeupFrom, reducedMotion: true);
    expect(places.last.image, 'closeups/oil-gulp-mc-gulp.png');
    expect(places.last.offset.distance, 0);
  });
}
