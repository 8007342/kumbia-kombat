import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../gameplay/exit_shot.dart';
import '../gameplay/level_definition.dart';
import '../review_links.dart';
import 'art_view.dart';
import 'browser.dart';
import 'console_catalog.dart';
import 'console_notes.dart';

const consoleInk = Color(0xFF101F29);
const consolePanel = Color(0xFF182C3A);
const consoleCream = Color(0xFFFFF0D1);
const consoleGold = Color(0xFFFFC35F);
const consoleMint = Color(0xFF7CE2C4);
const consoleRose = Color(0xFFFF7A90);
const consoleDim = Color(0xFF9FB3C0);

/// `/console`: the curation page. Every level, take, room, layer, clip and
/// close-up the data names, each with its reference and a note box, and buttons
/// that start the game where you want to look.
///
/// `openspec/changes/add-curation-console/specs/curation-console/spec.md`.
class ConsolePage extends StatefulWidget {
  const ConsolePage({
    super.key,
    this.catalog,
    this.browser,
    this.registry,
    this.bundle,
  });

  /// The shipping data unless a test gives its own.
  final Future<ConsoleCatalog> Function()? catalog;
  final ConsoleBrowser? browser;

  /// For the close-ups, which play the game's own [ExitShot].
  final Future<LevelRegistry> Function()? registry;
  final AssetBundle? bundle;

  @override
  State<ConsolePage> createState() => _ConsolePageState();
}

class _ConsolePageState extends State<ConsolePage> {
  late final ConsoleBrowser _browser = widget.browser ?? createConsoleBrowser();
  late final ConsoleNotes _notes = ConsoleNotes(_browser);
  late final ArtCache _art = ArtCache(widget.bundle);
  late final Future<ConsoleCatalog> _catalog =
      (widget.catalog ?? () => ConsoleCatalog.load(widget.bundle ?? rootBundle))();
  late final Future<LevelRegistry?> _registry =
      (widget.registry ??
              () => LevelRegistry.load(widget.bundle ?? rootBundle))()
          .then<LevelRegistry?>((r) => r)
          .catchError((Object _) => null);
  late final ConsoleAudio _audio = _browser.audio();
  ConsoleTrack? _track;
  Timer? _audioTick;

  @override
  void dispose() {
    _audioTick?.cancel();
    _audio.dispose();
    _art.dispose();
    super.dispose();
  }

  void _play(ConsoleTrack track) {
    if (_track == track) {
      _audio.playing ? _audio.pause() : _audio.resume();
    } else {
      _track = track;
      _audio.play(
        opus: track.files['opus'] ?? track.files.values.first,
        aac: track.files['aac'] ?? track.files.values.first,
      );
    }
    _audioTick ??= Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
    setState(() {});
  }

