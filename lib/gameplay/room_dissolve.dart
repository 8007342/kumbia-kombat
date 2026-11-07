import 'dart:ui' as ui;

/// The owner's gentle flow into the next room, in place of the hard cut: the last
/// frame of the old room stays on top of the live new one and clears away. It never
/// goes through black, and it only draws, so it can't reach the music or the score.
class RoomDissolve {
  RoomDissolve(this.image, {required this.scale});

  /// Short enough that the new room is clear before its first call: the shortest
  /// intro is four beats at the bar's base tempo, or the lawn's 1.9 s.
  static const seconds = 1.2;

  /// How far the old room grows as it clears, as if Mācron walks through it.
  static const drift = .06;

  final ui.Image image;
  final double scale;
  double elapsed = 0;

  bool get done => elapsed >= seconds;

  /// Quintic smootherstep, as every entrance here uses: no speed at either end.
  static double progress(double seconds) {
    final t = (seconds / RoomDissolve.seconds).clamp(0.0, 1.0);
    return t * t * t * (t * (t * 6 - 15) + 10);
  }

  static double opacityAt(double seconds) => 1 - progress(seconds);

  /// Reduced motion keeps the fade and drops the movement.
  static double growthAt(double seconds, {required bool reducedMotion}) =>
      reducedMotion ? 1 : 1 + drift * progress(seconds);

  void render(
    ui.Canvas canvas,
    double width,
    double height, {
    required bool reducedMotion,
  }) {
    final growth = growthAt(elapsed, reducedMotion: reducedMotion);
    canvas.save();
    canvas.translate(width / 2, height / 2);
    canvas.scale(growth / scale);
    canvas.translate(-width * scale / 2, -height * scale / 2);
    canvas.drawImage(
      image,
      ui.Offset.zero,
      ui.Paint()
        ..color = ui.Color.fromRGBO(255, 255, 255, opacityAt(elapsed))
        ..filterQuality = ui.FilterQuality.low,
    );
    canvas.restore();
  }

  void dispose() => image.dispose();
}
