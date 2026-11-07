import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/console/browser_stub.dart';
import 'package:kumbia_kombat/console/console_catalog.dart';
import 'package:kumbia_kombat/console/console_notes.dart';
import 'package:kumbia_kombat/console/console_page.dart';

String _text(String path) => File(path).readAsStringSync();
Map<String, dynamic> _json(String path) =>
    jsonDecode(_text(path)) as Map<String, dynamic>;

/// The catalog as the console builds it, from the files in this checkout.
ConsoleCatalog _shipping({Map<String, String> extraLevels = const {}}) {
  final levelTexts = {
    for (final f in Directory('levels').listSync().whereType<File>())
      if (f.path.endsWith('.json') && !f.path.endsWith('index.json'))
        f.uri.pathSegments.last.replaceAll('.json', ''): f.readAsStringSync(),
    ...extraLevels,
  };
  final assets = [
    for (final f in Directory('assets/art/closeups').listSync().whereType<File>())
      'assets/art/closeups/${f.uri.pathSegments.last}',
  ];
  return ConsoleCatalog.build(
    indexText: _text('levels/index.json'),
    levelTexts: levelTexts,
    ensembleText: _text(ConsoleCatalog.ensembleManifest),
    partyText: _text(ConsoleCatalog.partyManifest),
    choreographyText: _text(ConsoleCatalog.choreography),
    musicText: _text(ConsoleCatalog.musicManifest),
    closeupTexts: {
      for (final a in assets)
        if (a.endsWith('.json')) a: _text(a),
    },
    assetPaths: assets,
  );
}

/// Every run of drawings any level file names, as the data has it.
List<(String level, String path, List<String> frames)> _levelClips() {
  final found = <(String, String, List<String>)>[];
  void walk(String level, Object? node, String path) {
    if (node is Map) {
      final frames = node['frames'];
      if (frames is List && frames.isNotEmpty && frames.every((f) => f is String)) {
        found.add((level, path, frames.cast<String>()));
        return;
      }
      for (final e in node.entries) {
        walk(level, e.value, path.isEmpty ? '${e.key}' : '$path.${e.key}');
      }
    } else if (node is List) {
      for (final (i, item) in node.indexed) {
        walk(level, item, '$path[$i]');
      }
    }
  }

  for (final f in Directory('levels').listSync().whereType<File>()) {
    if (!f.path.endsWith('.json') || f.path.endsWith('index.json')) continue;
    final id = f.uri.pathSegments.last.replaceAll('.json', '');
    walk(id, jsonDecode(f.readAsStringSync()), '');
  }
  return found;
}

