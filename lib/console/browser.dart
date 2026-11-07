import 'browser_stub.dart'
    if (dart.library.js_interop) 'browser_web.dart'
    as platform;

/// The few browser features the console needs: notes that outlive a reload,
/// leaving for the game, and an audio element with a progress bar. Off the web
/// (tests) these are kept in memory, so nothing here can fail a test.
abstract class ConsoleBrowser {
  String? read(String key);
  void write(String key, String value);

  /// Leaves the console for [url], a path on this site.
  void open(String url);

  ConsoleAudio audio();
}

/// One track at a time, from an asset path like `assets/music/...`.
abstract class ConsoleAudio {
  /// Picks Opus where the browser plays it, else AAC (Safari before 17).
  void play({required String opus, required String aac});
  void pause();
  void resume();
  void seek(double seconds);
  bool get playing;
  double get position;

  /// NaN until the browser has read the file's length.
  double get duration;
  void dispose();
}

ConsoleBrowser createConsoleBrowser() => platform.createPlatformBrowser();
