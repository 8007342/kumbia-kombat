import 'dart:convert';

import 'package:flutter/services.dart';

import '../gameplay/crowd_interest.dart';
import '../gameplay/ensemble_sprites.dart';
import '../gameplay/party_sprites.dart';
import '../review_links.dart';

/// Everything the curation console lists, read from the shipping data files and
/// nothing else, so a new level, take, atlas or clip shows up with no code change.
/// Each item carries a [ref]: a short, stable name the owner can quote in notes
/// ("salon / terciopelo / bow"), and a [source]: the file and JSON path it came
/// from, so whoever reads the note can find the data.
///
/// `openspec/changes/add-curation-console/specs/curation-console/spec.md`.
class ConsoleCatalog {
  ConsoleCatalog({
    required this.levels,
    required this.tracks,
    required this.atlases,
    required this.closeupArt,
    required this.tempos,
    required this.problems,
  });

  /// Campaign order first, then any level file the index doesn't list yet.
  final List<ConsoleLevel> levels;
  final List<ConsoleTrack> tracks;
  final List<ConsoleAtlas> atlases;

  /// Close-up drawings in `assets/art/closeups/`, and the json that places them.
  final List<ConsoleImage> closeupArt;

  /// Every BPM a rendered take plays at, for timing clips; sorted, no repeats.
  final List<double> tempos;

  /// What could not be read. Shown on the page rather than failing it, so one
  /// bad file in progress still leaves the rest of the console to curate.
  final List<String> problems;

  static const levelsFolder = 'levels';
  static const ensembleManifest = 'assets/art/ensemble/manifest.json';
  static const partyManifest = 'assets/art/party/manifest.json';
  static const choreography = 'assets/art/ensemble/choreography.json';
  static const musicManifest = 'assets/music/rendered/manifest.json';
  static const closeupsFolder = 'assets/art/closeups';

  Iterable<ConsoleClip> get clips => atlases.expand((a) => a.clips);
  Iterable<ConsoleLayer> get layers => levels.expand((l) => l.layers);

  ConsoleLevel? level(String id) =>
      levels.where((l) => l.id == id).firstOrNull;
  ConsoleAtlas? atlas(String id) =>
      atlases.where((a) => a.id == id).firstOrNull;
  Iterable<ConsoleTrack> tracksFor(String level) =>
      tracks.where((t) => t.level == level);

  /// Reads the shipping files from [bundle]. [assetPaths] is the bundle's asset
  /// list; when null it is read from the bundle's own manifest.
  static Future<ConsoleCatalog> load(
    AssetBundle bundle, {
    List<String>? assetPaths,
  }) async {
    final problems = <String>[];
    Future<String?> read(String path) async {
      try {
        return await bundle.loadString(path);
      } catch (error) {
        problems.add('$path: could not be read ($error)');
        return null;
      }
    }

    var assets = assetPaths;
    if (assets == null) {
      try {
        assets = (await AssetManifest.loadFromAssetBundle(bundle)).listAssets();
      } catch (_) {
        assets = const [];
      }
    }
    final indexText = await read('$levelsFolder/index.json');
    final levelIds = <String>{
      ...levelIdsIn(indexText),
      for (final path in assets)
        if (path.startsWith('$levelsFolder/') &&
            path.endsWith('.json') &&
            !path.endsWith('/index.json') &&
            !path.substring(levelsFolder.length + 1).contains('/'))
          path.substring(levelsFolder.length + 1, path.length - 5),
    };
    final levelTexts = <String, String>{};
    for (final id in levelIds) {
      final text = await read('$levelsFolder/$id.json');
      if (text != null) levelTexts[id] = text;
    }
    final closeupTexts = <String, String>{};
    for (final path in assets) {
      if (path.startsWith('$closeupsFolder/') && path.endsWith('.json')) {
        final text = await read(path);
        if (text != null) closeupTexts[path] = text;
      }
    }
    return build(
      indexText: indexText ?? '{}',
      levelTexts: levelTexts,
      ensembleText: await read(ensembleManifest),
      partyText: await read(partyManifest),
      choreographyText: await read(choreography),
      musicText: await read(musicManifest),
      closeupTexts: closeupTexts,
      assetPaths: assets,
      problems: problems,
    );
  }

