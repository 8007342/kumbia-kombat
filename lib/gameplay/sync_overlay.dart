import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'sync_calibration.dart';

const _ink = Color(0xFF101F29);
const _cream = Color(0xFFFFF0D1);
const _gold = Color(0xFFFFC35F);
const _mint = Color(0xFF7CE2C4);
const _blue = Color(0xFF72DDF7);
const _ember = Color(0xFFFF7F5C);

/// The tap-along, reached from the title screen. Four clicks to listen to, then
/// sixteen to tap with, anywhere. It measures by ear on purpose: nothing on
/// screen moves with the beat. The result shifts judging, never the music.
class SyncCalibrationOverlay extends StatefulWidget {
  const SyncCalibrationOverlay({
    super.key,
    required this.activate,
    required this.nowMs,
    required this.judgeOffsetMs,
    required this.eventAgeMs,
    required this.click,
    required this.saved,
    required this.onSave,
    required this.onClose,
  });

  /// Wakes the sound, inside the press that opened this.
  final Future<void> Function() activate;

  /// The audio clock, in milliseconds.
  final int Function() nowMs;

  /// What the game already takes off a tap: latency estimate and touch delay.
  final int Function() judgeOffsetMs;

  /// How old a pointer event is, by its own time stamp, in milliseconds.
  final int Function(Duration timeStamp) eventAgeMs;

  /// Plays one click at an audio-clock time, in seconds.
  final void Function(double atSeconds, {required bool accent}) click;

  /// The offset this device already has, if any.
  final int? saved;

  /// Saves an offset, or null to clear it.
  final void Function(int? offsetMs) onSave;
  final VoidCallback onClose;

  @override
  State<SyncCalibrationOverlay> createState() => _SyncCalibrationOverlayState();
}

class _SyncCalibrationOverlayState extends State<SyncCalibrationOverlay>
    with SingleTickerProviderStateMixin {
  SyncCalibration? _run;
  bool _waking = false;
  bool _finished = false;
  int? _result;
  String? _error;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _tick())..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick() {
    final run = _run;
    if (run == null || _finished) return;
    if (widget.nowMs() > run.endMs) {
      setState(() {
        _finished = true;
        _result = run.offsetMs;
        if (_result != null) widget.onSave(_result);
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _begin() async {
    if (_waking) return;
    setState(() {
      _waking = true;
      _error = null;
    });
    try {
      await widget.activate();
    } catch (_) {
      if (mounted) {
        setState(() {
          _waking = false;
          _error = 'Sound needs your permission. Tap again.';
        });
      }
      return;
    }
    if (!mounted) return;
    final run = SyncCalibration(firstClickMs: widget.nowMs() + 700);
    for (final (i, at) in run.clicksMs.indexed) {
      widget.click(at / 1000, accent: i % 4 == 0);
    }
    setState(() {
      _waking = false;
      _finished = false;
      _result = null;
      _run = run;
    });
  }

  void _tap(PointerDownEvent event) {
    final run = _run;
    if (run == null || _finished) return;
    run.tap(
      widget.nowMs() - widget.judgeOffsetMs() - widget.eventAgeMs(event.timeStamp),
    );
  }

  @override
  Widget build(BuildContext context) {
    final run = _run;
    final listening = run != null && !_finished;
    final clickIndex = run == null
        ? -1
        : ((widget.nowMs() - run.firstClickMs) / run.beatMs).floor();
    final String headline;
    final String detail;
    if (listening) {
      headline = clickIndex < run.countInClicks ? 'LISTEN…' : 'TAP WITH THE CLICK';
      detail = clickIndex < run.countInClicks
          ? 'Four clicks to listen to. Then tap anywhere, on each click.'
          : 'Taps: ${run.deltasMs.length} of ${run.tapClicks}. Listen, don\'t watch.';
    } else if (_finished && _result == null) {
      headline = 'NOT QUITE';
      detail = 'Too few steady taps to trust. Try once more, in time with the click.';
    } else if (_finished) {
      headline = 'IN SYNC';
      detail = 'Saved for this phone. ${_describe(_result!)}';
    } else {
      headline = 'SYNC';
      detail =
          'Phones play sound a little late. Tap along with sixteen clicks and the '
          'game learns how late this one is. It changes how taps are judged, '
          'never the music. Headphones? Calibrate with them on.';
    }
    final shown = _finished ? _result : widget.saved;
    return Positioned.fill(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: listening ? _tap : null,
        child: ColoredBox(
          color: _ink.withValues(alpha: .94),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
              child: Column(
                children: [
                  const Spacer(),
                  Text(
                    headline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _cream,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    detail,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _cream.withValues(alpha: .75),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: _gold, fontSize: 11),
                      ),
                    ),
                  const SizedBox(height: 28),
                  if (!listening && shown != null)
                    SizedBox(
                      height: 44,
                      width: double.infinity,
                      child: CustomPaint(painter: SyncBarPainter(shown)),
                    ),
                  const Spacer(),
                  if (!listening) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _waking ? null : _begin,
                        style: FilledButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: _ink,
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: Text(
                          _waking
                              ? 'WAKING THE MUSIC…'
                              : run == null
                              ? 'START  >'
                              : 'AGAIN  >',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      children: [
                        if (widget.saved != null || _result != null)
                          _option('FORGET SYNC', () {
                            widget.onSave(null);
                            setState(() {
                              _result = null;
                              _run = null;
                              _finished = false;
                            });
                          }),
                        _option('DONE', widget.onClose),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _describe(int offsetMs) {
    if (offsetMs.abs() < 10) return 'Your taps land right on the click.';
    final way = offsetMs > 0 ? 'after' : 'before';
    return 'Your taps land a touch $way the click here, and the game now allows for it.';
  }

  Widget _option(String label, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(foregroundColor: _cream.withValues(alpha: .6)),
    child: Text(label, style: const TextStyle(fontSize: 9, letterSpacing: 1)),
  );
}

/// The saved offset as a sync slider, not a number: early on the left in the
/// early mark's blue, late on the right in the late mark's ember.
class SyncBarPainter extends CustomPainter {
  SyncBarPainter(this.offsetMs);
  final int offsetMs;

  /// Where the marker sits, 0 (most early) to 1 (most late).
  static double position(int offsetMs) =>
      .5 + offsetMs / (2 * SyncCalibration.maxOffsetMs);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final track = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width / 2, y),
      track..color = _blue.withValues(alpha: .45),
    );
    canvas.drawLine(
      Offset(size.width / 2, y),
      Offset(size.width, y),
      track..color = _ember.withValues(alpha: .45),
    );
    canvas.drawLine(
      Offset(size.width / 2, y - 9),
      Offset(size.width / 2, y + 9),
      Paint()
        ..strokeWidth = 2
        ..color = _cream.withValues(alpha: .5),
    );
    final x = position(offsetMs).clamp(0.0, 1.0) * size.width;
    canvas.drawCircle(Offset(x, y), 11, Paint()..color = _ink);
    canvas.drawCircle(Offset(x, y), 8, Paint()..color = _mint);
  }

  @override
  bool shouldRepaint(SyncBarPainter oldDelegate) =>
      oldDelegate.offsetMs != offsetMs;
}
