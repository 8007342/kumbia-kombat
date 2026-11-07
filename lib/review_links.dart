/// Which page a URL opens, and the review links that start the game somewhere
/// other than the beginning. One place for every query name, so the console's
/// buttons and the game read the same words.
///
/// `/console` and `/qr` are real paths. The deploy serves them three ways, and
/// the app reads all three, so none depends on the others:
/// - `web/console/index.html` and `web/qr/index.html` are copied into the build,
///   so any static server answers `/console/` with a page that boots the app;
/// - Cloudflare's `not_found_handling = "single-page-application"` answers any
///   other path with `index.html`, URL untouched;
/// - `?page=console` works on the root page of any server at all.
library;

enum AppRoute { game, console, qr, gestures }

/// [readPath] is false off the web, where `Uri.base` is the working directory
/// and a folder that happens to be called `console` must not open the console.
AppRoute routeFor(Uri uri, {bool readPath = true}) {
  if (uri.queryParameters['capture'] == 'gestures') return AppRoute.gestures;
  final named = <String>[
    if (readPath) ...uri.pathSegments.where((s) => s.isNotEmpty).take(1),
    ?uri.queryParameters['page'],
    // A hash route, for a server that rewrites nothing and a link typed by hand.
    ...uri.fragment.split('/').where((s) => s.isNotEmpty),
  ].map((s) => s.toLowerCase());
  for (final name in named) {
    if (name == 'console') return AppRoute.console;
    if (name == 'qr') return AppRoute.qr;
  }
  return AppRoute.game;
}

class ReviewLinks {
  /// The tier the first phrase starts at, from `?tier=0..4`; null for none or a
  /// number out of range, which plays as an ordinary start.
  static int? tierFrom(Map<String, String> query) {
    final tier = int.tryParse(query['tier'] ?? '');
    return tier != null && tier >= 0 && tier <= 4 ? tier : null;
  }

  /// `?sync=1` opens the SYNC tap-along calibration as the page loads.
  static bool syncFrom(Map<String, String> query) => query['sync'] == '1';

  /// Latencies the console offers for `?latency=<ms>`; 0 turns it off.
  static const latencyTrials = [0, 40, 80, 120, 160, 200];

  /// A link to the game from the site root. [level] plays one level alone and
  /// ends on its end screen; null plays the campaign.
  static String play({
    String? level,
    bool flawless = false,
    int? tier,
    bool mixer = false,
    bool sync = false,
    int? latencyMs,
  }) {
    final query = <String, String>{
      'level': ?level,
      if (flawless) 'autoplay': 'flawless',
      if (tier != null) 'tier': '$tier',
      if (mixer) 'mixer': '1',
      if (sync) 'sync': '1',
      if (latencyMs != null) 'latency': '$latencyMs',
    };
    return Uri(path: '/', queryParameters: query.isEmpty ? null : query)
        .toString();
  }

  static const shareUrl = 'https://kumbias.tlatoani.net';
}