  Future<void> _copyNotes() async {
    await Clipboard.setData(ClipboardData(text: _notes.asText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${_notes.count} notes with their references')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        scaffoldBackgroundColor: consoleInk,
        textTheme: theme.textTheme.apply(
          bodyColor: consoleCream,
          displayColor: consoleCream,
        ),
      ),
      child: DefaultTabController(
        length: 6,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: consoleInk,
            foregroundColor: consoleCream,
            titleSpacing: 12,
            title: const _RetroTitle('KUMBIA KOMBAT', 'CONSOLE'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _RetroButton(
                  key: const Key('copy-all-notes'),
                  label: 'COPY NOTES (${_notes.count})',
                  onPressed: _copyNotes,
                ),
              ),
            ],
            bottom: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: consoleGold,
              unselectedLabelColor: consoleDim,
              indicatorColor: consoleGold,
              tabs: [
                Tab(text: 'LEVELS'),
                Tab(text: 'MUSIC'),
                Tab(text: 'ROOMS'),
                Tab(text: 'MOVES'),
                Tab(text: 'CLOSE-UPS'),
                Tab(text: 'NOTES'),
              ],
            ),
          ),
          body: FutureBuilder<ConsoleCatalog>(
            future: _catalog,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('The data could not load: ${snap.error}'));
              }
              final catalog = snap.data;
              if (catalog == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return TabBarView(
                children: [
                  _levelsTab(catalog),
                  _musicTab(catalog),
                  _roomsTab(catalog),
                  _MovesTab(catalog: catalog, art: _art, note: _noteBox),
                  _closeupsTab(catalog),
                  _notesTab(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _noteBox(String ref, String source) => _NoteBox(
    key: ValueKey('note:$ref'),
    ref: ref,
    source: source,
    notes: _notes,
    onChanged: () => setState(() {}),
  );

  Widget _list(ConsoleCatalog catalog, List<Widget> children) => ListView(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 48),
    children: [
      if (catalog.problems.isNotEmpty)
        _Card(
          title: 'Not everything could be read',
          ref: 'console / problems',
          children: [
            for (final p in catalog.problems)
              Text(p, style: const TextStyle(color: consoleRose, fontSize: 12)),
          ],
        ),
      ...children,
    ],
  );

  // LEVELS ------------------------------------------------------------------

  Widget _levelsTab(ConsoleCatalog catalog) => _list(catalog, [
    _Card(
      title: 'The whole night',
      ref: 'game / campaign',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _link('PLAY', ReviewLinks.play()),
            _link('AUTOPLAY FLAWLESS', ReviewLinks.play(flawless: true)),
            _link('MIXER', ReviewLinks.play(mixer: true)),
            _link('SYNC', ReviewLinks.play(sync: true)),
            _link('LISTENING PAGE', '/listen/'),
            _link('SHARE QR', '/qr/'),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const _Fine('latency ms'),
            for (final ms in ReviewLinks.latencyTrials)
              _link('$ms', ReviewLinks.play(latencyMs: ms), small: true),
          ],
        ),
        const SizedBox(height: 8),
        const _Fine(
          'SYNC opens the tap-along calibration. A latency link sets output and '
          'touch delay as one number and sets calibration aside; 0 turns '
          'compensation off. A level link plays that level alone and ends on its end screen. '
          'TIER starts the first phrase at that tier: the crowd and band still '
          'start cold. OUTRO is tier 4 on autoplay, the quickest way to the '
          'close-up and the walk out in the game itself.',
        ),
        _noteBox('game / campaign', 'levels/index.json'),
      ],
    ),
    for (final level in catalog.levels)
      _Card(
        key: ValueKey('level:${level.id}'),
        title:
            '${level.number == null ? 'not in campaign' : level.number.toString().padLeft(2, '0')}  ${level.title}',
        ref: level.ref,
        source: level.file,
        children: [
          _Facts({
            'opponent': [
              for (final o in level.opponents)
                o.id == o.atlas ? o.id : '${o.id} (atlas ${o.atlas})',
            ].join(', '),
            'score': [?level.score, ?level.successScore].join(', '),
            'tempos': [
              for (final t in catalog.tracksFor(level.id))
                if (t.key.startsWith('takes.'))
                  '${t.name} ${t.bpm?.toStringAsFixed(0)}',
            ].join(' · '),
            'bridge': level.bridgeToNext ?? '—',
            if (level.inReview) 'review': 'listed in index.json review',
          }),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _link('PLAY', ReviewLinks.play(level: level.id)),
              _link('FLAWLESS', ReviewLinks.play(level: level.id, flawless: true)),
              _link(
                'OUTRO',
                ReviewLinks.play(level: level.id, flawless: true, tier: 4),
              ),
              _link('MIXER', ReviewLinks.play(level: level.id, mixer: true)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const _Fine('start at tier'),
              for (var tier = 0; tier <= 4; tier++)
                _link(
                  'T$tier',
                  ReviewLinks.play(level: level.id, tier: tier),
                  small: true,
                ),
              const _Fine('flawless'),
              for (var tier = 0; tier <= 4; tier++)
                _link(
                  'T$tier',
                  ReviewLinks.play(level: level.id, tier: tier, flawless: true),
                  small: true,
                ),
            ],
          ),
          _noteBox(level.ref, level.file),
        ],
      ),
  ]);

  Widget _link(String label, String url, {bool small = false}) => _RetroButton(
    key: Key('link:$url:$label'),
    label: label,
    small: small,
    tooltip: url,
    onPressed: () => _browser.open(url),
  );

  // MUSIC -------------------------------------------------------------------

  Widget _musicTab(ConsoleCatalog catalog) {
    final byLevel = <String, List<ConsoleTrack>>{};
    for (final t in catalog.tracks) {
      byLevel.putIfAbsent(t.level, () => []).add(t);
    }
    return _list(catalog, [
      for (final entry in byLevel.entries)
        _Card(
          title: catalog.level(entry.key)?.title ?? entry.key,
          ref: 'music / ${entry.key}',
          source: 'assets/music/rendered/manifest.json › levels.${entry.key}',
          children: [
            if (entry.value.first.musicalKey != null)
              _Fine('key ${entry.value.first.musicalKey}'),
            for (final track in entry.value) _trackRow(track),
            _noteBox('music / ${entry.key}', 'assets/music/rendered/manifest.json'),
          ],
        ),
    ]);
  }

  Widget _trackRow(ConsoleTrack track) {
    final current = _track == track;
    final playing = current && _audio.playing;
    final length = current && _audio.duration.isFinite
        ? _audio.duration
        : track.seconds ?? 0;
    final position = current ? _audio.position : 0.0;
    return Container(
      key: ValueKey('track:${track.ref}'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: current ? const Color(0xFF213B4D) : const Color(0x22000000),
        border: Border.all(color: current ? consoleGold : const Color(0x33FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                key: Key('play:${track.ref}'),
                color: consoleGold,
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                onPressed: () => _play(track),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.name.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: consoleCream,
                      ),
                    ),
                    _Fine(
                      [
                        if (track.bpm != null) '${track.bpm!.toStringAsFixed(0)} BPM',
                        if (track.bars != null) '${track.bars} bars',
                        if (track.seconds != null) _clock(track.seconds!),
                        if (track.lufs != null) '${track.lufs} LUFS',
                      ].join(' · '),
                    ),
                    _RefChip(track.ref),
                  ],
                ),
              ),
            ],
          ),
          if (current)
            Row(
              children: [
                _Fine(_clock(position)),
                Expanded(
                  child: Slider(
                    activeColor: consoleGold,
                    value: length > 0 ? (position / length).clamp(0.0, 1.0) : 0,
                    onChanged: length > 0
                        ? (v) => setState(() => _audio.seek(v * length))
                        : null,
                  ),
                ),
                _Fine(_clock(length)),
              ],
            ),
          _Fine(track.source),
          _noteBox(track.ref, track.source),
        ],
      ),
    );
  }

  // ROOMS -------------------------------------------------------------------

  Widget _roomsTab(ConsoleCatalog catalog) => _list(catalog, [
    for (final level in catalog.levels)
      _Card(
        title: level.title,
        ref: '${level.id} / room',
        source: '${level.file} › background, layers, stage.floor',
        children: [
          _RoomView(
            key: ValueKey('room:${level.id}'),
            level: level,
            art: _art,
            bpm: catalog.tracksFor(level.id)
                    .where((t) => t.name == 'mid')
                    .firstOrNull
                    ?.bpm ??
                100,
          ),
          _Fine('plate ${level.backgroundAsset}'),
          _noteBox('${level.id} / room', level.backgroundAsset),
          for (final layer in level.layers)
            _Sub(
              title: layer.id,
              ref: layer.ref,
              lines: [
                '${layer.kind} · ${layer.motion} every ${layer.periodBeats} beats · ${layer.frames} frames',
                'at ${layer.left},${layer.top} size ${layer.width}×${layer.height} · ${layer.atlasAsset} y ${layer.atlasY}',
                layer.source,
              ],
              note: _noteBox(layer.ref, layer.source),
            ),
        ],
      ),
  ]);

  // CLOSE-UPS ---------------------------------------------------------------

  Widget _closeupsTab(ConsoleCatalog catalog) => FutureBuilder<LevelRegistry?>(
    future: _registry,
    builder: (context, snap) {
      final registry = snap.data;
      final shots = <(ConsoleLevel, ExitShot)>[];
      for (final level in catalog.levels) {
        LevelDefinition? def;
        try {
          def = registry?.byId(level.id);
        } catch (_) {
          def = registry?.reviewLevels[level.id];
        }
        final shot = def?.exitShot;
        if (shot != null) shots.add((level, shot));
      }
      return _list(catalog, [
        if (snap.connectionState == ConnectionState.done && registry == null)
          const _Fine('The levels did not pass the game\'s own check, so the close-ups cannot play here.'),
        for (final (level, shot) in shots)
          _Card(
            title: '${level.title}: the close-up',
            ref: '${level.id} / closeup',
            source: '${level.file} › exitShot',
            children: [
              _CloseupPlayer(
                key: ValueKey('closeup:${level.id}'),
                shot: shot,
                art: _art,
                bpm: catalog.tracksFor(level.id)
                        .where((t) => t.name == 'success')
                        .firstOrNull
                        ?.bpm ??
                    100,
              ),
              _noteBox('${level.id} / closeup', '${level.file} › exitShot'),
            ],
          ),
        _Card(
          title: 'Close-up drawings',
          ref: 'closeup / art',
          source: ConsoleCatalog.closeupsFolder,
          children: [
            for (final image in catalog.closeupArt)
              _Sub(
                title: image.asset.split('/').last,
                ref: image.ref,
                lines: [image.asset, ...image.usedBy],
                picture: SizedBox(
                  height: 120,
                  child: Image.asset(
                    image.asset,
                    bundle: widget.bundle,
                    filterQuality: FilterQuality.none,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const _Fine('could not load'),
                  ),
                ),
                note: _noteBox(image.ref, image.asset),
              ),
          ],
        ),
      ]);
    },
  );

  // NOTES -------------------------------------------------------------------

  Widget _notesTab() => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      Wrap(
        spacing: 8,
        children: [
          _RetroButton(label: 'COPY ALL NOTES', onPressed: _copyNotes),
          _RetroButton(
            label: 'CLEAR',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Clear every note?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Keep them'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(_notes.clear);
                      Navigator.pop(context);
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      const _Fine(
        'Notes stay in this browser only. Copy them and paste them to us; '
        'each one carries the reference of the thing it is about.',
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        color: consolePanel,
        child: SelectableText(
          _notes.count == 0 ? 'No notes yet.' : _notes.asText(),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
    ],
  );
}

String _clock(double seconds) {
  if (!seconds.isFinite) return '--:--';
  final s = seconds.round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

// MOVES ---------------------------------------------------------------------

class _MovesTab extends StatefulWidget {
  const _MovesTab({required this.catalog, required this.art, required this.note});
  final ConsoleCatalog catalog;
  final ArtCache art;
  final Widget Function(String ref, String source) note;

  @override
  State<_MovesTab> createState() => _MovesTabState();
}

class _MovesTabState extends State<_MovesTab> {
  String? _role;
  late double _bpm = widget.catalog.tempos.isEmpty
      ? 100
      : widget.catalog.tempos[widget.catalog.tempos.length ~/ 2];

  @override
  Widget build(BuildContext context) {
    final roles = {for (final a in widget.catalog.atlases) a.role}.toList();
    final shown = widget.catalog.atlases
        .where((a) => _role == null || a.role == _role)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 48),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('everyone'),
              selected: _role == null,
              onSelected: (_) => setState(() => _role = null),
            ),
            for (final role in roles)
              ChoiceChip(
                label: Text(role),
                selected: _role == role,
                onSelected: (_) => setState(() => _role = role),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const _Fine('tempo'),
            for (final bpm in {...widget.catalog.tempos, 100.0}.toList()..sort())
              ChoiceChip(
                label: Text(bpm.toStringAsFixed(0)),
                selected: _bpm == bpm,
                onSelected: (_) => setState(() => _bpm = bpm),
              ),
          ],
        ),
        const _Fine(
          'Clips play at their beats from the data, at the tempo chosen here. '
          '"assumed" means no data times it yet: one beat a drawing.',
        ),
        for (final atlas in shown)
          _AtlasCard(
            key: ValueKey('atlas:${atlas.id}'),
            atlas: atlas,
            art: widget.art,
            bpm: _bpm,
            note: widget.note,
          ),
      ],
    );
  }
}