  /// The level ids `levels/index.json` names, campaign then review.
  static List<String> levelIdsIn(String? indexText) {
    if (indexText == null) return const [];
    try {
      final index = jsonDecode(indexText);
      if (index is! Map) return const [];
      return [
        for (final entry in index['campaign'] as List? ?? const [])
          if (entry is Map && entry['level'] is String) entry['level'] as String,
        for (final id in index['review'] as List? ?? const [])
          if (id is String) id,
      ];
    } catch (_) {
      return const [];
    }
  }

  static ConsoleCatalog build({
    required String indexText,
    required Map<String, String> levelTexts,
    String? ensembleText,
    String? partyText,
    String? choreographyText,
    String? musicText,
    Map<String, String> closeupTexts = const {},
    List<String> assetPaths = const [],
    List<String>? problems,
  }) {
    final issues = problems ?? <String>[];
    T? attempt<T>(String what, T Function() body) {
      try {
        return body();
      } catch (error) {
        issues.add('$what: $error');
        return null;
      }
    }

    // Levels, in campaign order.
    final index = attempt('levels/index.json', () => jsonDecode(indexText));
    final campaign = <String, Map>{};
    final review = <String>{};
    if (index is Map) {
      for (final entry in index['campaign'] as List? ?? const []) {
        if (entry is Map && entry['level'] is String) {
          campaign[entry['level'] as String] = entry;
        }
      }
      review.addAll((index['review'] as List? ?? const []).whereType<String>());
    }
    final rawLevels = <String, Map<String, dynamic>>{};
    for (final entry in levelTexts.entries) {
      final data = attempt('levels/${entry.key}.json', () => jsonDecode(entry.value));
      if (data is Map<String, dynamic>) rawLevels[entry.key] = data;
    }
    final order = [
      ...campaign.keys.where(rawLevels.containsKey),
      ...review.where((id) => rawLevels.containsKey(id) && !campaign.containsKey(id)),
      ...(rawLevels.keys
              .where((id) => !campaign.containsKey(id) && !review.contains(id))
              .toList()
            ..sort()),
    ];
    final levels = <ConsoleLevel>[];
    for (final id in order) {
      final level = attempt(
        'levels/$id.json',
        () => ConsoleLevel._fromJson(
          id,
          rawLevels[id]!,
          number: campaign.containsKey(id)
              ? campaign.keys.toList().indexOf(id) + 1
              : null,
          bridgeToNext: campaign[id]?['bridgeToNext'] as String?,
          inReview: review.contains(id),
        ),
      );
      if (level != null) levels.add(level);
    }

    // Music: every object in the manifest that has files is something to play.
    final tracks = <ConsoleTrack>[];
    final music = musicText == null
        ? null
        : attempt(musicManifest, () => jsonDecode(musicText));
    if (music is Map && music['levels'] is Map) {
      for (final entry in (music['levels'] as Map).entries) {
        final level = entry.key as String;
        if (entry.value is! Map) continue;
        final found = <ConsoleTrack>[];
        _walk(entry.value, const [], (path, node) {
          if (node['files'] is! Map) return false;
          found.add(
            ConsoleTrack._fromJson(
              level,
              path,
              node,
              musicalKey: (entry.value as Map)['key'] as String?,
            ),
          );
          return true;
        });
        found.sort((a, b) => a.sortKey.compareTo(b.sortKey));
        tracks.addAll(found);
      }
    }
    final tempos = {
      for (final track in tracks)
        if (track.bpm != null) track.bpm!,
    }.toList()..sort();

    // Atlases: the ensemble's, then the party's (Mācron and the first crowd).
    final atlases = <ConsoleAtlas>[];
    void readAtlases(String? text, String manifest, String folder, String what) {
      if (text == null) return;
      final data = attempt(manifest, () => jsonDecode(text));
      final raw = data is Map ? data['atlases'] : null;
      if (raw is! Map) return;
      for (final entry in raw.entries) {
        final atlas = attempt(
          '$manifest › atlases.${entry.key}',
          () => ConsoleAtlas._fromJson(
            entry.key as String,
            Map<String, dynamic>.from(entry.value as Map),
            manifest: manifest,
            folder: folder,
            what: what,
          ),
        );
        if (atlas != null) atlases.add(atlas);
      }
    }

    readAtlases(ensembleText, ensembleManifest, 'assets/art/ensemble', 'ensemble');
    readAtlases(partyText, partyManifest, 'assets/art/party', 'party');

    // Clips, from wherever data names a run of drawings.
    final choreo = choreographyText == null
        ? null
        : attempt(choreography, () => jsonDecode(choreographyText));
    if (choreo is Map) {
      final shared = choreo['clips'] is Map ? choreo['clips'] as Map : const {};
      final dancers = choreo['dancers'] is Map ? choreo['dancers'] as Map : const {};
      for (final dancerEntry in dancers.entries) {
        final atlas = atlases
            .where((a) => a.id == dancerEntry.key)
            .firstOrNull;
        if (atlas == null) continue;
        final dancer = dancerEntry.value is Map ? dancerEntry.value as Map : const {};
        final aliases = Map<String, String>.from(
          dancer['frames'] is Map ? dancer['frames'] as Map : const {},
        );
        final own = dancer['clips'] is Map ? dancer['clips'] as Map : const {};
        final names = {...shared.keys.cast<String>(), ...own.keys.cast<String>()};
        for (final name in names) {
          final ownClip = own[name];
          final raw = ownClip ?? shared[name];
          if (raw is! Map) continue;
          final clip = ConsoleClip._fromJson(
            atlas: atlas.id,
            name: name,
            data: raw,
            aliases: aliases,
            level: null,
            source: ownClip != null
                ? 'choreography.json › dancers.${atlas.id}.clips.$name'
                : 'choreography.json › clips.$name',
            timing: ClipTiming.data,
          );
          if (clip != null) atlas._add(clip);
        }
      }
    }
    for (final level in order) {
      final data = rawLevels[level];
      if (data == null) continue;
      _walk(data, const [], (path, node) {
        final frames = node['frames'];
        if (frames is! List || frames.isEmpty || frames.any((f) => f is! String)) {
          return false;
        }
        final names = frames.cast<String>();
        // The clip is for whichever atlases have every one of its drawings.
        for (final atlas in atlases) {
          if (!names.every(atlas.frames.containsKey)) continue;
          final clip = ConsoleClip._fromJson(
            atlas: atlas.id,
            name: _clipName(path),
            data: node,
            aliases: const {},
            level: level,
            source: 'levels/$level.json › ${_dotted(path)}',
            timing: node['beatsPerFrame'] != null || node['beats'] != null
                ? ClipTiming.data
                : ClipTiming.assumed,
          );
          if (clip != null) atlas._add(clip);
        }
        return true;
      });
    }
    for (final atlas in atlases) {
      for (final clip in codeClips(atlas)) {
        atlas._add(clip);
      }
      atlas._addGroups();
    }

    // Close-up art: every drawing in the folder, with the json that places it.
    final closeupArt = <ConsoleImage>[];
    final placedBy = <String, List<String>>{};
    for (final entry in closeupTexts.entries) {
      final data = attempt(entry.key, () => jsonDecode(entry.value));
      if (data == null) continue;
      final name = entry.key.split('/').last;
      _walkValues(data, const [], (path, value) {
        if (value is String && value.endsWith('.png')) {
          placedBy.putIfAbsent(value.split('/').last, () => []).add(
            '$name › ${_dotted(path)}',
          );
        }
      });
    }
    for (final level in levels) {
      for (final (path, image) in level.closeupImages) {
        placedBy.putIfAbsent(image.split('/').last, () => []).add(
          'levels/${level.id}.json › $path',
        );
      }
    }
    for (final path in assetPaths) {
      if (path.startsWith('$closeupsFolder/') && path.endsWith('.png')) {
        final file = path.split('/').last;
        closeupArt.add(
          ConsoleImage(
            ref: 'closeup / ${file.substring(0, file.length - 4)}',
            asset: path,
            usedBy: List.unmodifiable(placedBy[file] ?? const []),
          ),
        );
      }
    }
    closeupArt.sort((a, b) => a.asset.compareTo(b.asset));

    return ConsoleCatalog(
      levels: List.unmodifiable(levels),
      tracks: List.unmodifiable(tracks),
      atlases: List.unmodifiable(atlases),
      closeupArt: List.unmodifiable(closeupArt),
      tempos: List.unmodifiable(tempos),
      problems: List.unmodifiable(issues),
    );
  }

