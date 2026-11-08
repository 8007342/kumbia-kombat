import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../console/browser.dart';
import 'credits_data.dart';

const _ink = Color(0xFF101F29);
const _cream = Color(0xFFFFF0D1);
const _gold = Color(0xFFFFC35F);
const _mint = Color(0xFF7CE2C4);
const _dim = Color(0xFF9FB3C0);

/// The credits roll: music plays while every package and tool the game was
/// built with scrolls up. "Built using / Tillandsias.org" first, then the base,
/// then what the game uses directly, large and in one column, then what those
/// use, in more columns and smaller text the further away they are.
///
/// It plays after the last level's end screen, and at `/credits/`, which the
/// console links to. `openspec/changes/add-credits-roll/specs/credits-roll/spec.md`.
class CreditsPage extends StatefulWidget {
  const CreditsPage({
    super.key,
    this.load,
    this.browser,
    this.closeWhenDone = false,
    this.pixelsPerSecond = 46,
  });

  /// The shipping `assets/credits.json` unless a test gives its own.
  final Future<CreditsData> Function()? load;

  /// For the music; the browser's `<audio>` on the web, silent in tests.
  final ConsoleBrowser? browser;

  /// After the game's end screen the roll goes back there by itself once it
  /// has run out. On its own page it stays, so it can be read.
  final bool closeWhenDone;
  final double pixelsPerSecond;

  @override
  State<CreditsPage> createState() => _CreditsPageState();
}