void main() {
  group('console catalog from the shipping data', () {
    final catalog = _shipping();

    test('reads everything without a problem', () {
      expect(catalog.problems, isEmpty);
    });

    test('lists every level, campaign order first, with its references', () {
      final index = _json('levels/index.json');
      final campaign = [
        for (final e in index['campaign'] as List) (e as Map)['level'] as String,
      ];
      final files = [
        for (final f in Directory('levels').listSync().whereType<File>())
          if (!f.path.endsWith('index.json') && f.path.endsWith('.json'))
            f.uri.pathSegments.last.replaceAll('.json', ''),
      ];
      expect(catalog.levels.take(campaign.length).map((l) => l.id), campaign);
      expect(catalog.levels.map((l) => l.id).toSet(), files.toSet());
      for (final level in catalog.levels) {
        expect(level.ref, 'level / ${level.id}');
        expect(level.file, 'levels/${level.id}.json');
        expect(File(level.backgroundAsset).existsSync(), isTrue, reason: level.ref);
        expect(level.playLink, '/?level=${level.id}');
        final data = _json(level.file);
        expect(level.title, data['title']);
        final number = campaign.indexOf(level.id);
        expect(level.number, number < 0 ? null : number + 1);
      }
    });

    test('lists every rendered take with name, tempo, length and a real file', () {
      final manifest = _json(ConsoleCatalog.musicManifest)['levels'] as Map;
      for (final entry in manifest.entries) {
        final level = entry.key as String;
        final music = entry.value as Map;
        final expected = <String>[
          for (final take in (music['takes'] as Map).keys) 'takes.$take',
          for (final key in music.keys)
            if (music[key] is Map && (music[key] as Map)['files'] is Map) '$key',
        ];
        final listed = catalog.tracksFor(level).map((t) => t.key).toSet();
        expect(listed, containsAll(expected), reason: level);
        for (final track in catalog.tracksFor(level)) {
          expect(track.ref, startsWith('music / $level / '));
          expect(track.source, contains('levels.$level.${track.key}'));
          expect(track.bpm, isNotNull, reason: track.ref);
          expect(track.seconds, greaterThan(0), reason: track.ref);
          for (final file in track.files.values) {
            expect(File(file).existsSync(), isTrue, reason: '${track.ref} $file');
          }
        }
      }
      expect(catalog.tempos, isNotEmpty);
    });

    test('lists every atlas with its picture, and every clip draws real frames', () {
      final ensemble = (_json(ConsoleCatalog.ensembleManifest)['atlases'] as Map).keys;
      final party = (_json(ConsoleCatalog.partyManifest)['atlases'] as Map).keys;
      expect(
        catalog.atlases.map((a) => a.id).toSet(),
        {...ensemble.cast<String>(), ...party.cast<String>()},
      );
      for (final atlas in catalog.atlases) {
        expect(File(atlas.image).existsSync(), isTrue, reason: atlas.ref);
        expect(atlas.ref, 'atlas / ${atlas.id}');
        expect(atlas.clips.map((c) => c.name), contains('all_frames'));
        for (final clip in atlas.clips) {
          expect(clip.frames, isNotEmpty);
          expect(clip.beats.length, clip.frames.length);
          for (final frame in clip.frames) {
            expect(atlas.frames, contains(frame), reason: clip.ref);
          }
          expect(clip.ref, endsWith('${atlas.id} / ${clip.name}'));
        }
      }
    });

    test('every dancer has the choreography clips the game dances', () {
      final choreo = _json(ConsoleCatalog.choreography);
      final shared = (choreo['clips'] as Map).keys.cast<String>();
      for (final entry in (choreo['dancers'] as Map).entries) {
        final atlas = catalog.atlas(entry.key as String)!;
        final own = ((entry.value as Map)['clips'] as Map? ?? {}).keys.cast<String>();
        expect(
          atlas.clips.where((c) => c.level == null).map((c) => c.name),
          containsAll({...shared, ...own}),
          reason: atlas.id,
        );
      }
    });

    test('every run of drawings a level names is playable on some atlas', () {
      final clips = catalog.clips.toList();
      for (final (level, path, frames) in _levelClips()) {
        final playable = clips.where(
          (c) =>
              c.level == level &&
              c.source == 'levels/$level.json › $path' &&
              c.ref.startsWith('$level / '),
        );
        expect(playable, isNotEmpty, reason: '$level $path $frames');
      }
    });

    test('Mācron and the shared guests have their code-timed clips', () {
      final hero = catalog.atlas('hero')!;
      expect(hero.role, 'Mācron');
      final groove = hero.clips.firstWhere((c) => c.name == 'groove');
      expect(groove.frames, ['front_idle', 'groove_left', 'anticipate', 'groove_right']);
      expect(groove.beats, [.25, .25, .25, .25]);
      final guest = catalog.atlas('guest0')!;
      expect(guest.clips.map((c) => c.name), contains('crowd.stepTouch'));
    });

    test('lists every room layer and close-up drawing with references', () {
      for (final level in catalog.levels) {
        final data = _json(level.file);
        final props = ((data['layers'] as Map?)?['props'] as List?) ?? const [];
        expect(level.layers.length, props.length, reason: level.id);
        for (final layer in level.layers) {
          expect(layer.ref, '${level.id} / layer / ${layer.id}');
          expect(File(layer.atlasAsset).existsSync(), isTrue, reason: layer.ref);
          expect(layer.frameAt(0), inInclusiveRange(0, layer.frames - 1));
        }
        expect(level.hasExitShot, data.containsKey('exitShot'));
      }
      final pngs = Directory('assets/art/closeups')
          .listSync()
          .where((f) => f.path.endsWith('.png'))
          .length;
      expect(catalog.closeupArt.length, pngs);
      final nod = catalog.closeupArt.firstWhere((i) => i.asset.endsWith('nod-bb-rest.png'));
      expect(nod.ref, 'closeup / nod-bb-rest');
      expect(nod.usedBy, isNotEmpty);
    });
  });

  test('a new level file shows up with its clips and layers, no code change', () {
    final level = jsonEncode({
      'id': 'probe',
      'title': 'THE PROBE ROOM',
      'background': 'garden/garden-mansion-clean.png',
      'music': {'score': 'probe', 'successScore': 'probe_success'},
      'stage': {
        'challengers': [
          {
            'id': 'velvet',
            'atlas': 'gatekeeper',
            'mark': [0.5, 0.5],
            'bow': {
              'frames': ['approval_load', 'approval_nod', 'approval_release'],
              'beats': [0.5, 1, 0.5],
            },
          },
        ],
      },
      'layers': {
        'plateWidth': 1024,
        'plateHeight': 1536,
        'props': [
          {
            'id': 'chandelier',
            'atlas': 'garden/garden-layers.png',
            'atlasY': 0,
            'left': 10,
            'top': 0,
            'width': 50,
            'height': 50,
            'frames': 7,
            'motion': 'sway',
            'periodBeats': 4,
          },
        ],
      },
    });
    final catalog = _shipping(extraLevels: {'probe': level});
    final probe = catalog.level('probe')!;
    expect(probe.number, isNull);
    expect(probe.opponents.single, (id: 'velvet', atlas: 'gatekeeper'));
    expect(probe.layers.single.ref, 'probe / layer / chandelier');
    final bow = catalog.atlas('gatekeeper')!.clips.firstWhere(
      (c) => c.level == 'probe',
    );
    expect(bow.ref, 'probe / gatekeeper / challengers[0].bow');
    expect(bow.source, 'levels/probe.json › stage.challengers[0].bow');
    expect(bow.lengthBeats, 2);
    expect([for (final b in [0.0, 0.6, 1.4, 1.7, 2.1]) bow.indexAt(b)], [0, 1, 1, 2, 0]);
  });

  test('a broken file is reported, and the rest still lists', () {
    final catalog = ConsoleCatalog.build(
      indexText: _text('levels/index.json'),
      levelTexts: {'garden': _text('levels/garden.json'), 'oops': '{not json'},
      musicText: _text(ConsoleCatalog.musicManifest),
    );
    expect(catalog.problems.single, startsWith('levels/oops.json'));
    expect(catalog.level('garden'), isNotNull);
    expect(catalog.tracks, isNotEmpty);
  });

  test('notes keep their references, survive a reload and copy out as text', () {
    final browser = MemoryConsoleBrowser();
    ConsoleNotes(browser)
      ..set('salon / terciopelo / bow', 'frame 3 looks off', source: 'levels/salon.json › x')
      ..set('music / garden / low', 'too quiet', source: 'manifest');
    final again = ConsoleNotes(browser);
    expect(again.noteFor('salon / terciopelo / bow'), 'frame 3 looks off');
    final text = again.asText();
    expect(text, contains('## music / garden / low\n(manifest)\ntoo quiet'));
    expect(text, contains('## salon / terciopelo / bow'));
    again.set('music / garden / low', '  ', source: 'manifest');
    expect(ConsoleNotes(browser).count, 1);
  });

  testWidgets('the console loads the shipping bundle and lists it with references', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final catalog = (await tester.runAsync(() => ConsoleCatalog.load(rootBundle)))!;
    expect(catalog.problems, isEmpty);
    final files = _shipping();
    expect(catalog.levels.map((l) => l.id), files.levels.map((l) => l.id));
    expect(catalog.tracks.map((t) => t.ref), files.tracks.map((t) => t.ref));
    expect(catalog.atlases.map((a) => a.id), files.atlases.map((a) => a.id));
    expect(catalog.closeupArt.map((i) => i.asset), files.closeupArt.map((i) => i.asset));

    final browser = MemoryConsoleBrowser();
    await tester.pumpWidget(
      MaterialApp(
        home: ConsolePage(
          catalog: () async => catalog,
          browser: browser,
          registry: () async => throw StateError('not needed'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final first = catalog.levels.first;
    expect(find.text(first.ref), findsWidgets);
    await tester.tap(find.byKey(Key('link:${first.playLink}:PLAY')));
    expect(browser.opened.last, '/?level=${first.id}');
    await tester.tap(find.byKey(const Key('link:/?autoplay=flawless:AUTOPLAY FLAWLESS')));
    expect(browser.opened.last, '/?autoplay=flawless');

    await tester.tap(find.byKey(Key('add-note:${first.ref}')));
    await tester.pump();
    await tester.enterText(find.byKey(Key('note:${first.ref}')), 'the lamps flicker');
    await tester.pump();
    expect(ConsoleNotes(browser).noteFor(first.ref), 'the lamps flicker');
    expect(find.text('COPY NOTES (1)'), findsOneWidget);

    await tester.tap(find.text('MUSIC'));
    await tester.pumpAndSettle();
    final take = catalog.tracks.first;
    expect(find.text(take.ref), findsOneWidget);
    expect(find.text(take.source), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
