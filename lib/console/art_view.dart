import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'console_catalog.dart';

/// Pictures decoded once per page, by asset path. A failed load stays failed
/// and says so, rather than painting nothing.
class ArtCache {
  ArtCache([AssetBundle? bundle]) : _bundle = bundle ?? rootBundle;
  final AssetBundle _bundle;
  final _images = <String, Future<ui.Image>>{};
  final _ready = <String, ui.Image>{};

  ui.Image? ready(String asset) => _ready[asset];

  Future<ui.Image> load(String asset) => _images.putIfAbsent(asset, () async {
    final data = await _bundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final image = (await codec.getNextFrame()).image;
    _ready[asset] = image;
    return image;
  });

  void dispose() {
    for (final image in _ready.values) {
      image.dispose();
    }
    _ready.clear();
    _images.clear();
  }
}

/// Builds [builder] once every picture in [assets] has loaded.
class ArtLoader extends StatefulWidget {
  const ArtLoader({
    super.key,
    required this.cache,
    required this.assets,
    required this.builder,
    this.placeholder,
  });

  final ArtCache cache;
  final List<String> assets;
  final Widget Function(BuildContext context, List<ui.Image> images) builder;
  final Widget? placeholder;

  @override
  State<ArtLoader> createState() => _ArtLoaderState();
}

class _ArtLoaderState extends State<ArtLoader> {
  late Future<List<ui.Image>> _load = _start();

  Future<List<ui.Image>> _start() =>
      Future.wait([for (final a in widget.assets) widget.cache.load(a)]);

  @override
  void didUpdateWidget(ArtLoader old) {
    super.didUpdateWidget(old);
    if (old.assets.join('|') != widget.assets.join('|')) _load = _start();
  }

  @override
  Widget build(BuildContext context) {
    final now = [for (final a in widget.assets) widget.cache.ready(a)];
    if (now.every((i) => i != null)) {
      return widget.builder(context, now.cast<ui.Image>());
    }
    return FutureBuilder<List<ui.Image>>(
      future: _load,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text(
              'could not load ${widget.assets.join(', ')}',
              style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 11),
            ),
          );
        }
        if (!snap.hasData) {
          return widget.placeholder ??
              const Center(
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
        }
        return widget.builder(context, snap.data!);
      },
    );
  }
}

/// One atlas drawing standing on the bottom of its box. [fit] is the box, in
/// atlas pixels, that every drawing of a clip shares, so a clip doesn't bob
/// in size from frame to frame.
class SpritePainter extends CustomPainter {
  SpritePainter({
    required this.image,
    required this.frame,
    required this.fit,
    this.flip = false,
    this.shadow = true,
  });

  final ui.Image image;
  final ConsoleFrame frame;

  /// Width and height above the feet, and the reach either side of them.
  final ({double up, double down, double left, double right}) fit;
  final bool flip;
  final bool shadow;

  static ({double up, double down, double left, double right}) fitFor(
    Iterable<ConsoleFrame> frames,
  ) {
    var up = 1.0, down = 0.0, left = 1.0, right = 1.0;
    for (final f in frames) {
      up = up < f.anchor.dy ? f.anchor.dy : up;
      final below = f.rect.height - f.anchor.dy;
      down = down < below ? below : down;
      left = left < f.anchor.dx ? f.anchor.dx : left;
      final reach = f.rect.width - f.anchor.dx;
      right = right < reach ? reach : right;
    }
    final side = left > right ? left : right;
    return (up: up, down: down, left: side, right: side);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final wide = fit.left + fit.right;
    final tall = fit.up + fit.down;
    final scale = (size.width / wide < size.height / tall)
        ? size.width / wide
        : size.height / tall;
    final feet = Offset(size.width / 2, size.height - fit.down * scale);
    if (shadow) {
      canvas.drawOval(
        Rect.fromCenter(
          center: feet,
          width: fit.up * scale * .34,
          height: fit.up * scale * .06,
        ),
        Paint()..color = const Color(0x66000000),
      );
    }
    canvas.save();
    canvas.translate(feet.dx, feet.dy);
    if (flip != frame.mirror) canvas.scale(-1, 1);
    canvas.drawImageRect(
      image,
      frame.rect,
      Rect.fromLTWH(
        -frame.anchor.dx * scale,
        -frame.anchor.dy * scale,
        frame.rect.width * scale,
        frame.rect.height * scale,
      ),
      Paint()..filterQuality = FilterQuality.none,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(SpritePainter old) =>
      old.frame != frame || old.image != image || old.flip != flip;
}

/// A drawing's still, for a list or the share page.
class SpriteStill extends StatelessWidget {
  const SpriteStill({
    super.key,
    required this.cache,
    required this.atlas,
    required this.frame,
    this.flip = false,
    this.shadow = true,
  });

  final ArtCache cache;
  final ConsoleAtlas atlas;
  final String frame;
  final bool flip;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final f = atlas.frames[frame];
    if (f == null) return const SizedBox.shrink();
    return ArtLoader(
      cache: cache,
      assets: [atlas.image],
      placeholder: const SizedBox.shrink(),
      builder: (context, images) => SizedBox.expand(
        child: CustomPaint(
          painter: SpritePainter(
            image: images.single,
            frame: f,
            fit: SpritePainter.fitFor([f]),
            flip: flip,
            shadow: shadow,
          ),
        ),
      ),
    );
  }
}

/// A ticker in seconds for anything that plays, stopped while [playing] is false.
mixin ConsolePlayback<T extends StatefulWidget> on State<T> {
  Timer? _timer;
  final _clock = Stopwatch();
  double _offset = 0;

  double get playSeconds => _offset + _clock.elapsedMicroseconds / 1e6;
  bool get playing => _clock.isRunning;

  void startPlayback() {
    _clock.start();
    _timer ??= Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (mounted) setState(() {});
    });
  }

  void stopPlayback() {
    _offset = playSeconds;
    _clock
      ..stop()
      ..reset();
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() {});
  }

  void seekPlayback(double seconds) {
    _offset = seconds;
    _clock.reset();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
