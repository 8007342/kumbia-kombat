// Compares sprite filters through a depth move, in the real renderer.
// Build: flutter build web -t tool/probes/depth_probe_main.dart --output build/web/probe --base-href /probe/
// Open /probe/?t=0.25 to freeze a move position, or no t to animate at 170 BPM over 8 beats.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

const _atlasName = 'bartender';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final manifest = jsonDecode(
    await rootBundle.loadString('assets/art/ensemble/manifest.json'),
  )['atlases'][_atlasName];
  final bytes = await rootBundle.load(
    'assets/art/ensemble/${manifest['image']}',
  );
  final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
  final atlas = (await codec.getNextFrame()).image;
  final rect = (manifest['frames'][manifest['referenceFrame']]['rect'] as List)
      .cast<num>();
  final src = Rect.fromLTWH(
    rect[0].toDouble(),
    rect[1].toDouble(),
    rect[2].toDouble(),
    rect[3].toDouble(),
  );
  // Sharp route: a 4x nearest copy of this one frame, then linear filtering.
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawImageRect(
    atlas,
    src,
    Rect.fromLTWH(0, 0, src.width * 4, src.height * 4),
    Paint()..filterQuality = ui.FilterQuality.none,
  );
  final sharp = await recorder.endRecording().toImage(
    src.width.toInt() * 4,
    src.height.toInt() * 4,
  );
  final fixed = double.tryParse(Uri.base.queryParameters['t'] ?? '');
  runApp(_Probe(atlas, src, sharp, fixed));
}

class _Probe extends StatefulWidget {
  const _Probe(this.atlas, this.src, this.sharp, this.fixed);
  final ui.Image atlas, sharp;
  final Rect src;
  final double? fixed;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;
  @override
  void initState() {
    super.initState();
    _t = widget.fixed ?? 0;
    _ticker = createTicker((e) {
      if (widget.fixed == null) {
        setState(() => _t = e.inMicroseconds / 1e6 / (8 * 60 / 170) % 1);
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _Painter(widget.atlas, widget.src, widget.sharp, _t),
    size: Size.infinite,
  );
}

class _Painter extends CustomPainter {
  _Painter(this.atlas, this.src, this.sharp, this.t);
  final ui.Image atlas, sharp;
  final Rect src;
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF1E2830), BlendMode.src);
    final footY = .42 + .16 * (.5 - .5 * math.cos(2 * math.pi * t));
    final height = .1263 * (footY - .16) / (.4 - .16) * size.height;
    final width = height * src.width / src.height;
    final ground = size.height * .9;
    Rect at(int col) => Rect.fromLTWH(
      size.width * (col + .5) / 3 - width / 2,
      ground - height,
      width,
      height,
    );
    canvas.drawImageRect(
      atlas,
      src,
      at(0),
      Paint()..filterQuality = ui.FilterQuality.none,
    );
    canvas.drawImageRect(
      atlas,
      src,
      at(1),
      Paint()..filterQuality = ui.FilterQuality.low,
    );
    canvas.drawImageRect(
      sharp,
      Rect.fromLTWH(0, 0, sharp.width.toDouble(), sharp.height.toDouble()),
      at(2),
      Paint()..filterQuality = ui.FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(_Painter old) => old.t != t;
}
