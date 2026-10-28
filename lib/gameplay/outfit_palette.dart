import 'dart:ui' as ui;

enum OutfitColor { teal, blue, coral, gold }

/// GPU-only clothing recolor. Reserved cool purple, saturated plum and bright
/// pink gates are reviewed against the ensemble v2 clothing/skin/hair pixels.
/// Arbitrary art must not opt in without a new mask/palette review.
class OutfitPalette {
  OutfitPalette._(this._compiledProgram);
  final ui.FragmentProgram _compiledProgram;
  final Map<(ui.Image, OutfitColor, Object?), _OutfitVariant> _variants = {};
  static Future<ui.FragmentProgram>? _program;
  bool _disposed = false;

  int get cachedVariantCount => _variants.length;

  /// Cache the compiled program, but own/dispose each renderer's shader pool.
  /// Failure is explicit: the caller may show source plum without claiming a
  /// recolored variant. Do not silently run a global ColorFilter fallback.
  static Future<OutfitPalette> load() async {
    final program = await (_program ??= ui.FragmentProgram.fromAsset(
      'shaders/party_palette.frag',
    ));
    return OutfitPalette._(program);
  }

  ui.Paint paint({
    required ui.Image image,
    required ui.Rect source,
    required ui.Rect destination,
    required OutfitColor palette,
    // Distinguish multiple actors sharing the same atlas and palette. The
    // current 3 archetypes × 4 palettes already have unique (image, palette).
    Object? instanceKey,
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
    final variant = _variants.putIfAbsent((
      image,
      palette,
      instanceKey,
    ), () => _OutfitVariant(_compiledProgram.fragmentShader(), image, palette));
    final uniforms = [
      destination.left,
      destination.top,
      destination.width,
      destination.height,
      source.left,
      source.top,
      source.width,
      source.height,
    ];
    for (var i = 0; i < uniforms.length; i++) {
      variant.shader.setFloat(i, uniforms[i]);
    }
    return variant.paint;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final variant in _variants.values) {
      variant.paint.shader = null;
      variant.shader.dispose();
    }
    _variants.clear();
  }
}

/// Texture and hue remain fixed for this avatar. CanvasKit may retain uniform
/// state when recording draws, so distinct guests must not share one mutable
/// shader even when a native raster test appears to snapshot its uniforms.
class _OutfitVariant {
  _OutfitVariant(this.shader, ui.Image image, OutfitColor palette)
    : paint = ui.Paint()..filterQuality = ui.FilterQuality.none {
    final hue = switch (palette) {
      OutfitColor.teal => (0.18, 0.72, 0.60),
      OutfitColor.blue => (0.23, 0.47, 0.92),
      OutfitColor.coral => (0.94, 0.34, 0.25),
      OutfitColor.gold => (0.95, 0.69, 0.19),
    };
    shader.setFloat(8, image.width.toDouble());
    shader.setFloat(9, image.height.toDouble());
    shader.setFloat(10, hue.$1);
    shader.setFloat(11, hue.$2);
    shader.setFloat(12, hue.$3);
    shader.setImageSampler(0, image);
    paint.shader = shader;
  }

  final ui.FragmentShader shader;
  final ui.Paint paint;
}
