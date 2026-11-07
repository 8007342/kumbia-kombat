import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/exit_shot.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/music/accent_voice.dart';
import 'package:kumbia_kombat/music/rendered_music.dart';

/// The indoor party's win: BlinBlin's approving nod and Mācron's answer, on the
/// real level file and the real rendered manifest.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final level = LevelRegistry.parse(
    File('levels/index.json').readAsStringSync(),
    (id) => File('levels/$id.json').readAsStringSync(),
  ).byId('cool-crowd');
  final ExitShot shot = level.exitShot!;
  final music = RenderedManifest.fromJson(
    jsonDecode(File('assets/music/rendered/manifest.json').readAsStringSync()),
  ).levels['cool-crowd']!;

  test('every drawing it names ships', () {
    for (final image in shot.images) {
      expect(File('assets/art/$image').existsSync(), isTrue, reason: image);
    }
  });

  test('the whole close-up fits the success tag, whichever score plays', () {
    final synth = jsonDecode(
      File('assets/music/scores/${level.music.successScore}.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final rendered = music.success!;
    for (final beats in [
      (synth['bars'] as int) * (synth['beatsPerBar'] as int),
      rendered.bars * rendered.beatsPerBar,
    ]) {
      expect(shot.closeupTo, lessThanOrEqualTo(beats));
    }
  });

  test('each nods on their own accent: BlinBlin first, Mācron on the title', () {
    final [bb, mc] = shot.actors;
    final nods = shot.cue.where((c) => c.track == 'nod').toList();
    expect(bb.frameAt(nods.first.beat), endsWith('nod-bb-down.png'));
    expect(bb.frameAt(nods.last.beat), isNot(endsWith('-down.png')));
    expect(mc.frameAt(nods.last.beat), endsWith('nod-mc-down.png'));
    expect(mc.frameAt(nods.first.beat), endsWith('nod-mc-rest.png'));
  });

  test('two nods, each on a whole beat, the second on the title', () {
    final nods = shot.cue.where((c) => c.track == 'nod').toList();
    expect(nods.length, 2);
    expect(nods.last.beat, shot.contactBeat);
    expect(nods.first.beat, lessThan(nods.last.beat));
    expect(nods.first.velocity, lessThan(nods.last.velocity));
    expect(accentPeak('nod', 127), lessThan(accentPeak('bump', 127)));
    expect(shot.titleAt(shot.contactBeat, reducedMotion: false), isNotNull);
    expect(shot.titleAt(shot.contactBeat - .1, reducedMotion: false), isNull);
  });

  test('BlinBlin is left of the picture and Mācron right, neither crossing', () {
    final [bb, mc] = shot.actors;
    expect(bb.contact.dx, greaterThan(300));
    expect(mc.contact.dx, lessThan(100));
    expect(shot.contactPoint.dy, 1, reason: 'canvas bottoms sit on the screen edge');
  });

  test('reduced motion holds each on one drawing, with no drift', () {
    for (final beat in [3.6, 4.5, 5.5, 7.0]) {
      for (final place in shot.sample(beat, reducedMotion: true)) {
        expect(place.image, place.actor.impact);
        expect(place.offset.distance, 0);
      }
    }
  });
}
