import 'transport.dart';

/// Device lifecycle needed by gameplay, separate from the scheduling contract.
abstract interface class GameAudio implements MusicAudioBackend {
  /// Must be initiated from a player gesture on the web. Unsupported platforms
  /// throw instead of starting a silent scored run.
  Future<void> activate();
  Future<void> dispose();
  String get leadShape;
  set leadShape(String value);
}