  /// Clips that live in code rather than data, sampled from the very functions
  /// the game draws with, so their timing is the game's.
  static List<ConsoleClip> codeClips(ConsoleAtlas atlas) {
    final has = atlas.frames.containsKey;
    final clips = <ConsoleClip>[];
    void add(String name, String source, double beats, String Function(double) at) {
      final clip = ConsoleClip.sampled(
        atlas: atlas.id,
        name: name,
        source: source,
        lengthBeats: beats,
        at: at,
      );
      if (clip.frames.every(has)) clips.add(clip);
    }

    if (atlas.id == 'hero') {
      const source = 'lib/gameplay/party_sprites.dart › heroSpriteFrame';
      String hero({
        double beat = 0,
        double phaseBeat = 1,
        bool front = true,
        bool walking = false,
        double flourishAge = -1,
      }) => heroSpriteFrame(
        beat: beat,
        phaseBeat: phaseBeat,
        front: front,
        walking: walking,
        reducedMotion: false,
        actionAge: 99,
        action: null,
        flourishAge: flourishAge,
      );
      add('groove', '$source (front, between notes)', 1, (b) => hero(beat: b));
      add('walk', '$source (walking)', 1, (b) => hero(beat: b, walking: true));
      add('turn_to_front', '$source (phase start)', .5, (b) => hero(phaseBeat: b));
      add('spin_flourish', '$source (flourish)', 1, (b) => hero(flourishAge: b));
    }
    if (ensembleGuestFrameIds.every(has)) {
      const source = 'lib/gameplay/ensemble_sprites.dart › ensembleClipFrame';
      for (final clip in CrowdClip.values) {
        add(
          'crowd.${clip.name}',
          '$source (${clip.name}, 2-beat pass)',
          2,
          (b) => ensembleClipFrame(clip, beat: b, duration: 2),
        );
      }
    }
    return clips;
  }