class _AtlasCard extends StatefulWidget {
  const _AtlasCard({
    super.key,
    required this.atlas,
    required this.art,
    required this.bpm,
    required this.note,
  });
  final ConsoleAtlas atlas;
  final ArtCache art;
  final double bpm;
  final Widget Function(String ref, String source) note;

  @override
  State<_AtlasCard> createState() => _AtlasCardState();
}

class _AtlasCardState extends State<_AtlasCard> {
  bool _open = false;
  ConsoleClip? _clip;

  @override
  Widget build(BuildContext context) {
    final atlas = widget.atlas;
    final clip = _clip ?? atlas.clips.firstOrNull;
    final reference = atlas.referenceFrame ?? atlas.frames.keys.firstOrNull;
    return _Card(
      title: '${atlas.id}  ·  ${atlas.role}',
      ref: atlas.ref,
      source: '${atlas.source} · ${atlas.image}',
      leading: reference == null
          ? null
          : SizedBox(
              width: 44,
              height: 56,
              child: SpriteStill(
                cache: widget.art,
                atlas: atlas,
                frame: reference,
                shadow: false,
              ),
            ),
      onTapTitle: () => setState(() => _open = !_open),
      children: [
        _Fine('${atlas.frames.length} drawings · ${atlas.clips.length} clips'),
        if (_open) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in atlas.clips)
                ChoiceChip(
                  label: Text(c.level == null ? c.name : '${c.level}: ${c.name}'),
                  selected: c == clip,
                  onSelected: (_) => setState(() => _clip = c),
                ),
            ],
          ),
          if (clip != null) ...[
            const SizedBox(height: 8),
            _ClipPlayer(
              key: ValueKey('clip:${clip.ref}'),
              atlas: atlas,
              clip: clip,
              art: widget.art,
              bpm: widget.bpm,
            ),
            _RefChip(clip.ref),
            _Fine(clip.source),
            _Fine(
              '${clip.frames.length} frames · ${clip.lengthBeats.toStringAsFixed(2)} beats'
              '${clip.timing == ClipTiming.assumed ? ' · timing assumed' : ''}',
            ),
            widget.note(clip.ref, clip.source),
          ],
        ] else
          TextButton(
            onPressed: () => setState(() => _open = true),
            child: const Text('SHOW CLIPS', style: TextStyle(color: consoleGold)),
          ),
        widget.note(atlas.ref, atlas.source),
      ],
    );
  }
}

