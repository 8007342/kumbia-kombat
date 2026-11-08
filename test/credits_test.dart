import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/console/browser_stub.dart';
import 'package:kumbia_kombat/credits/credits_data.dart';
import 'package:kumbia_kombat/credits/credits_page.dart';

CreditsData _shipping() => CreditsData.fromJson(
  jsonDecode(File(CreditsData.asset).readAsStringSync()) as Map<String, dynamic>,
);

const _small = CreditsData(
  lead: 'Built using',
  name: 'Tillandsias.org',
  music: CreditsMusic(opus: 'assets/a.ogg', aac: 'assets/a.m4a', standIn: true),
  items: [
    CreditItem(name: 'Podman', kind: 'platform', degree: 0),
    CreditItem(name: 'Fedora Linux', version: '45', kind: 'platform', degree: 0),
    CreditItem(name: 'flame', version: '1.38.2', kind: 'dart', degree: 1),
    CreditItem(name: 'ordered_set', version: '8.0.1', kind: 'dart', degree: 2, via: 'flame'),
    CreditItem(name: 'term_glyph', version: '1.2.2', kind: 'dart', degree: 5),
  ],
);

class _OpenedBrowser extends MemoryConsoleBrowser {
  final audios = <SilentConsoleAudio>[];
  @override
  SilentConsoleAudio audio() {
    final audio = SilentConsoleAudio();
    audios.add(audio);
    return audio;
  }
}

void main() {
  group('assets/credits.json', () {
    final credits = _shipping();
    final names = {for (final i in credits.items) '${i.kind}:${i.name}'};

    test('starts with Tillandsias, Podman and Fedora 45', () {
      expect(credits.lead, 'Built using');
      expect(credits.name, 'Tillandsias.org');
      final base = credits.at(0).map((i) => i.label);
      expect(base, containsAll(['Tillandsias', 'Podman', 'Fedora Linux 45']));
      for (final tool in ['Flutter', 'Dart', 'ComfyUI', 'FFmpeg', 'Blender', 'uv', 'ollama']) {
        expect(names, contains('tool:$tool'), reason: tool);
      }
      expect(names, contains('model:Comfy-Org/ACE-Step-1.5'));
      expect(names, contains('model:Comfy-Org/Qwen-Image-Edit'));
      expect(names, contains('model:qwen2.5vl'));
    });

    test('names every package the lock files name, with a degree', () {
      // If this fails, dependencies changed: run tool/credits/build_credits.py.
      final lock = File('pubspec.lock').readAsStringSync();
      final dart = RegExp(r'^  ([a-z0-9_]+):$', multiLine: true)
          .allMatches(lock)
          .map((m) => m.group(1)!);
      for (final name in dart) {
        expect(names, contains('dart:$name'), reason: 'pubspec.lock names $name');
      }
      final cargo = File('tool/music/mixrs/Cargo.lock').readAsStringSync();
      final crates = RegExp(r'^name = "([^"]+)"$', multiLine: true)
          .allMatches(cargo)
          .map((m) => m.group(1)!)
          .where((n) => n != 'mixrs');
      for (final name in crates) {
        expect(names, contains('rust:$name'), reason: 'Cargo.lock names $name');
      }
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final direct in ['flame', 'flutter_svg', 'qr', 'cupertino_icons']) {
        expect(pubspec, contains('  $direct:'));
        expect(
          credits.items.firstWhere((i) => i.kind == 'dart' && i.name == direct).degree,
          1,
          reason: direct,
        );
      }
      expect(credits.items.every((i) => i.degree >= 0), isTrue);
      expect(credits.at(2), isNotEmpty);
      expect(credits.at(3, orDeeper: true), isNotEmpty);
      // A degree-2 credit says what brought it in.
      expect(credits.at(2).every((i) => i.via != null), isTrue);
    });

    test('plays music the game ships, and says it is a stand-in', () {
      final music = credits.music!;
      expect(File(music.opus).existsSync(), isTrue, reason: music.opus);
      expect(File(music.aac).existsSync(), isTrue, reason: music.aac);
      expect(music.standIn, isTrue, reason: 'credits music is still to be made');
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- ${CreditsData.asset}'));
      expect(pubspec, contains('- ${File(music.opus).parent.path}/'));
    });
  });

  testWidgets('the roll scrolls up, large first and smaller in more columns', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final browser = _OpenedBrowser();
    await tester.pumpWidget(
      MaterialApp(home: CreditsPage(load: () async => _small, browser: browser)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Built using'), findsOneWidget);
    expect(find.text('Tillandsias.org'), findsOneWidget);
    double size(String text) => tester.widget<Text>(find.text(text)).style!.fontSize!;
    expect(size('Tillandsias.org'), greaterThan(size('Podman')));
    expect(size('Podman'), greaterThan(size('flame 1.38.2')));
    expect(size('flame 1.38.2'), greaterThan(size('ordered_set 8.0.1')));
    expect(size('ordered_set 8.0.1'), greaterThan(size('term_glyph 1.2.2')));
    double width(String key) => tester.getSize(find.byKey(ValueKey(key))).width;
    expect(width('credit:dart:ordered_set'), greaterThan(width('credit:dart:term_glyph')));

    // The music is the stand-in, going round.
    final audio = browser.audios.single;
    expect(audio.source, 'assets/a.ogg');
    expect(audio.looping, isTrue);
    expect(find.byKey(const Key('credits-sound')), findsNothing);

    // The header starts below the screen and rises.
    final start = tester.getTopLeft(find.text('Tillandsias.org')).dy;
    expect(start, greaterThan(800));
    // Two seconds of frames; a stalled frame moves it at most a tenth of a second.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final later = tester.getTopLeft(find.text('Tillandsias.org')).dy;
    expect(start - later, inInclusiveRange(40, 140));

    await tester.tap(find.byKey(const Key('credits-close')));
    await tester.pump();
    // On its own page there's nowhere to go back to, so it goes to the game.
    expect(browser.opened, ['/']);
    expect(audio.playing, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('after the end screen, the roll goes back by itself when it ends', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CreditsPage(
                  load: () async => _small,
                  browser: _OpenedBrowser(),
                  closeWhenDone: true,
                  pixelsPerSecond: 2000,
                ),
              ),
            ),
            child: const Text('END SCREEN'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('END SCREEN'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(CreditsPage), findsOneWidget);
    for (var i = 0; i < 120 && find.byType(CreditsPage).evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(CreditsPage), findsNothing);
    expect(find.text('END SCREEN'), findsOneWidget);
  });

  testWidgets('the shipping credits lay out on a phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final credits = _shipping();
    await tester.pumpWidget(
      MaterialApp(
        home: CreditsPage(load: () async => credits, browser: _OpenedBrowser()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Podman'), findsOneWidget);
    expect(find.text(credits.at(3, orDeeper: true).last.label), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
