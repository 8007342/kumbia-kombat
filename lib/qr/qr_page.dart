import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr/qr.dart';

import '../console/art_view.dart';
import '../console/console_catalog.dart';
import '../review_links.dart';

const _night = Color(0xFF140B24);
const _dusk = Color(0xFF3B1740);
const _ink = Color(0xFF101F29);
const _paper = Color(0xFFFFF8E7);
const _gold = Color(0xFFFFC35F);
const _rose = Color(0xFFFF7A90);
const _mint = Color(0xFF7CE2C4);

/// The modules of the share code. Error correction Q (25%) keeps it readable
/// with a scuff or a phone's glare; the URL is short, so the code stays small.
QrImage shareQr([String data = ReviewLinks.shareUrl]) => QrImage(
  QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.Q),
);

/// `/qr`: the game's share page. A large code for kumbias.tlatoani.net, framed
/// by the party's own dancers on a warm night.
class QrPage extends StatefulWidget {
  const QrPage({super.key, this.bundle, this.animate = true});
  final AssetBundle? bundle;

  /// Off in tests, which can't settle a page that keeps dancing.
  final bool animate;

  @override
  State<QrPage> createState() => _QrPageState();
}

/// Who dances under the code, by atlas id, and what to call them.
const qrCast = [
  ('gatekeeper', 'The Gatekeeper'),
  ('swing-a', 'The Swing Girls'),
  ('hero', 'Mācron'),
  ('swing-b', ''),
  ('blinblin', 'BlinBlin'),
  ('bartender', 'The Bartender'),
  ('pool-player', 'The Pool Player'),
];

class _QrPageState extends State<QrPage> with ConsolePlayback {
  late final ArtCache _art = ArtCache(widget.bundle);
  late final Future<ConsoleCatalog> _cast = _loadCast();

  Future<ConsoleCatalog> _loadCast() async {
    final bundle = widget.bundle ?? rootBundle;
    Future<String?> read(String path) async {
      try {
        return await bundle.loadString(path);
      } catch (_) {
        return null;
      }
    }

    return ConsoleCatalog.build(
      indexText: '{}',
      levelTexts: const {},
      ensembleText: await read(ConsoleCatalog.ensembleManifest),
      partyText: await read(ConsoleCatalog.partyManifest),
      choreographyText: await read(ConsoleCatalog.choreography),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.animate) startPlayback();
  }

  @override
  void dispose() {
    _art.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final beat = playSeconds * 104 / 60;
    return Scaffold(
      backgroundColor: _night,
      body: CustomPaint(
        painter: _NightPainter(beat),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final side = math.min(box.maxWidth - 48, 420.0).clamp(200.0, 420.0);
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      const _Title(),
                      const SizedBox(height: 18),
                      ShareCode(key: const Key('share-qr'), side: side),
                      const SizedBox(height: 10),
                      const SelectableText(
                        'kumbias.tlatoani.net',
                        style: TextStyle(
                          color: _gold,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'scan it · send it · dance it',
                        style: TextStyle(color: _mint, fontSize: 13, letterSpacing: 2),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: math.min(box.maxWidth, 720),
                        height: 190,
                        child: FutureBuilder<ConsoleCatalog>(
                          future: _cast,
                          builder: (context, snap) => snap.data == null
                              ? const SizedBox.shrink()
                              : _DanceFloor(catalog: snap.data!, art: _art, beat: beat),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      Text(
        'KUMBIA',
        style: TextStyle(
          color: _gold,
          fontSize: 46,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: 6,
          shadows: [
            Shadow(color: _rose, offset: Offset(3, 3)),
            Shadow(color: Colors.black, offset: Offset(6, 6)),
          ],
        ),
      ),
      Text(
        'KOMBAT',
        style: TextStyle(
          color: _paper,
          fontSize: 46,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: 6,
          shadows: [
            Shadow(color: _rose, offset: Offset(3, 3)),
            Shadow(color: Colors.black, offset: Offset(6, 6)),
          ],
        ),
      ),
      SizedBox(height: 8),
      Text(
        'FIND YOUR RHYTHM · JOIN THE PARTY',
        style: TextStyle(color: _mint, fontSize: 12, letterSpacing: 3),
      ),
    ],
  );
}

/// The code itself on a paper card with a four-module quiet zone: dark ink on
/// cream, nothing drawn over it, so any phone camera reads it.
class ShareCode extends StatelessWidget {
  const ShareCode({super.key, required this.side, this.data = ReviewLinks.shareUrl});
  final double side;
  final String data;

  static const quietModules = 4;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(6),
    decoration: const BoxDecoration(
      color: _gold,
      boxShadow: [BoxShadow(color: Colors.black, offset: Offset(6, 6))],
    ),
    child: RepaintBoundary(
      key: const Key('share-qr-pixels'),
      child: CustomPaint(
        size: Size.square(side),
        painter: QrPainter(shareQr(data)),
      ),
    ),
  );
}

class QrPainter extends CustomPainter {
  QrPainter(this.qr);
  final QrImage qr;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _paper);
    final (:module, :origin) = layout(size.shortestSide, qr.moduleCount);
    final ink = Paint()
      ..color = _ink
      ..isAntiAlias = false;
    for (var y = 0; y < qr.moduleCount; y++) {
      for (var x = 0; x < qr.moduleCount; x++) {
        if (!qr.isDark(y, x)) continue;
        canvas.drawRect(
          Rect.fromLTWH(origin + x * module, origin + y * module, module, module),
          ink,
        );
      }
    }
  }

  /// Module size and the first module's corner, for a square of [side].
  /// Whole pixels a module where the space allows, so edges stay crisp.
  static ({double module, double origin}) layout(double side, int moduleCount) {
    final count = moduleCount + 2 * ShareCode.quietModules;
    var module = side / count;
    if (module >= 2) module = module.floorToDouble();
    return (
      module: module,
      origin: (side - module * count) / 2 + module * ShareCode.quietModules,
    );
  }

  @override
  bool shouldRepaint(QrPainter old) => false;
}

class _DanceFloor extends StatelessWidget {
  const _DanceFloor({required this.catalog, required this.art, required this.beat});
  final ConsoleCatalog catalog;
  final ArtCache art;
  final double beat;

