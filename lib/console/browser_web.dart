// Web-only adapter, imported conditionally by browser.dart.
import 'dart:async';
import 'dart:js_interop';

import 'browser.dart';

ConsoleBrowser createPlatformBrowser() => _WebConsoleBrowser();

@JS('localStorage')
external _Storage? get _storage;

extension type _Storage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
}

@JS('location')
external _Location get _location;

extension type _Location._(JSObject _) implements JSObject {
  external void assign(String url);
}

@JS('Audio')
extension type _Audio._(JSObject _) implements JSObject {
  external factory _Audio();
  external String get src;
  external set src(String value);
  external set preload(String value);
  external bool get paused;
  external double get currentTime;
  external set currentTime(double value);
  external double get duration;
  external JSPromise<JSAny?> play();
  external void pause();
  external String canPlayType(String type);
  external void removeAttribute(String name);
  external void load();
}

class _WebConsoleBrowser implements ConsoleBrowser {
  @override
  String? read(String key) {
    try {
      return _storage?.getItem(key);
    } catch (_) {
      return null;
    }
  }

  @override
  void write(String key, String value) {
    try {
      _storage?.setItem(key, value);
    } catch (_) {
      // Private windows may refuse storage; the notes still copy out.
    }
  }

  @override
  void open(String url) => _location.assign(url);

  @override
  ConsoleAudio audio() => _WebConsoleAudio();
}

class _WebConsoleAudio implements ConsoleAudio {
  final _element = _Audio()..preload = 'auto';

  @override
  void play({required String opus, required String aac}) {
    final ogg = _element.canPlayType('audio/ogg; codecs="opus"');
    final path = ogg.isEmpty ? aac : opus;
    // Flutter serves an asset `a/b` at `assets/a/b`, under the page's base.
    _element.src = 'assets/$path';
    _element.play().toDart.ignore();
  }

  @override
  void pause() => _element.pause();

  @override
  void resume() => _element.play().toDart.ignore();

  @override
  void seek(double seconds) {
    try {
      _element.currentTime = seconds;
    } catch (_) {}
  }

  @override
  bool get playing => !_element.paused;

  @override
  double get position => _element.currentTime;

  @override
  double get duration => _element.duration;

  @override
  void dispose() {
    _element.pause();
    _element.removeAttribute('src');
    _element.load();
  }
}