  static String _dotted(List<Object> path) {
    final out = StringBuffer();
    for (final part in path) {
      if (part is int) {
        out.write('[$part]');
      } else {
        if (out.isNotEmpty) out.write('.');
        out.write(part);
      }
    }
    return out.toString();
  }

  /// The last two names on a JSON path: `occupied.pair`, `ladders.instrument[1]`.
  static String _clipName(List<Object> path) {
    final named = <String>[];
    for (final part in path) {
      if (part is int) {
        if (named.isNotEmpty) named[named.length - 1] = '${named.last}[$part]';
      } else {
        named.add(part as String);
      }
    }
    return named.skip(named.length < 2 ? 0 : named.length - 2).join('.');
  }

  /// Visits every map under [node]; [visit] returns true to stop descending.
  static void _walk(
    Object? node,
    List<Object> path,
    bool Function(List<Object> path, Map node) visit,
  ) {
    if (node is Map) {
      if (path.isNotEmpty && visit(path, node)) return;
      for (final entry in node.entries) {
        _walk(entry.value, [...path, entry.key as Object], visit);
      }
    } else if (node is List) {
      for (final (i, item) in node.indexed) {
        _walk(item, [...path, i], visit);
      }
    }
  }

  static void _walkValues(
    Object? node,
    List<Object> path,
    void Function(List<Object> path, Object? value) visit,
  ) {
    if (node is Map) {
      for (final entry in node.entries) {
        _walkValues(entry.value, [...path, entry.key as Object], visit);
      }
    } else if (node is List) {
      for (final (i, item) in node.indexed) {
        _walkValues(item, [...path, i], visit);
      }
    } else {
      visit(path, node);
    }
  }
}