class _ClipPlayer extends StatefulWidget {
  const _ClipPlayer({
    super.key,
    required this.atlas,
    required this.clip,
    required this.art,
    required this.bpm,
  });
  final ConsoleAtlas atlas;
  final ConsoleClip clip;
  final ArtCache art;
  final double bpm;

  @override
  State<_ClipPlayer> createState() => _ClipPlayerState();
}

class _ClipPlayerState extends State<_ClipPlayer> with ConsolePlayback {
  int? _held;
  bool _flip = false;

  @override
  void initState() {
    super.initState();
    startPlayback();
  }

  double get _beat => playSeconds * widget.bpm / 60;

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    final index = _held ?? clip.indexAt(_beat);
    final id = clip.frames[index];
    final frame = widget.atlas.frames[id];
    final fit = SpritePainter.fitFor([
      for (final f in clip.frames)
        if (widget.atlas.frames[f] != null) widget.atlas.frames[f]!,
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 220,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF243F55), Color(0xFF3A2A40)],
            ),
            border: Border.all(color: const Color(0x55FFC35F)),
          ),
          child: frame == null
              ? Center(child: Text('missing drawing $id'))
              : ArtLoader(
                  cache: widget.art,
                  assets: [widget.atlas.image],
                  builder: (context, images) => CustomPaint(
                    painter: SpritePainter(
                      image: images.single,
                      frame: frame,
                      fit: fit,
                      flip: _flip,
                    ),
                  ),
                ),
        ),
        Row(
          children: [
            IconButton(
              tooltip: 'previous drawing',
              icon: const Icon(Icons.skip_previous),
              onPressed: () => setState(() {
                stopPlayback();
                _held = (index - 1) % clip.frames.length;
              }),
            ),
            IconButton(
              tooltip: playing ? 'hold' : 'play',
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              onPressed: () => setState(() {
                if (playing) {
                  _held = index;
                  stopPlayback();
                } else {
                  _held = null;
                  startPlayback();
                }
              }),
            ),
            IconButton(
              tooltip: 'next drawing',
              icon: const Icon(Icons.skip_next),
              onPressed: () => setState(() {
                stopPlayback();
                _held = (index + 1) % clip.frames.length;
              }),
            ),
            IconButton(
              tooltip: 'mirror',
              icon: const Icon(Icons.flip),
              onPressed: () => setState(() => _flip = !_flip),
            ),
            Expanded(
              child: Text(
                'frame ${index + 1}/${clip.frames.length} · $id'
                ' · ${clip.beats[index]} b',
                key: const Key('clip-frame'),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: consoleMint,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ROOM VIEW -----------------------------------------------------------------

class _RoomView extends StatefulWidget {
  const _RoomView({super.key, required this.level, required this.art, required this.bpm});
  final ConsoleLevel level;
  final ArtCache art;
  final double bpm;

  @override
  State<_RoomView> createState() => _RoomViewState();
}

class _RoomViewState extends State<_RoomView> with ConsolePlayback {
  bool _layers = true;
  bool _boxes = false;
  bool _floor = false;
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final level = widget.level;
    final assets = [
      level.backgroundAsset,
      for (final a in {for (final l in level.layers) l.atlasAsset}) a,
    ];
    final beat = playSeconds * widget.bpm / 60;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            FilterChip(
              label: Text(playing ? 'animating at ${widget.bpm.toStringAsFixed(0)} BPM' : 'animate'),
              selected: playing,
              onSelected: (on) {
                setState(() => _shown = true);
                on ? startPlayback() : stopPlayback();
              },
            ),
            FilterChip(
              label: const Text('layers'),
              selected: _layers,
              onSelected: (on) => setState(() => _layers = on),
            ),
            FilterChip(
              label: const Text('layer boxes'),
              selected: _boxes,
              onSelected: (on) => setState(() => _boxes = on),
            ),
            FilterChip(
              label: const Text('floor overlay'),
              selected: _floor,
              onSelected: (on) => setState(() => _floor = on),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!_shown)
          TextButton(
            onPressed: () => setState(() => _shown = true),
            child: const Text('SHOW ROOM', style: TextStyle(color: consoleGold)),
          )
        else
          AspectRatio(
            aspectRatio: level.plateSize == null
                ? 2 / 3
                : level.plateSize!.width / level.plateSize!.height,
            child: ArtLoader(
              cache: widget.art,
              assets: assets,
              builder: (context, images) => CustomPaint(
                painter: _RoomPainter(
                  level: level,
                  plate: images.first,
                  atlases: {
                    for (final (i, a) in assets.indexed)
                      if (i > 0) a: images[i],
                  },
                  beat: beat,
                  layers: _layers,
                  boxes: _boxes,
                  floor: _floor,
                ),
              ),
            ),
          ),
        if (_shown && playing)
          _Fine('beat ${beat.toStringAsFixed(1)} · layers at full swing'),
      ],
    );
  }
}

class _RoomPainter extends CustomPainter {
  _RoomPainter({
    required this.level,
    required this.plate,
    required this.atlases,
    required this.beat,
    required this.layers,
    required this.boxes,
    required this.floor,
  });
  final ConsoleLevel level;
  final ui.Image plate;
  final Map<String, ui.Image> atlases;
  final double beat;
  final bool layers, boxes, floor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.none;
    canvas.drawImageRect(
      plate,
      Rect.fromLTWH(0, 0, plate.width.toDouble(), plate.height.toDouble()),
      Offset.zero & size,
      paint,
    );
    final plateW = (level.plateSize?.width ?? plate.width).toDouble();
    final plateH = (level.plateSize?.height ?? plate.height).toDouble();
    final sx = size.width / plateW, sy = size.height / plateH;
    for (final layer in level.layers) {
      final dest = Rect.fromLTWH(
        layer.left * sx,
        layer.top * sy,
        layer.width * sx,
        layer.height * sy,
      );
      final atlas = atlases[layer.atlasAsset];
      if (layers && atlas != null) {
        // Cover the painted original, as the game's layer does at rest.
        canvas.drawImageRect(
          atlas,
          layer.sourceRect(layer.frameAt(beat)),
          dest,
          paint,
        );
      }
      if (boxes) {
        canvas.drawRect(
          dest,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = consoleMint
            ..strokeWidth = 1,
        );
        _label(canvas, layer.id, dest.topLeft, consoleMint);
      }
    }
    if (floor) {
      final f = level.floor;
      if (f != null) {
        final y = f.horizonY * size.height;
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          Paint()
            ..color = consoleRose
            ..strokeWidth = 1.5,
        );
        _label(canvas, 'horizon ${f.horizonY}', Offset(4, y - 14), consoleRose);
        // A grid of rows that recede to the horizon, one adult tall apart.
        final foot = f.footY * size.height;
        final tall = f.height * size.height;
        final grid = Paint()
          ..color = const Color(0x66FF7A90)
          ..strokeWidth = 1;
        for (var row = -6; row <= 12; row++) {
          final ratio = math.pow(1.25, row).toDouble();
          final ry = y + (foot - y) * ratio;
          if (ry <= y || ry > size.height) continue;
          canvas.drawLine(Offset(0, ry), Offset(size.width, ry), grid);
        }
        final x = size.width * .08;
        canvas.drawLine(
          Offset(x, foot),
          Offset(x, foot - tall),
          Paint()
            ..color = consoleGold
            ..strokeWidth = 3,
        );
        _label(canvas, 'one adult', Offset(x + 4, foot - tall), consoleGold);
      }
      for (final mark in level.marks) {
        final at = Offset(mark.at.dx * size.width, mark.at.dy * size.height);
        final color = mark.name.startsWith('guest') ? consoleMint : consoleGold;
        canvas.drawCircle(at, 3, Paint()..color = color);
        if (!mark.name.startsWith('guest')) _label(canvas, mark.name, at, color);
      }
    }
  }

  void _label(Canvas canvas, String text, Offset at, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          backgroundColor: const Color(0xAA000000),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_RoomPainter old) => true;
}

