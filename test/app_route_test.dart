import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/review_links.dart';

void main() {
  test('/console and /qr open their pages, by path, query or hash', () {
    AppRoute at(String url) => routeFor(Uri.parse(url));
    expect(at('https://kumbias.tlatoani.net/'), AppRoute.game);
    expect(at('https://kumbias.tlatoani.net/?level=bar'), AppRoute.game);
    expect(at('https://kumbias.tlatoani.net/console'), AppRoute.console);
    expect(at('https://kumbias.tlatoani.net/console/'), AppRoute.console);
    expect(at('https://kumbias.tlatoani.net/CONSOLE/'), AppRoute.console);
    expect(at('https://kumbias.tlatoani.net/qr'), AppRoute.qr);
    expect(at('https://kumbias.tlatoani.net/qr/'), AppRoute.qr);
    expect(at('http://www.kumbia-kombat.localhost/?page=console'), AppRoute.console);
    expect(at('http://www.kumbia-kombat.localhost/#/qr'), AppRoute.qr);
    expect(at('https://kumbias.tlatoani.net/?capture=gestures'), AppRoute.gestures);
    // Only the first segment names a page: a deeper path is not the console.
    expect(at('https://kumbias.tlatoani.net/listen/console'), AppRoute.game);
  });

  test('off the web the working directory never picks a page', () {
    final uri = Uri.parse('file:///home/forge/src/console/');
    expect(routeFor(uri, readPath: false), AppRoute.game);
    expect(routeFor(uri), AppRoute.game);
    expect(routeFor(Uri.parse('file:///console/'), readPath: false), AppRoute.game);
  });

  test('review links say what the game reads', () {
    expect(ReviewLinks.play(), '/');
    expect(ReviewLinks.play(level: 'bar'), '/?level=bar');
    expect(
      ReviewLinks.play(level: 'salon', flawless: true, tier: 4),
      '/?level=salon&autoplay=flawless&tier=4',
    );
    expect(ReviewLinks.play(mixer: true), '/?mixer=1');
    expect(ReviewLinks.tierFrom({'tier': '3'}), 3);
    expect(ReviewLinks.tierFrom({'tier': '0'}), 0);
    expect(ReviewLinks.tierFrom({'tier': '5'}), isNull);
    expect(ReviewLinks.tierFrom({'tier': 'high'}), isNull);
    expect(ReviewLinks.tierFrom({}), isNull);
  });

  test('the /console/ and /qr/ entry pages are the app page with a fixed base', () {
    final app = File('web/index.html').readAsStringSync();
    for (final page in ['console', 'qr']) {
      final entry = File('web/$page/index.html').readAsStringSync();
      expect(entry, contains('<base href="/">'), reason: page);
      expect(entry, contains('<script src="flutter_bootstrap.js" async></script>'));
      String body(String html) => html
          .replaceAll(RegExp(r'<!-- /\w+/ for any static server[\s\S]*?-->\n'), '')
          .replaceAll(RegExp(r'<base href="[^"]*">'), '<base>')
          .replaceAll(RegExp(r'<title>[^<]*</title>'), '<title>');
      expect(body(entry), body(app), reason: '$page drifted from web/index.html');
    }
  });
}