class ConsoleLevel {
  ConsoleLevel._({
    required this.id,
    required this.title,
    required this.number,
    required this.bridgeToNext,
    required this.inReview,
    required this.background,
    required this.score,
    required this.successScore,
    required this.opponents,
    required this.layers,
    required this.plateSize,
    required this.floor,
    required this.marks,
    required this.closeupImages,
    required this.hasExitShot,
  });

  final String id;
  final String title;

  /// Place in the campaign, 1-based; null for a level not in the campaign yet.
  final int? number;
  final String? bridgeToNext;
  final bool inReview;

  /// Under `assets/art/`.
  final String background;
  final String? score, successScore;

  /// `id (atlas)` for each challenger.
  final List<({String id, String atlas})> opponents;
  final List<ConsoleLayer> layers;

  /// The plate size layers are measured in, when the level says.
  final ({int width, int height})? plateSize;

  /// `stage.floor`: horizon, and the reference height at a reference foot line,
  /// as fractions of the plate's height.
  final ({double horizonY, double footY, double height})? floor;

  /// Named spots on the plate, as fractions: Mācron's marks, challengers, guests.
  final List<({String name, Offset at})> marks;

  /// JSON path and image of every close-up drawing the exit shot names.
  final List<(String, String)> closeupImages;
  final bool hasExitShot;

  String get ref => 'level / $id';
  String get file => 'levels/$id.json';
  String get backgroundAsset => 'assets/art/$background';
  String get playLink => ReviewLinks.play(level: id);

  factory ConsoleLevel._fromJson(
    String id,
    Map<String, dynamic> data, {
    required int? number,
    required String? bridgeToNext,
    required bool inReview,
  }) {
    final music = data['music'] is Map ? data['music'] as Map : const {};
    final stage = data['stage'] is Map ? data['stage'] as Map : const {};
    final opponents = [
      for (final c in stage['challengers'] as List? ?? const [])
        if (c is Map)
          (id: '${c['id'] ?? c['atlas']}', atlas: '${c['atlas'] ?? c['id']}'),
    ];
    final rawLayers = data['layers'] is Map ? data['layers'] as Map : const {};
    final layers = <ConsoleLayer>[];
    for (final (i, p) in (rawLayers['props'] as List? ?? const []).indexed) {
      if (p is! Map) continue;
      layers.add(ConsoleLayer._fromJson(id, i, p));
    }
    final plate = rawLayers['plateWidth'] is num && rawLayers['plateHeight'] is num
        ? (
            width: (rawLayers['plateWidth'] as num).toInt(),
            height: (rawLayers['plateHeight'] as num).toInt(),
          )
        : null;
    final f = stage['floor'];
    final floor = f is Map &&
            f['horizonY'] is num &&
            f['referenceFootY'] is num &&
            f['referenceHeight'] is num
        ? (
            horizonY: (f['horizonY'] as num).toDouble(),
            footY: (f['referenceFootY'] as num).toDouble(),
            height: (f['referenceHeight'] as num).toDouble(),
          )
        : null;
    final marks = <({String name, Offset at})>[];
    void mark(String name, Object? raw) {
      if (raw is List && raw.length == 2 && raw.every((v) => v is num)) {
        marks.add((
          name: name,
          at: Offset((raw[0] as num).toDouble(), (raw[1] as num).toDouble()),
        ));
      }
    }

    for (final key in stage.keys) {
      if ('$key'.startsWith('hero')) mark('$key', stage[key]);
    }
    for (final c in stage['challengers'] as List? ?? const []) {
      if (c is! Map) continue;
      for (final key in ['mark', 'yieldMark', 'meetMark']) {
        mark('${c['id']}.$key', c[key]);
      }
    }
    final crowd = data['crowd'] is Map ? data['crowd'] as Map : const {};
    for (final (i, g) in (crowd['guests'] as List? ?? const []).indexed) {
      mark('guest[$i]', g is Map ? g['at'] : g);
    }
    final images = <(String, String)>[];
    final shot = data['exitShot'];
    if (shot is Map) {
      ConsoleCatalog._walkValues(shot, const ['exitShot'], (path, value) {
        if (value is String && value.endsWith('.png')) {
          images.add((ConsoleCatalog._dotted(path), value));
        }
      });
    }
    return ConsoleLevel._(
      id: id,
      title: '${data['title'] ?? id}',
      number: number,
      bridgeToNext: bridgeToNext,
      inReview: inReview,
      background: '${data['background'] ?? ''}',
      score: music['score'] as String?,
      successScore: music['successScore'] as String?,
      opponents: List.unmodifiable(opponents),
      layers: List.unmodifiable(layers),
      plateSize: plate,
      floor: floor,
      marks: List.unmodifiable(marks),
      closeupImages: List.unmodifiable(images),
      hasExitShot: shot is Map,
    );
  }
}

