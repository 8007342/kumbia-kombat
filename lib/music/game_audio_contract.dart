import 'transport.dart';

/// Offered by backends with a volume control. Only gain changes: nothing here
/// can move an attack, a note's length, or the audio clock.
abstract interface class MusicFader {
  /// Keeps today's volume until [atSeconds], so a count-in sounds as it always
  /// has, then drops and swells back to full over [seconds]. It always ends at
  /// full, even if the music pauses again while it runs.
  void fadeMusicIn({required double atSeconds, required double seconds});
}

/// Device lifecycle needed by gameplay, separate from the scheduling contract.
abstract interface class GameAudio implements MusicAudioBackend {
  /// Must be initiated from a player gesture on the web. Unsupported platforms
  /// throw instead of starting a silent scored run.
  Future<void> activate();
  Future<void> dispose();
  String get leadShape;
  set leadShape(String value);
}