class _CreditsPageState extends State<CreditsPage>
    with SingleTickerProviderStateMixin {
  late final ConsoleBrowser _browser = widget.browser ?? createConsoleBrowser();
  late final ConsoleAudio _audio = _browser.audio();
  late final Future<CreditsData> _data = (widget.load ?? CreditsData.load)();
  final _scroll = ScrollController();
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  bool _held = false;
  bool _musicStarted = false;
  bool _soundBlocked = false;
  double _doneFor = 0;
  bool _closed = false;
  Timer? _soundCheck;

  @override
  void initState() {
    super.initState();
    _data.then((data) {
      if (!mounted) return;
      final music = data.music;
      if (music != null) {
        _audio.play(opus: music.opus, aac: music.aac, loop: true);
        _musicStarted = true;
        // A page opened by a link has had no tap yet, and browsers hold its
        // sound back. Then the speaker asks for one.
        _soundCheck = Timer(const Duration(milliseconds: 1500), () {
          if (mounted && !_audio.playing) setState(() => _soundBlocked = true);
        });
      }
      _ticker.start();
      setState(() {});
    }).ignore();
  }

  @override
  void dispose() {
    _soundCheck?.cancel();
    _ticker.dispose();
    _scroll.dispose();
    _audio.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (_held || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent) {
      _doneFor += dt;
      if (widget.closeWhenDone && _doneFor > 4) _close();
      return;
    }
    _doneFor = 0;
    _scroll.jumpTo(
      math.min(
        position.maxScrollExtent,
        position.pixels + dt.clamp(0, .1) * widget.pixelsPerSecond,
      ),
    );
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    _audio.pause();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      _browser.open('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      body: FutureBuilder<CreditsData>(
        future: _data,
        builder: (context, snap) {
          final data = snap.data;
          return Stack(
            children: [
              if (data != null)
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, box) => NotificationListener<
                      ScrollNotification
                    >(
                      onNotification: (n) {
                        // A thumb on the roll holds it, and it carries on from
                        // wherever the thumb left it.
                        if (n is ScrollStartNotification && n.dragDetails != null) {
                          _held = true;
                        } else if (n is ScrollEndNotification) {
                          _held = false;
                        }
                        return false;
                      },
                      child: SingleChildScrollView(
                        key: const Key('credits-roll'),
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: _Roll(data: data, viewport: box.maxHeight),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (snap.hasError)
                Center(
                  child: Text(
                    'The credits could not load.',
                    style: TextStyle(color: _cream.withValues(alpha: .7)),
                  ),
                ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_musicStarted && _soundBlocked)
                        IconButton(
                          key: const Key('credits-sound'),
                          tooltip: 'Sound',
                          color: _gold,
                          icon: const Icon(Icons.volume_up),
                          onPressed: () {
                            _audio.resume();
                            setState(() => _soundBlocked = false);
                          },
                        ),
                      IconButton(
                        key: const Key('credits-close'),
                        tooltip: 'Close',
                        color: _cream.withValues(alpha: .6),
                        icon: const Icon(Icons.close),
                        onPressed: _close,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The whole roll, laid out once. Starts a screen below the top so the first
/// line rises into view, and ends with the last lines leaving room to be read.
class _Roll extends StatelessWidget {
  const _Roll({required this.data, required this.viewport});

  final CreditsData data;
  final double viewport;

  static const kindTitles = {
    'platform': '',
    'tool': 'TOOLS',
    'model': 'MODELS',
    'font': 'TYPE',
    'dart': 'DART PACKAGES',
    'rust': 'RUST CRATES, FOR THE MIXER',
    'python': 'PYTHON PACKAGES',
    'node': 'NODE PACKAGES',
  };

  @override
  Widget build(BuildContext context) {
    final direct = data.at(1);
    final kinds = <String>{
      for (final kind in kindTitles.keys)
        if (direct.any((i) => i.kind == kind)) kind,
      for (final item in direct)
        if (!kindTitles.containsKey(item.kind)) item.kind,
    };
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 560;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: viewport),
            Text(
              data.lead,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _mint,
                fontSize: 14,
                letterSpacing: 3,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data.name,
              key: const Key('credits-header'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _gold,
                fontSize: 40,
                height: 1,
                letterSpacing: -1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 48),
            for (final item in data.at(0)) ...[
              _Line(item, size: 26, role: false),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 56),
            for (final kind in kinds) ...[
              _Heading(kindTitles[kind] ?? kind.toUpperCase()),
              for (final item in direct.where((i) => i.kind == kind)) ...[
                _Line(item, size: 18, role: true),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 36),
            ],
            if (data.at(2).isNotEmpty) ...[
              const _Heading('AND WHAT THEY USE'),
              _Columns(data.at(2), columns: wide ? 3 : 2, size: 12),
              const SizedBox(height: 48),
            ],
            if (data.at(3, orDeeper: true).isNotEmpty) ...[
              const _Heading('AND WHAT THOSE USE, ALL THE WAY DOWN'),
              _Columns(
                data.at(3, orDeeper: true),
                columns: wide ? 4 : 3,
                size: 9,
              ),
              const SizedBox(height: 80),
            ],
            const Text(
              'KUMBIA KOMBAT',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _cream,
                fontSize: 30,
                letterSpacing: -1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '¡Gracias!',
              textAlign: TextAlign.center,
              style: TextStyle(color: _gold.withValues(alpha: .9), fontSize: 16),
            ),
            SizedBox(height: viewport * .45),
          ],
        );
      },
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: _mint,
        fontSize: 10,
        letterSpacing: 2.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// One credit, large: its name and version, and what it did for us.
class _Line extends StatelessWidget {
  const _Line(this.item, {required this.size, required this.role});
  final CreditItem item;
  final double size;
  final bool role;

  @override
  Widget build(BuildContext context) => Column(
    key: ValueKey('credit:${item.kind}:${item.name}'),
    children: [
      Text(
        item.label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _cream,
          fontSize: size,
          height: 1.1,
          fontWeight: FontWeight.w800,
        ),
      ),
      if (role && item.role != null)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            item.role!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _dim, fontSize: 10),
          ),
        ),
    ],
  );
}

/// Credits further from the game: more to a row and smaller, the way a film's
/// crew list ends.
class _Columns extends StatelessWidget {
  const _Columns(this.items, {required this.columns, required this.size});
  final List<CreditItem> items;
  final int columns;
  final double size;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const gap = 8.0;
      final width = (box.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: size * .5,
        children: [
          for (final item in items)
            SizedBox(
              key: ValueKey('credit:${item.kind}:${item.name}'),
              width: width,
              child: Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _cream.withValues(alpha: .8),
                  fontSize: size,
                  height: 1.2,
                ),
              ),
            ),
        ],
      );
    },
  );
}
