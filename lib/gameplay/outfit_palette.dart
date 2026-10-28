import 'dart:ui' as ui;

enum OutfitColor { teal, blue, coral, gold }

/// GPU-only clothing recolor. Reserved cool purple, saturated plum and bright
/// pink gates are reviewed against the ensemble v2 clothing/skin/hair pixels.
/// Arbitrary art must not opt in without a new mask/palette review.
class OutfitPalette {
  OutfitPalette._(this._shader);
  final ui.FragmentShader _shader;
  final ui.Paint _paint = ui.Paint()..filterQuality = ui.FilterQuality.none;
  static Future<ui.FragmentProgram>? _program;
  bool _disposed = false;

  /// Cache the compiled program, but own/dispose each renderer's shader instance.
  /// Failure is explicit: the caller may show source plum without claiming a
  /// recolored variant. Do not silently run a global ColorFilter fallback.
  static Future<OutfitPalette> load() async {
    final program = await (_program ??= ui.FragmentProgram.fromAsset(
      'shaders/party_palette.frag',
    ));
    return OutfitPalette._(program.fragmentShader());
  }

  ui.Paint paint({
    required ui.Image image,
    required ui.Rect source,
    required ui.Rect destination,
    required OutfitColor palette,
  }) {
    if (_disposed) throw StateError('Outfit palette is disposed');
    for (final rect in [source, destination]) {
      if (!rect.isFinite || rect.width <= 0 || rect.height <= 0) {
        throw ArgumentError.value(rect, 'rect');
      }
    }
    if (source.left < 0 ||
        source.top < 0 ||
        source.right > image.width ||
        source.bottom > image.height) {
      throw ArgumentError.value(source, 'source', 'Outside atlas');
    }
    final hue = switch (palette) {
      OutfitColor.teal => (0.18, 0.72, 0.60),
      OutfitColor.blue => (0.23, 0.47, 0.92),
      OutfitColor.coral => (0.94, 0.34, 0.25),
      OutfitColor.gold => (0.95, 0.69, 0.19),
    };
    final uniforms = [
      destination.left,
      destination.top,
      destination.width,
      destination.height,
      source.left,
      source.top,
      source.width,
      source.height,
      image.width.toDouble(),
      image.height.toDouble(),
      hue.$1,
      hue.$2,
      hue.$3,
    ];
    for (var i = 0; i < uniforms.length; i++) {
      _shader.setFloat(i, uniforms[i]);
    }
    _shader.setImageSampler(0, image);
    return _paint..shader = _shader;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _paint.shader = null;
    _shader.dispose();
  }
}
