import 'browser.dart';

ConsoleBrowser createPlatformBrowser() => MemoryConsoleBrowser();

/// In memory, for tests and native builds.
class MemoryConsoleBrowser implements ConsoleBrowser {
  final store = <String, String>{};
  final opened = <String>[];

  @override
  String? read(String key) => store[key];

  @override
  void write(String key, String value) => store[key] = value;

  @override
  void open(String url) => opened.add(url);

  @override
  ConsoleAudio audio() => SilentConsoleAudio();
}

class SilentConsoleAudio implements ConsoleAudio {
  String? source;
  bool _playing = false;

  @override
  void play({required String opus, required String aac}) {
    source = opus;
    _playing = true;
  }

  @override
  void pause() => _playing = false;

  @override
  void resume() => _playing = source != null;

  @override
  void seek(double seconds) {}

  @override
  bool get playing => _playing;

  @override
  double get position => 0;

  @override
  double get duration => double.nan;

  @override
  void dispose() => _playing = false;
}