// CLOSE-UP ------------------------------------------------------------------

class _CloseupPlayer extends StatefulWidget {
  const _CloseupPlayer({super.key, required this.shot, required this.art, required this.bpm});
  final ExitShot shot;
  final ArtCache art;
  final double bpm;

  @override
  State<_CloseupPlayer> createState() => _CloseupPlayerState();
}

class _CloseupPlayerState extends State<_CloseupPlayer> with ConsolePlayback {
  bool _shown = false;

  double get _beat {
    final shot = widget.shot;
    final span = shot.closeupTo - shot.closeupFrom;
    final along = (playSeconds * widget.bpm / 60) % (span <= 0 ? 1 : span);
    return shot.closeupFrom + along;
  }

  @override
  Widget build(BuildContext context) {
    final shot = widget.shot;
    if (!_shown) {
      return TextButton(
        onPressed: () => setState(() {
          _shown = true;
          startPlayback();
        }),
        child: const Text('PLAY CLOSE-UP', style: TextStyle(color: consoleGold)),
      );
    }
    final beat = _beat;
    final placements = shot.sample(beat, reducedMotion: false);
    final assets = [
      'assets/art/${shot.plate}',
      for (final image in shot.images.skip(1).toSet()) 'assets/art/$image',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 9 / 16,
          child: ArtLoader(
            cache: widget.art,
            assets: assets,
            builder: (context, images) => CustomPaint(
              painter: _CloseupPainter(
                shot: shot,
                beat: beat,
                images: {for (final (i, a) in assets.indexed) a: images[i]},
              ),
            ),
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              onPressed: () => setState(() => playing ? stopPlayback() : startPlayback()),
            ),
            Expanded(
              child: Text(
                'beat ${beat.toStringAsFixed(2)} of ${shot.closeupFrom}–${shot.closeupTo}'
                ' · contact ${shot.contactBeat} · ${widget.bpm.toStringAsFixed(0)} BPM\n'
                '${placements.map((p) => p.image.split('/').last).join(' + ')}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: consoleMint),
              ),
            ),
          ],
        ),
        const _Fine(
          'The game\'s ExitShot.sample at the success tempo, in a 180-wide view. '
          'A duet that wins on the mirrored side plays mirrored in the game.',
        ),
      ],
    );
  }
}

