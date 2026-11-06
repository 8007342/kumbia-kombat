import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// The pause screen: the frozen game under the look of a paused videotape, with
/// a big icon on top. Drawn here, with no words and no image files. Art only: it
/// reads the audio clock and never moves the music, the notes or the score.

/// How long the picture takes to clear after a resume, at most. It always clears
/// inside the count-in, so it's gone before input opens.
const resumeFadeSeconds = 1.2;
const resumeFadeSecondsCalm = .35;

/// How long the music takes to reach full volume, from its first note after the
/// count-in. Every chart's first scored note is a whole call later than this.
const musicFadeSeconds = 1.2;
const musicFadeSecondsCalm = .4;

/// A second tap this soon after a resume is the same thumb bouncing: even on the
/// pause button, it isn't a request to pause again.
const resumeDoubleTapGuardSeconds = .35;

/// How often the noise changes. Under the three flashes a second that safety
/// guidance allows.
const vcrNoiseStepsPerSecond = 2.0;

/// The most any noise mark covers the picture, at a band's middle. Even where two
/// wide bands overlap, a streak can't make the 10% luminance swing that safety
/// guidance counts as a flash at any rate.
const vcrNoisePeakOpacity = .045;
const vcrBandFillOpacity = .03;
const vcrScanlineOpacity = .07;

/// Sideways slip of the noise, in logical pixels. None under reduced motion.
const vcrJitterPixels = 1.5;

/// How tall the moving band is, in screen heights. Its edges fade to nothing, so
/// it reads as a soft swell rolling through the picture rather than a stripe.
const vcrMovingBandHeight = .46;
const vcrSecondBandHeight = .22;

/// Screen heights a second. A slow roll, never a flicker.
const vcrBandDriftPerSecond = .012;

const _cream = Color(0xFFFFF0D1);
const _gold = Color(0xFFFFC35F);
const _ink = Color(0xFF101F29);

/// The picture's fade after a resume, on the audio clock. Being paused always
/// overrides it, so pausing mid-fade needs no cleanup: the next resume replaces it.
class ResumeFade {
  double _from = 0;
  double _until = -1;

  /// [anchor] is when the music restarts. The fade finishes by then at the latest.
  void begin({
    required double now,
    required double anchor,
    required bool reducedMotion,
  }) {
    _from = now;
    _until =
        now +
        math.min(
          math.max(0.0, anchor - now),
          reducedMotion ? resumeFadeSecondsCalm : resumeFadeSeconds,
        );
  }

  double get endsAt => _until;

  /// 1 is the whole frame, 0 is gone. Eases at both ends.
  double opacityAt(double now) {
    if (now >= _until) return 0;
    final t = ((now - _from) / (_until - _from)).clamp(0.0, 1.0);
    return 1 - t * t * (3 - 2 * t);
  }

  bool guardsPauseAt(double now) =>
      _until >= 0 && now >= _from && now < _from + resumeDoubleTapGuardSeconds;
}

/// One streak band of the noise, in shares of the screen height.
class VcrBand {
  const VcrBand(this.top, this.height);
  final double top;
  final double height;
}

/// What the noise looks like at one moment. The same time gives the same frame.
class VcrNoiseFrame {
  const VcrNoiseFrame(this.step, this.jitter, this.bands);

  /// Seeds the streaks: they only change when this does.
  final int step;
  final double jitter;
  final List<VcrBand> bands;
}

VcrNoiseFrame vcrNoiseAt(double seconds, {required bool reducedMotion}) {
  final t = reducedMotion ? 0.0 : seconds;
  final step = (t * vcrNoiseStepsPerSecond).floor();
  return VcrNoiseFrame(
    step,
    reducedMotion ? 0 : (step.isEven ? 1 : -1) * vcrJitterPixels,
    [
      VcrBand((.18 + t * vcrBandDriftPerSecond) % 1, vcrMovingBandHeight),
      VcrBand((.72 + t * vcrBandDriftPerSecond * 1.5) % 1, vcrSecondBandHeight),
      // A tape's picture always frays along the bottom edge.
      const VcrBand(.965, .035),
    ],
  );
}

class VcrPauseOverlay extends StatefulWidget {
  const VcrPauseOverlay({
    super.key,
    required this.showPlay,
    required this.opacity,
    required this.reducedMotion,
    required this.onResume,
    this.message,
  });

  /// The icon has turned to the play triangle: a resume was accepted.
  final bool showPlay;
  final double opacity;
  final bool reducedMotion;

  /// Null during the fade, when the picture lets touches through to the game.
  final VoidCallback? onResume;

  /// Errors stay as words: they say what to do next.
  final String? message;

  @override
  State<VcrPauseOverlay> createState() => _VcrPauseOverlayState();
}

