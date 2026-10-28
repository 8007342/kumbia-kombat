import 'dart:ui' as ui;

enum OutfitColor { teal, blue, coral, gold }

/// GPU-only clothing recolor. Reserved cool purple, saturated plum and bright
/// pink gates are reviewed against the ensemble v2 clothing/skin/hair pixels.
/// Arbitrary art must not opt in without a new mask/palette review.
class OutfitPalette {
  OutfitPalette._(this._compiledProgram);
  final ui.FragmentProgram _compiledProgram;
  final Map<(ui.Image, OutfitColor, ui.Rect), _OutfitVariant> _variants = {};
  static Future<ui.FragmentProgram>? _program;
  bool _disposed = false;

  int get cachedVariantCount => _variants.length;

  /// Cache the compiled program, but own/dispose each renderer's picture pool.
  /// Failure is explicit: the caller may show source plum without claiming a
  /// recolored variant. Do not silently run a global ColorFilter fallback.
  static Future<OutfitPalette> load() async {
    final program = await (_program ??= ui.FragmentProgram.fromAsset(
      'shaders/party_palette.frag',
    ));
    return OutfitPalette._(program);
  }

  /// Draw a retained GPU picture for each atlas pose/palette. Position, scale and
  /// facing belong to the canvas. Recording once avoids both mutable shader
  /// state and CanvasKit sampler wrappers expiring between animation frames.
  void draw(
    ui.Canvas canvas, {
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
    final variant = _variants.putIfAbsent(
      (image, palette, source),
      () => _OutfitVariant(
        _compiledProgram.fragmentShader(),
        image,
        source,
        palette,
      ),
    );
    canvas.save();
    canvas.translate(destination.left, destination.top);
    canvas.scale(
      destination.width / source.width,
      destination.height / source.height,
    );
    canvas.drawPicture(variant.picture);
    canvas.restore();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final variant in _variants.values) {
      variant.picture.dispose();
      variant.shader.dispose();
    }
    _variants.clear();
  }
}

/// Keep both the recorded picture and its initialized shader alive: CanvasKit's
/// recorded draws retain shader resources, including its uniform buffer. No
/// sampler is rebound after recording. This retains drawing commands, not
/// recolored atlas copies; the cache is bounded by poses × wardrobe palettes.
class _OutfitVariant {
  _OutfitVariant(
    this.shader,
    ui.Image image,
    ui.Rect source,
    OutfitColor palette,
  ) {
    final hue = switch (palette) {
      OutfitColor.teal => (0.18, 0.72, 0.60),
      OutfitColor.blue => (0.23, 0.47, 0.92),
      OutfitColor.coral => (0.94, 0.34, 0.25),
      OutfitColor.gold => (0.95, 0.69, 0.19),
    };
    final uniforms = [
      0.0,
      0.0,
      source.width,
      source.height,
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
      shader.setFloat(i, uniforms[i]);
    }
    shader.setImageSampler(0, image);
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      ui.Offset.zero & source.size,
      ui.Paint()
        ..filterQuality = ui.FilterQuality.none
        ..shader = shader,
    );
    picture = recorder.endRecording();
  }

  final ui.FragmentShader shader;
  late final ui.Picture picture;
}