class _CloseupPainter extends CustomPainter {
  _CloseupPainter({required this.shot, required this.beat, required this.images});
  final ExitShot shot;
  final double beat;
  final Map<String, ui.Image> images;

  @override
  void paint(Canvas canvas, Size size) {
    // The game's own drawing, `GardenSceneGame._drawCloseup`, in a 180-wide view.
    const width = 180.0;
    final bounds = Rect.fromLTWH(0, 0, width, width * size.height / size.width);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / width);
    final paint = Paint()..filterQuality = FilterQuality.none;
    final plate = images['assets/art/${shot.plate}'];
    if (plate != null) {
      final cover = math.max(bounds.width / plate.width, bounds.height / plate.height);
      canvas.drawImageRect(
        plate,
        Rect.fromLTWH(0, 0, plate.width.toDouble(), plate.height.toDouble()),
        Rect.fromCenter(
          center: bounds.center,
          width: plate.width * cover,
          height: plate.height * cover,
        ),
        paint,
      );
    }
    canvas.drawRect(bounds, Paint()..color = const Color(0x8C050A10));
    final meet = Offset(
      bounds.width * shot.contactPoint.dx,
      bounds.height * shot.contactPoint.dy,
    );
    for (final place in shot.sample(beat, reducedMotion: false)) {
      final art = images['assets/art/${place.image}'];
      if (art == null) continue;
      final origin = meet + place.offset - place.actor.contact * place.actor.scale;
      canvas.drawImageRect(
        art,
        Rect.fromLTWH(0, 0, art.width.toDouble(), art.height.toDouble()),
        origin & Size(art.width * place.actor.scale, art.height * place.actor.scale),
        paint,
      );
    }
    for (final mote in shot.motes(beat, reducedMotion: false)) {
      canvas.drawRect(
        Rect.fromCenter(center: meet + mote.offset, width: mote.size, height: mote.size),
        Paint()..color = const Color(0xFFF4E3B2).withValues(alpha: mote.opacity),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CloseupPainter old) => old.beat != beat;
}

// PIECES --------------------------------------------------------------------

class _RetroTitle extends StatelessWidget {
  const _RetroTitle(this.top, this.bottom);
  final String top, bottom;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        top,
        style: const TextStyle(
          fontSize: 12,
          letterSpacing: 3,
          fontWeight: FontWeight.w900,
          color: consoleMint,
        ),
      ),
      Text(
        bottom,
        style: const TextStyle(
          fontSize: 22,
          letterSpacing: 4,
          fontWeight: FontWeight.w900,
          color: consoleGold,
          shadows: [Shadow(color: Colors.black, offset: Offset(3, 3))],
        ),
      ),
    ],
  );
}

