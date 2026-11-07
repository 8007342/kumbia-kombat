import 'rendered_music.dart';
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

/// A rendered clip that is sounding or queued. Stopping only ever shapes gain
/// and ends the buffer: it can't reach the beat clock.
abstract interface class ClipVoice {
  /// Fades out over [fadeSeconds] from [atSeconds]. A later call replaces it.
  void stopAt(double atSeconds, {double fadeSeconds});
}

/// Plays decoded buffers on the same device clock the transport reads.
abstract interface class ClipDeck {
  /// Decoded and playable right now, without waiting.
  bool clipReady(RenderedClip clip);

  /// Starts at [atSeconds], [offsetSeconds] into the file. A looping clip keeps
  /// looping by its own points until stopped; others play to the file's end.
  ClipVoice playClip(
    RenderedClip clip, {
    required double atSeconds,
    required double offsetSeconds,
    double fadeInSeconds,
  });
}

/// Loading and live levels, for a backend that can play rendered music.
abstract interface class RenderedAudio implements ClipDeck {
  /// Fetches the compressed file, so a later [decodeClip] needs no network.
  Future<void> fetchClip(RenderedClip clip);

  /// Needs an activated backend. Throws if the file can't be fetched or decoded.
  Future<void> decodeClip(RenderedClip clip);

  /// Drops the decoded audio, keeping the compressed file. Sounding voices run
  /// on: Web Audio keeps a buffer alive for as long as a source plays it.
  void releaseClip(RenderedClip clip);

  void setMix(RenderedMix mix);

  /// Applies a changed [RenderedClip.gainDb] to anything playing it.
  void clipGainChanged(RenderedClip clip);

  /// Decoded audio held right now, for the owner's readout.
  int get decodedBytes;

  /// Compressed audio held right now.
  int get compressedBytes;
}
