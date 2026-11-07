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

/// Offered by backends that know how late the device plays what they schedule.
abstract interface class AudioLatency {
  /// What the browser reports, in seconds, or null when it reports nothing:
  /// Web Audio's `outputLatency` and `baseLatency`, each null when missing.
  ({double? output, double? base}) get reportedLatency;

  /// How long ago a pointer event happened, from its time stamp, in seconds,
  /// or null when the stamp can't be read against this clock. On the web a
  /// pointer's stamp is the DOM event's, on the page's `performance.now()`.
  double? eventAgeSeconds(Duration timeStamp);
}

/// When a browser reports no latency at all. Phones commonly play 50 to 150 ms
/// late without Bluetooth; this is the low end, so a wrong guess costs less.
const defaultOutputLatencySeconds = .06;

/// The output latency to compensate: [override] (from `?latency=<ms>`, in
/// seconds) when given, else `outputLatency + baseLatency` when the browser
/// reports an output latency, else `baseLatency` alone (Safari reports only
/// that, and it leaves out the device), else [defaultOutputLatencySeconds].
/// A zero or negative report counts as no report: Chrome reports 0 before the
/// first sound. Never above half a second.
double chooseOutputLatency({double? output, double? base, double? override}) {
  double? valid(double? v) => v != null && v.isFinite && v > 0 ? v : null;
  final double chosen;
  if (override != null && override.isFinite && override >= 0) {
    chosen = override;
  } else if (valid(output) != null) {
    chosen = valid(output)! + (valid(base) ?? 0);
  } else if (valid(base) != null) {
    chosen = valid(base)!;
  } else {
    chosen = defaultOutputLatencySeconds;
  }
  return chosen.clamp(0.0, .5);
}

/// How long a phone's touch screen takes to hand a tap over, when nothing
/// measures it. Touch screens measure 50 to 200 ms end to end, much of it the
/// display (Deber et al., CHI 2015); this is the low part that delays the tap.
const defaultTouchLatencySeconds = .04;

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