class _RetroButton extends StatelessWidget {
  const _RetroButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.small = false,
    this.tooltip,
  });
  final String label;
  final VoidCallback onPressed;
  final bool small;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: consoleGold,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: small ? 8 : 12,
            vertical: small ? 6 : 9,
          ),
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(color: Color(0xFF8A5A10), width: 3),
              bottom: BorderSide(color: Color(0xFF8A5A10), width: 3),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: consoleInk,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              fontSize: small ? 11 : 13,
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _Card extends StatelessWidget {
  const _Card({
    super.key,
    required this.title,
    required this.ref,
    required this.children,
    this.source,
    this.leading,
    this.onTapTitle,
  });
  final String title, ref;
  final String? source;
  final List<Widget> children;
  final Widget? leading;
  final VoidCallback? onTapTitle;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: const BoxDecoration(
      color: consolePanel,
      border: Border(
        top: BorderSide(color: Color(0x55FFC35F)),
        left: BorderSide(color: Color(0x55FFC35F)),
        right: BorderSide(color: Colors.black, width: 3),
        bottom: BorderSide(color: Colors.black, width: 3),
      ),
    ),
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onTapTitle,
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 10)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: consoleCream,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _RefChip(ref),
                    if (source != null) _Fine(source!),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ...children,
      ],
    ),
  );
}

