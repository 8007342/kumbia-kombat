import 'dart:ui' as ui;

enum OutfitColor { teal, blue, coral, gold }

/// Recolor the reserved clothing ramp once, then retain ordinary atlas images.
/// Gameplay never records a fragment shader or a shader-backed picture. The
/// source atlas stays visible until a validated variant is available.
class OutfitPalette {
  OutfitPalette._(this._compiledProgram);

  /// Explicit source-art mode for renderers without fragment shader support.
  OutfitPalette.sourceOnly() : _compiledProgram = null;

  final ui.FragmentProgram? _compiledProgram;
  static Future<ui.FragmentProgram>? _program;
  static const maxVariants = 12; // Three guest atlases × four wardrobes.
  final Map<(ui.Image, OutfitColor), ui.Image> _images = {};
  final Map<(ui.Image, OutfitColor), Future<void>> _requests = {};
  final ui.Paint _paint = ui.Paint()..filterQuality = ui.FilterQuality.none;
  Future<void> _queue = Future<void>.value();
  bool _disposed = false;
  Object? lastPreparationError;

  int get cachedVariantCount => _images.length;

  /// Compilation failure affects wardrobe variety, never character visibility.
  static Future<OutfitPalette> load() async {
    try {
      return OutfitPalette._(
        await (_program ??= ui.FragmentProgram.fromAsset(
          'shaders/party_palette.frag',
        )),
      );
    } catch (error) {
      return OutfitPalette.sourceOnly()..lastPreparationError = error;
    }
  }

  /// Optional prewarm. Calls are deduplicated and raster jobs run serially to
  /// avoid twelve simultaneous atlas allocations/readbacks on mobile browsers.
  /// Errors leave source art in place and are available for diagnostics above.
  Future<void> prepare(ui.Image image, OutfitColor palette) {
    if (_disposed || _compiledProgram == null) return Future<void>.value();
    final key = (image, palette);
    final existing = _requests[key];
    if (existing != null) return existing;
    if (_requests.length >= maxVariants) return Future<void>.value();
    final retainedSource = image.clone();
    final request = _queue.then((_) async {
      try {
        // Let the browser present source art between expensive atlas readbacks.
        await Future<void>.delayed(Duration.zero);
        if (_disposed) return;
        final raster = await _rasterize(retainedSource, palette);
        if (_disposed) {
          raster.dispose();
        } else {
          _images[key] = raster;
        }
      } catch (error) {
        lastPreparationError = error;
      } finally {
        retainedSource.dispose();
      }
    });
    _requests[key] = request;
    _queue = request;
    return request;
  }

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
    prepare(image, palette);
    canvas.drawImageRect(
      _images[(image, palette)] ?? image,
      source,
      destination,
      _paint,
    );
  }

  Future<ui.Image> _rasterize(ui.Image source, OutfitColor palette) async {
    final shader = _compiledProgram!.fragmentShader();
    ui.Picture? picture;
    ui.Image? result;
    try {
      final hue = switch (palette) {
        OutfitColor.teal => (0.18, 0.72, 0.60),
        OutfitColor.blue => (0.23, 0.47, 0.92),
        OutfitColor.coral => (0.94, 0.34, 0.25),
        OutfitColor.gold => (0.95, 0.69, 0.19),
      };
      final width = source.width.toDouble();
      final height = source.height.toDouble();
      final uniforms = [
        0.0,
        0.0,
        width,
        height,
        0.0,
        0.0,
        width,
        height,
        width,
        height,
        hue.$1,
        hue.$2,
        hue.$3,
      ];
      for (var i = 0; i < uniforms.length; i++) {
        shader.setFloat(i, uniforms[i]);
      }
      shader.setImageSampler(0, source);
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        ui.Rect.fromLTWH(0, 0, width, height),
        ui.Paint()..shader = shader,
      );
      picture = recorder.endRecording();
      result = await picture.toImage(source.width, source.height);

      // Reject transparent/partial output before replacing a visible source.
      // Alpha must survive at every atlas pixel, including every animation pose.
      final original = await source.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final output = await result.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (original == null ||
          output == null ||
          original.lengthInBytes != output.lengthInBytes) {
        throw StateError('Cannot validate wardrobe image alpha');
      }
      for (var i = 3; i < original.lengthInBytes; i += 4) {
        if ((original.getUint8(i) - output.getUint8(i)).abs() > 2) {
          throw StateError('Wardrobe raster changed source alpha');
        }
      }
      return result;
    } catch (_) {
      result?.dispose();
      rethrow;
    } finally {
      picture?.dispose();
      shader.dispose();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    _requests.clear();
  }
}