/// A prop cut from a room's plate: its frames sit side by side in [atlas].
class ConsoleLayer {
  ConsoleLayer._({
    required this.level,
    required this.index,
    required this.id,
    required this.atlas,
    required this.atlasY,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.frames,
    required this.motion,
    required this.periodBeats,
    required this.kind,
  });

  final String level, id, atlas, motion, kind;
  final int index, atlasY, left, top, width, height, frames;
  final double periodBeats;

  String get ref => '$level / layer / $id';
  String get source => 'levels/$level.json › layers.props[$index]';
  String get atlasAsset => 'assets/art/$atlas';

  /// Same gutter as `RoomLayerProp`.
  Rect sourceRect(int frame) => Rect.fromLTWH(
    (frame * (width + 2)).toDouble(),
    atlasY.toDouble(),
    width.toDouble(),
    height.toDouble(),
  );

  /// The drawing at [beat] at full swing, as the room moves at its liveliest.
  int frameAt(double beat) {
    if (frames <= 1) return 0;
    final u = (beat / periodBeats) % 1.0;
    final last = frames - 1;
    if (motion == 'pulse') {
      final rise = u < .5 ? u * 2 : 2 - u * 2;
      return (rise * last).round();
    }
    // Sway: rest in the middle, out to each side once a period.
    final rest = frames ~/ 2;
    final s = u < .25
        ? u * 4
        : u < .75
        ? 2 - u * 4
        : u * 4 - 4;
    return (rest + rest * s).round().clamp(0, last);
  }

  factory ConsoleLayer._fromJson(String level, int index, Map p) {
    int whole(String key) => (p[key] as num?)?.toInt() ?? 0;
    return ConsoleLayer._(
      level: level,
      index: index,
      id: '${p['id'] ?? 'layer$index'}',
      atlas: '${p['atlas'] ?? ''}',
      atlasY: whole('atlasY'),
      left: whole('left'),
      top: whole('top'),
      width: whole('width'),
      height: whole('height'),
      frames: whole('frames').clamp(1, 64),
      motion: '${p['motion'] ?? 'sway'}',
      periodBeats: (p['periodBeats'] as num?)?.toDouble() ?? 4,
      kind: '${p['kind'] ?? ''}',
    );
  }
}

/// One rendered piece of music: a tier take, a success phrase, a bridge.
class ConsoleTrack {
  ConsoleTrack._({
    required this.level,
    required this.key,
    required this.bpm,
    required this.seconds,
    required this.bars,
    required this.files,
    required this.lufs,
    required this.musicalKey,
  });

  final String level;

  /// The JSON path under the level: `takes.low`, `success`, `bridge`.
  final String key;
  final double? bpm;
  final double? seconds;
  final int? bars;

  /// `opus` and `aac` asset paths.
  final Map<String, String> files;
  final double? lufs;
  final String? musicalKey;

  String get name => key.startsWith('takes.') ? key.substring(6) : key;
  String get ref => 'music / $level / $name';
  String get source => 'assets/music/rendered/manifest.json › levels.$level.$key';

  int get sortKey {
    const order = ['low', 'mid', 'high', 'success', 'successShort', 'bridge'];
    final at = order.indexOf(name);
    return at < 0 ? order.length : at;
  }