class _VcrPauseOverlayState extends State<VcrPauseOverlay>
    with SingleTickerProviderStateMixin {
  // The bands roll slowly, so a few repaints a second looks continuous.
  static const _repaintEvery = Duration(milliseconds: 125);
  final _seconds = ValueNotifier<double>(0);
  late final Ticker _ticker;
  Duration _painted = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (widget.reducedMotion || elapsed - _painted < _repaintEvery) return;
      _painted = elapsed;
      _seconds.value = elapsed.inMicroseconds / 1e6;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final picture = Opacity(
      opacity: widget.opacity.clamp(0.0, 1.0),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(child: CustomPaint(painter: VcrFramePainter())),
          RepaintBoundary(
            child: CustomPaint(
              painter: VcrNoisePainter(
                _seconds,
                reducedMotion: widget.reducedMotion,
              ),
            ),
          ),
          Center(
            child: FractionallySizedBox(
              widthFactor: .46,
              child: AspectRatio(
                aspectRatio: 1,
                child: CustomPaint(
                  painter: VcrIconPainter(showPlay: widget.showPlay),
                ),
              ),
            ),
          ),
          if (widget.message != null)
            Align(
              alignment: const Alignment(0, .62),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: _ink.withValues(alpha: .82)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      widget.message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _gold, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (widget.onResume == null) {
      return IgnorePointer(child: ExcludeSemantics(child: picture));
    }
    return Semantics(
      container: true,
      button: true,
      label: widget.showPlay ? 'Resuming' : 'Paused. Tap to resume.',
      onTap: widget.onResume,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: widget.onResume,
        child: picture,
      ),
    );
  }
}

/// The parts of the frame that never move: scanlines and a soft dark edge.
class VcrFramePainter extends CustomPainter {
  const VcrFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.black.withValues(alpha: vcrScanlineOpacity);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), line);
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          radius: .9,
          colors: [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: .28),
          ],
          stops: const [.62, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(VcrFramePainter oldDelegate) => false;
}

/// Tracking noise: wide, pale bands of short streaks, faint and slow, fading out
/// toward both edges. See the safety limits at the top of this file.
class VcrNoisePainter extends CustomPainter {
  VcrNoisePainter(this.seconds, {required this.reducedMotion})
    : super(repaint: seconds);

  final ValueListenable<double> seconds;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = vcrNoiseAt(seconds.value, reducedMotion: reducedMotion);
    for (final (index, band) in frame.bands.indexed) {
      // A band that rolls off the bottom comes back in at the top, unbroken.
      for (final top in [band.top, band.top - 1]) {
        if (top + band.height <= 0 || top >= 1) continue;
        _band(canvas, size, frame, band, top, index);
      }
    }
  }

  void _band(
    Canvas canvas,
    Size size,
    VcrNoiseFrame frame,
    VcrBand band,
    double topShare,
    int index,
  ) {
    final top = topShare * size.height;
    final height = band.height * size.height;
    final box = Rect.fromLTWH(0, top, size.width, height);
    canvas.drawRect(
      box,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _cream.withValues(alpha: 0),
            _cream.withValues(alpha: vcrBandFillOpacity),
            _cream.withValues(alpha: 0),
          ],
        ).createShader(box),
    );
    final draw = math.Random(frame.step * 7 + index);
    // The same density of streaks as ever, over a much wider band.
    final streaks = (size.width * band.height / 1.4).ceil();
    final streak = Paint();
    for (var i = 0; i < streaks; i++) {
      final along = draw.nextDouble();
      final x = draw.nextDouble() * size.width + frame.jitter;
      final length = 8 + draw.nextDouble() * 46;
      // Faint at the edges, strongest in the middle, and never above the peak.
      final soft = math.sin(math.pi * along);
      streak.color = _cream.withValues(alpha: vcrNoisePeakOpacity * soft * soft);
      canvas.drawRect(Rect.fromLTWH(x, top + along * height, length, 1.5), streak);
    }
  }

  @override
  bool shouldRepaint(VcrNoisePainter oldDelegate) =>
      oldDelegate.reducedMotion != reducedMotion;
}

/// Two bars, or a triangle. Translucent, so the game still shows through it.
class VcrIconPainter extends CustomPainter {
  const VcrIconPainter({required this.showPlay});

  final bool showPlay;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shape = showPlay
        ? (Path()
            ..moveTo(w * .22, h * .12)
            ..lineTo(w * .9, h * .5)
            ..lineTo(w * .22, h * .88)
            ..close())
        : (Path()
            ..addRect(Rect.fromLTRB(w * .16, h * .12, w * .4, h * .88))
            ..addRect(Rect.fromLTRB(w * .6, h * .12, w * .84, h * .88)));
    canvas.drawPath(
      shape.shift(const Offset(3, 4)),
      Paint()..color = _ink.withValues(alpha: .28),
    );
    canvas.drawPath(shape, Paint()..color = _cream.withValues(alpha: .52));
  }

  @override
  bool shouldRepaint(VcrIconPainter oldDelegate) =>
      oldDelegate.showPlay != showPlay;
}