class _Sub extends StatelessWidget {
  const _Sub({
    required this.title,
    required this.ref,
    required this.lines,
    required this.note,
    this.picture,
  });
  final String title, ref;
  final List<String> lines;
  final Widget note;
  final Widget? picture;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(8),
    color: const Color(0x22000000),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        _RefChip(ref),
        ?picture,
        for (final line in lines) _Fine(line),
        note,
      ],
    ),
  );
}

class _RefChip extends StatelessWidget {
  const _RefChip(this.ref);
  final String ref;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: InkWell(
      onTap: () => Clipboard.setData(ClipboardData(text: ref)),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        color: const Color(0xFF0B161E),
        child: Text(
          ref,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: consoleMint,
          ),
        ),
      ),
    ),
  );
}

class _Fine extends StatelessWidget {
  const _Fine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text(text, style: const TextStyle(fontSize: 11, color: consoleDim)),
  );
}

class _Facts extends StatelessWidget {
  const _Facts(this.facts);
  final Map<String, String> facts;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final e in facts.entries)
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${e.key}  ',
                style: const TextStyle(color: consoleDim, fontSize: 12),
              ),
              TextSpan(text: e.value, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
    ],
  );
}

class _NoteBox extends StatefulWidget {
  const _NoteBox({
    super.key,
    required this.ref,
    required this.source,
    required this.notes,
    required this.onChanged,
  });
  final String ref, source;
  final ConsoleNotes notes;
  final VoidCallback onChanged;

  @override
  State<_NoteBox> createState() => _NoteBoxState();
}

class _NoteBoxState extends State<_NoteBox> {
  late final _text = TextEditingController(text: widget.notes.noteFor(widget.ref));
  late bool _open = _text.text.isNotEmpty;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: Key('add-note:${widget.ref}'),
          onPressed: () => setState(() => _open = true),
          icon: const Icon(Icons.edit_note, size: 18, color: consoleDim),
          label: const Text('note', style: TextStyle(color: consoleDim)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextField(
        key: Key('note:${widget.ref}'),
        controller: _text,
        minLines: 1,
        maxLines: 6,
        style: const TextStyle(fontSize: 13, color: consoleCream),
        decoration: InputDecoration(
          isDense: true,
          labelText: 'note on ${widget.ref}',
          labelStyle: const TextStyle(color: consoleDim, fontSize: 12),
          filled: true,
          fillColor: const Color(0xFF0B161E),
          border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
        ),
        onChanged: (value) {
          widget.notes.set(widget.ref, value, source: widget.source);
          widget.onChanged();
        },
      ),
    );
  }
}
