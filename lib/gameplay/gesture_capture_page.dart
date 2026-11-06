import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'gesture_glyph.dart';
import 'gesture_recognizer.dart';
import 'gesture_shapes.dart';

/// A development page, at `?capture=gestures`, for recording real thumbs: the
/// recogniser has only ever seen made-up strokes. It asks for a shape, keeps what
/// was drawn, and copies it all as JSON for `tool/gesture/compare.dart --real`.
/// Nothing leaves the phone unless the person pastes it somewhere. The game never
/// reads this, and words are fine here: nobody plays it.
class GestureCapturePage extends StatefulWidget {
  const GestureCapturePage({super.key, this.copy});

  /// Replaces the clipboard, for a test.
  final void Function(String json)? copy;

  @override
  State<GestureCapturePage> createState() => _GestureCapturePageState();
}

/// The labels the page asks for. 'none' is a plain tap, which must earn nothing.
const captureAsks = ['spin', 'flick', 'wave', 'stomp', 'circle', 'none'];

class _GestureCapturePageState extends State<GestureCapturePage> {
  final _saved = <Map<String, Object>>[];
  final _xy = <double>[];
  final _ms = <int>[];
  Duration? _startedAt;
  String _heard = '';
  int _ask = 0;

  String get _asked => captureAsks[_ask % captureAsks.length];

  void _point(Offset at, Duration time) {
    final origin = _startedAt ??= time;
    _xy
      ..add(at.dx)
      ..add(at.dy);
    _ms.add((time - origin).inMilliseconds);
  }

  void _finish(Size screen) {
    final kind = GestureRecognizer.shipped.classify(_xy);
    setState(() {
      _heard = kind?.name ?? 'none';
      _saved.add({
        'asked': _asked,
        'xy': List<double>.of(_xy),
        'ms': List<int>.of(_ms),
        'width': screen.width,
        'height': screen.height,
      });
      _ask++;
      _xy.clear();
      _ms.clear();
      _startedAt = null;
    });
  }

  void _copy() {
    final json = jsonEncode(_saved);
    final copy = widget.copy;
    if (copy != null) {
      copy(json);
    } else {
      unawaited(Clipboard.setData(ClipboardData(text: json)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = GestureKind.values
        .where((k) => k.name == _asked)
        .firstOrNull;
    return Scaffold(
      backgroundColor: const Color(0xFF101F29),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) {
                    _xy.clear();
                    _ms.clear();
                    _startedAt = null;
                    _point(e.localPosition, e.timeStamp);
                  },
                  onPointerMove: (e) => _point(e.localPosition, e.timeStamp),
                  onPointerUp: (e) {
                    _point(e.localPosition, e.timeStamp);
                    _finish(box.biggest);
                  },
                  onPointerCancel: (_) {
                    _xy.clear();
                    _ms.clear();
                    _startedAt = null;
                  },
                  child: SizedBox.expand(
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        Text(
                          kind == null
                              ? 'Just tap, as you would in the game'
                              : 'Tap and draw: ${kind.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 40),
                        if (kind != null)
                          SizedBox(
                            width: 160,
                            height: 120,
                            child: CustomPaint(
                              painter: GestureGlyphPainter(
                                kind,
                                color: const Color(0xFF7CE2C4),
                                flip: false,
                                size: 90,
                                centred: true,
                                pose: const GlyphPose(1, null),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Text(
              '${_saved.length} saved. Last read as: $_heard',
              style: const TextStyle(color: Colors.white70),
            ),
            // Outside the drawing area, so pressing it is never saved as a stroke.
            TextButton(
              key: const ValueKey('copy-captured'),
              onPressed: _saved.isEmpty ? null : _copy,
              child: const Text('Copy all as JSON'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