  factory ConsoleTrack._fromJson(
    String level,
    List<Object> path,
    Map node, {
    String? musicalKey,
  }) {
    double? number(String key) => (node[key] as num?)?.toDouble();
    final bpm = number('bpm');
    final bars = (node['bars'] as num?)?.toInt();
    final perBar = number('beatsPerBar') ?? 4;
    final loopStart = number('loopStartSeconds') ?? number('startSeconds');
    final loopEnd = number('loopEndSeconds') ?? number('endSeconds');
    final seconds = loopStart != null && loopEnd != null
        ? loopEnd - loopStart
        : bpm != null && bars != null
        ? bars * perBar * 60 / bpm
        : null;
    return ConsoleTrack._(
      level: level,
      key: ConsoleCatalog._dotted(path),
      bpm: bpm,
      seconds: seconds,
      bars: bars,
      files: {
        for (final e in (node['files'] as Map).entries)
          if (e.value is String) '${e.key}': e.value as String,
      },
      lufs: number('lufs'),
      musicalKey: musicalKey,
    );
  }
}

class ConsoleFrame {
  const ConsoleFrame(this.id, this.rect, this.anchor, this.mirror);
  final String id;
  final Rect rect;

  /// From the rect's top left: where the feet are.
  final Offset anchor;
  final bool mirror;
}

class ConsoleAtlas {
  ConsoleAtlas._({
    required this.id,
    required this.image,
    required this.manifest,
    required this.what,
    required this.frames,
    required this.referenceFrame,
    required this.size,
  });

  final String id;

  /// Asset path of the atlas picture.
  final String image;
  final String manifest;

  /// `ensemble` or `party`.
  final String what;
  final Map<String, ConsoleFrame> frames;
  final String? referenceFrame;
  final ({int width, int height})? size;
  final List<ConsoleClip> _clips = [];
  List<ConsoleClip> get clips => List.unmodifiable(_clips);

  String get ref => 'atlas / $id';
  String get source => '$manifest › atlases.$id';

  /// What sort of figure this is, for grouping on the page.
  String get role {
    if (id == 'hero') return 'Mācron';
    if (id.startsWith('band-')) return 'band';
    if (id.startsWith('guest') || id == 'crowd') return 'guests';
    if (id.startsWith('pool-bg')) return 'background players';
    if (id == 'life' || id == 'furniture') return 'props';
    return 'opponents';
  }

  void _add(ConsoleClip clip) {
    if (_clips.any((c) => c.name == clip.name && c.level == clip.level)) return;
    _clips.add(clip);
  }

  /// Drawings named `<move>_a`, `_b`… with no clip in data: shown as a run at
  /// one beat each, marked as assumed timing, so nothing drawn is hidden.
  void _addGroups() {
    final covered = {for (final c in _clips) ...c.frames};
    final groups = <String, List<String>>{};
    final letter = RegExp(r'^(.+)_([a-h])$');
    for (final id in frames.keys) {
      final match = letter.firstMatch(id);
      if (match == null) continue;
      groups.putIfAbsent(match.group(1)!, () => []).add(id);
    }
    for (final entry in groups.entries) {
      if (entry.value.length < 2 || entry.value.every(covered.contains)) {
        continue;
      }
      final frames = entry.value..sort();
      _add(
        ConsoleClip(
          atlas: id,
          name: '${entry.key}_*',
          frames: List.unmodifiable(frames),
          beats: List.unmodifiable([for (final _ in frames) 1.0]),
          level: null,
          source: '$manifest › atlases.$id.frames (${entry.key}_a…)',
          timing: ClipTiming.assumed,
        ),
      );
    }
    _add(
      ConsoleClip(
        atlas: id,
        name: 'all_frames',
        frames: List.unmodifiable(frames.keys),
        beats: List.unmodifiable([for (final _ in frames.keys) 1.0]),
        level: null,
        source: '$manifest › atlases.$id.frames',
        timing: ClipTiming.assumed,
      ),
    );
  }