  @override
  Widget build(BuildContext context) {
    final cast = [
      for (final (i, (id, name)) in qrCast.indexed)
        if (catalog.atlas(id) case final atlas?) (i, atlas, name),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (i, atlas, name) in cast)
          Expanded(
            flex: atlas.id == 'hero' ? 5 : 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(child: _Dancer(atlas: atlas, art: art, beat: beat + i)),
                SizedBox(
                  height: 28,
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(color: _paper, fontSize: 9, height: 1.1),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Dancer extends StatelessWidget {
  const _Dancer({required this.atlas, required this.art, required this.beat});
  final ConsoleAtlas atlas;
  final ArtCache art;
  final double beat;

  @override
  Widget build(BuildContext context) {
    final clip =
        atlas.clips.where((c) => c.name == 'groove_basic').firstOrNull ??
        atlas.clips.where((c) => c.name == 'groove').firstOrNull;
    final frameId = clip?.frames[clip.indexAt(beat)] ?? atlas.referenceFrame;
    final frame = atlas.frames[frameId];
    if (frame == null) return const SizedBox.shrink();
    final fit = SpritePainter.fitFor([
      for (final f in clip?.frames ?? [frameId!])
        if (atlas.frames[f] != null) atlas.frames[f]!,
    ]);
    return ArtLoader(
      cache: art,
      assets: [atlas.image],
      placeholder: const SizedBox.shrink(),
      builder: (context, images) => SizedBox.expand(
        child: CustomPaint(
          painter: SpritePainter(image: images.single, frame: frame, fit: fit),
        ),
      ),
    );
  }
}

/// A warm night: a dusk glow at the floor, and a string of party lights that
/// pulse on the beat.
class _NightPainter extends CustomPainter {
  _NightPainter(this.beat);
  final double beat;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_night, Color(0xFF241238), _dusk, Color(0xFF5A2A2E)],
          stops: [0, .45, .8, 1],
        ).createShader(rect),
    );
    const colors = [_gold, _rose, _mint, Color(0xFFFFE3A3)];
    for (var row = 0; row < 2; row++) {
      final sag = 26.0 + row * 14;
      final top = 10.0 + row * 22;
      final count = (size.width / 34).ceil() + 1;
      for (var i = 0; i <= count; i++) {
        final t = i / count;
        final x = t * size.width;
        final y = top + sag * 4 * t * (1 - t);
        final on = ((beat + i + row * 2).floor() % 4) == 0;
        final color = colors[(i + row) % colors.length];
        canvas.drawCircle(
          Offset(x, y),
          on ? 7 : 5,
          Paint()..color = color.withValues(alpha: on ? .35 : .12),
        );
        canvas.drawCircle(Offset(x, y), 2.5, Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(_NightPainter old) => old.beat.floor() != beat.floor();
}