  factory ConsoleAtlas._fromJson(
    String id,
    Map<String, dynamic> data, {
    required String manifest,
    required String folder,
    required String what,
  }) {
    final frames = <String, ConsoleFrame>{};
    for (final entry in (data['frames'] as Map).entries) {
      final f = entry.value as Map;
      final r = (f['rect'] as List).cast<num>();
      final a = (f['anchor'] as List).cast<num>();
      frames[entry.key as String] = ConsoleFrame(
        entry.key as String,
        Rect.fromLTWH(
          r[0].toDouble(),
          r[1].toDouble(),
          r[2].toDouble(),
          r[3].toDouble(),
        ),
        Offset(a[0].toDouble(), a[1].toDouble()),
        f['mirror'] == true,
      );
    }
    return ConsoleAtlas._(
      id: id,
      image: '$folder/${data['image']}',
      manifest: manifest,
      what: what,
      frames: Map.unmodifiable(frames),
      referenceFrame: data['referenceFrame'] as String?,
      size: data['imageWidth'] is num && data['imageHeight'] is num
          ? (
              width: (data['imageWidth'] as num).toInt(),
              height: (data['imageHeight'] as num).toInt(),
            )
          : null,
    );
  }
}

/// Where a clip's timing comes from: the data the game reads, or a console guess
/// (one beat a drawing) for drawings no clip names yet.
enum ClipTiming { data, assumed }

class ConsoleClip {
  ConsoleClip({
    required this.atlas,
    required this.name,
    required this.frames,
    required this.beats,
    required this.level,
    required this.source,
    required this.timing,
    this.phase = 0,
  });

  final String atlas, name, source;

  /// The level whose data names this clip; null for the shared ones.
  final String? level;
  final List<String> frames;
  final List<double> beats;
  final double phase;
  final ClipTiming timing;

  late final double lengthBeats = beats.fold(0.0, (a, b) => a + b);

  /// `salon / terciopelo / bow`, or `gatekeeper / groove_basic`.
  String get ref => [?level, atlas, name].join(' / ');

  /// Frame index at [beat], looping, the way `DanceClip.loop` counts.
  int indexAt(double beat) {
    if (frames.isEmpty || lengthBeats <= 0) return 0;
    var remaining = (beat + phase) % lengthBeats;
    for (var i = 0; i < frames.length; i++) {
      remaining -= beats[i];
      if (remaining < 0) return i;
    }
    return frames.length - 1;
  }

  /// A run of drawings read off a function of the beat, in 1/16-beat steps.
  factory ConsoleClip.sampled({
    required String atlas,
    required String name,
    required String source,
    required double lengthBeats,
    required String Function(double beat) at,
  }) {
    const step = 1 / 16;
    final frames = <String>[];
    final beats = <double>[];
    final steps = (lengthBeats / step).round();
    for (var i = 0; i < steps; i++) {
      final frame = at(i * step);
      if (frames.isNotEmpty && frames.last == frame) {
        beats[beats.length - 1] += step;
      } else {
        frames.add(frame);
        beats.add(step);
      }
    }
    return ConsoleClip(
      atlas: atlas,
      name: name,
      frames: List.unmodifiable(frames),
      beats: List.unmodifiable(beats),
      level: null,
      source: source,
      timing: ClipTiming.data,
    );
  }

  static ConsoleClip? _fromJson({
    required String atlas,
    required String name,
    required Map data,
    required Map<String, String> aliases,
    required String? level,
    required String source,
    required ClipTiming timing,
  }) {
    final raw = data['frames'];
    if (raw is! List || raw.isEmpty || raw.any((f) => f is! String)) return null;
    final frames = [for (final f in raw.cast<String>()) aliases[f] ?? f];
    final each = (data['beatsPerFrame'] as num?)?.toDouble() ?? 1;
    final list = data['beats'];
    final beats = list is List && list.length == frames.length
        ? [for (final b in list) (b as num).toDouble()]
        : [for (final _ in frames) each];
    if (beats.any((b) => !b.isFinite || b <= 0)) return null;
    return ConsoleClip(
      atlas: atlas,
      name: name,
      frames: List.unmodifiable(frames),
      beats: List.unmodifiable(beats),
      level: level,
      source: source,
      timing: timing,
      phase: (data['phase'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ConsoleImage {
  const ConsoleImage({required this.ref, required this.asset, this.usedBy = const []});
  final String ref;
  final String asset;

  /// Which json places it: `nod-art.json › blinblin.drawings.rest`.
  final List<String> usedBy;
}
