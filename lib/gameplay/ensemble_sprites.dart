import 'dart:math' as math;
import 'dart:ui' as ui;

import 'challenger_choreography.dart';
import 'crowd_interest.dart';
import 'outfit_palette.dart';
import 'party_sprites.dart';

const ensembleGuestFrameIds = [
  'seated_idle_a',
  'seated_idle_b',
  'notice_a',
  'notice_b',
  'seated_follow_a',
  'seated_follow_b',
  'stand_up_a',
  'stand_up_b',
  'stand_up_c',
  'stand_up_d',
  'standing_idle_a',
  'standing_idle_b',
  'step_touch_a',
  'step_touch_b',
  'step_touch_c',
  'step_touch_d',
  'clap_a',
  'clap_b',
  'cheer_a',
  'cheer_b',
  'sit_down_a',
  'sit_down_b',
  'sit_down_c',
  'sit_down_d',
];
const ensembleLifeFrameIds = [
  'umbrella_a',
  'umbrella_b',
  'umbrella_c',
  'umbrella_d',
  'plant_a',
  'plant_b',
  'plant_c',
  'plant_d',
  'candle_a',
  'candle_b',
  'candle_c',
  'candle_d',
  'waiter_a',
  'waiter_b',
  'waiter_c',
  'waiter_d',
];
const ensembleFurnitureFrameIds = [
  'chair_right',
  'chair_left',
  'table',
  'umbrella_closed',
];

class EnsembleAtlasDefinition {
  EnsembleAtlasDefinition._(this.art, this.mirroredFrames, this.playerHeightPx);
  final PartyAtlasDefinition art;
  final Set<String> mirroredFrames;

  /// How tall the person stands, in atlas pixels, when a frame's box says otherwise:
  /// a bass or a raised bell reaches above the player's head.
  final double? playerHeightPx;

  factory EnsembleAtlasDefinition.fromJson(Map<String, dynamic> data) {
    final art = PartyAtlasDefinition.fromJson(data);
    final mirrors = <String>{};
    for (final entry in (data['frames'] as Map).entries) {
      final mirror = (entry.value as Map)['mirror'];
      if (mirror != null && mirror is! bool) {
        throw FormatException('Invalid frame mirror for ${entry.key}');
      }
      if (mirror == true) mirrors.add(entry.key as String);
    }
    final player = data['playerHeightPx'];
    if (player != null && (player is! num || player <= 0)) {
      throw const FormatException('Invalid playerHeightPx');
    }
    return EnsembleAtlasDefinition._(
      art,
      Set.unmodifiable(mirrors),
      (player as num?)?.toDouble(),
    );
  }

  bool flipFor(String frameId, {bool facingFlip = false}) =>
      facingFlip != mirroredFrames.contains(frameId);

  double nativeHeight(String referenceFrame) {
    final frame = art.frames[referenceFrame];
    if (frame == null) {
      throw StateError('Missing reference pose $referenceFrame');
    }
    return (playerHeightPx ?? frame.source.height) / frame.pixelsPerUnit;
  }
}

class EnsembleManifest {
  EnsembleManifest._(this.atlases);
  final Map<String, EnsembleAtlasDefinition> atlases;
  static const atlasIds = [
    'guest0',
    'guest1',
    'guest2',
    'gatekeeper',
    'bartender',
    'swing-a',
    'swing-b',
    'life',
    'furniture',
  ];

  factory EnsembleManifest.fromJson(Map<String, dynamic> data) {
    final raw = data['atlases'];
    if (data['version'] != 1 || raw is! Map) {
      throw const FormatException('Unsupported ensemble manifest');
    }
    final atlases = <String, EnsembleAtlasDefinition>{};
    for (final id in atlasIds) {
      final entry = raw[id];
      if (entry is! Map) throw FormatException('Missing ensemble atlas $id');
      final definition = EnsembleAtlasDefinition.fromJson(
        Map<String, dynamic>.from(entry),
      );
      definition.art.requireFrames(switch (id) {
        'guest0' || 'guest1' || 'guest2' => ensembleGuestFrameIds,
        'gatekeeper' ||
        'bartender' ||
        'swing-a' ||
        'swing-b' => challengerFrameIds,
        'life' => ensembleLifeFrameIds,
        _ => ensembleFurnitureFrameIds,
      });
      atlases[id] = definition;
    }
    // Art a level names by data, such as a band. It says which drawings it needs.
    for (final entry in raw.entries) {
      if (atlases.containsKey(entry.key)) continue;
      atlases[entry.key as String] = EnsembleAtlasDefinition.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }
    return EnsembleManifest._(Map.unmodifiable(atlases));
  }
}

class EnsembleAtlas {
  EnsembleAtlas(this.definition, ui.Image image)
    : sprite = PartySpriteAtlas(definition.art, image);
  final EnsembleAtlasDefinition definition;
  final PartySpriteAtlas sprite;

  double nativeHeight(String referenceFrame) =>
      definition.nativeHeight(referenceFrame);

  void draw(
    ui.Canvas canvas,
    String frameId,
    ui.Offset ground,
    double scale, {
    bool flipX = false,
    OutfitPalette? outfits,
    OutfitColor? palette,
    ui.FilterQuality filter = ui.FilterQuality.none,
  }) {
    final mirrored = definition.flipFor(frameId, facingFlip: flipX);
    if (outfits == null || palette == null) {
      sprite.draw(
        canvas,
        frameId,
        ground,
        scale,
        flipX: mirrored,
        filter: filter,
      );
      return;
    }
    final frame = definition.art.frames[frameId];
    if (frame == null) throw StateError('Missing ensemble frame $frameId');
    canvas.save();
    canvas.translate(ground.dx, ground.dy);
    if (mirrored) canvas.scale(-1, 1);
    final destination = frame.destination(ui.Offset.zero, scale);
    outfits.draw(
      canvas,
      image: sprite.image,
      source: frame.source,
      destination: destination,
      palette: palette,
    );
    canvas.restore();
  }
}

/// Transition clips clamp to their final key; loops wrap. Never normalize scale
/// by this pose's cropped height: all poses share standing-reference stature.
String ensembleGuestFrame(
  CrowdGuestSnapshot guest, {
  bool reducedMotion = false,
}) => ensembleClipFrame(
  guest.clip,
  beat: guest.clipBeat,
  duration: guest.clipDurationBeats,
  transitioning: guest.transitioning,
  reducedMotion: reducedMotion,
);

/// One clip's drawing at [beat] of a [duration] long pass.
String ensembleClipFrame(
  CrowdClip clip, {
  required double beat,
  required double duration,
  bool transitioning = false,
  bool reducedMotion = false,
}) {
  final (prefix, count) = switch (clip) {
    CrowdClip.seatedIdle => ('seated_idle', 2),
    CrowdClip.notice => ('notice', 2),
    CrowdClip.seatedFollow => ('seated_follow', 2),
    CrowdClip.standUp => ('stand_up', 4),
    CrowdClip.standingIdle => ('standing_idle', 2),
    CrowdClip.stepTouch => ('step_touch', 4),
    CrowdClip.clap => ('clap', 2),
    CrowdClip.cheer => ('cheer', 2),
    CrowdClip.sitDown => ('sit_down', 4),
  };
  if (!beat.isFinite || !duration.isFinite || duration <= 0) {
    throw ArgumentError('Invalid crowd clip timing');
  }
  final progress = transitioning
      ? (beat / duration).clamp(0.0, 1.0)
      : (beat % duration) / duration;
  final frame = reducedMotion && !transitioning
      ? 0
      : (progress * count).floor().clamp(0, count - 1);
  // `step_touch_b` is a pointing arm, and pointing is reserved for flourishes and
  // for turning from uninterested to interested, so a step in time never shows it.
  if (clip == CrowdClip.stepTouch) {
    return 'step_touch_${const ['a', 'd', 'c', 'd'][frame]}';
  }
  return '${prefix}_${const ['a', 'b', 'c', 'd'][frame]}';
}

/// Slow local life uses a foreground-only clock, not musical note timing. Its
/// [range], 0 to 1, is how much of the drawn movement shows: the room starts near
/// still and its drift grows with the music's tier. Only the size changes, so
/// waking never makes a prop jump.
String ensembleAmbientFrame(
  String kind,
  double seconds, {
  int instance = 0,
  bool reducedMotion = false,
  double range = 1,
}) {
  final level = _ambientLevel(kind, seconds, instance) * range;
  if (reducedMotion) return '${kind}_a';
  return '${kind}_${_propLevels[level.round().clamp(0, 3)]}';
}

const _propLevels = ['a', 'b', 'c', 'd'];

/// Where the ambient loop is, as a drawing's number from 0 to 3.
int _ambientLevel(String kind, double seconds, int instance) {
  if (!seconds.isFinite || seconds < 0) throw ArgumentError.value(seconds);
  final period = switch (kind) {
    'umbrella' => 9.4,
    'plant' => 7.6,
    'candle' => 5.8,
    'waiter' => 3.2,
    _ => throw ArgumentError.value(kind),
  };
  final phase = (seconds / period + instance * .371) % 1;
  return const [0, 1, 2, 3, 2, 1][(phase * 6).floor()];
}

double _propBeatPeriod(String kind) => switch (kind) {
  'umbrella' => 4.0,
  'candle' => 1.0,
  _ => 2.0,
};

/// How far this prop's dance has arrived, 0 to 1, for a crowd swing of [swing].
/// Each prop wakes at its own point and its range grows from there.
double partyPropStrength(double swing, int instance) {
  if (swing <= 0) return 0;
  final wake = (instance * .371 % 1) * .35;
  return ((swing - wake) / (1 - wake)).clamp(0.0, 1.0);
}

/// A table's drink, `cup_2` at rest. It only starts to lean with the crowd's
/// swing, on the beat, and picks a drawing, so it can't reach the music or score.
String tableCupFrame({
  required double beat,
  required double swing,
  int instance = 0,
  bool reducedMotion = false,
}) {
  if (reducedMotion || !beat.isFinite || beat < 0) return 'cup_2';
  final strength = partyPropStrength(swing, instance);
  final lean = (2 * strength * math.cos(math.pi * beat)).round();
  return 'cup_${2 + lean}';
}

/// The top of the ladder: props stop drifting on the wall clock and dance on the
/// music beat. [swing] is `CrowdInterestModel.partySwing`, already slow and
/// quintic. It only ever picks frames, so it can't reach the music or the score.
/// Each prop wakes at its own point and its range grows after that, so nothing
/// switches on at full size. Every prop shares the beat's phase, because a left
/// or right prop moving alone could read as a call.
///
/// Under full swing, [range] sizes the ambient drift, and [onBeat], 0 to 1, fades
/// that drift down while a movement in time fades up: the tier's life for flames.
/// Staff, umbrellas and plants pass no [onBeat], so they don't dance until [swing].
String ensemblePartyFrame(
  String kind,
  double seconds, {
  required double beat,
  required double swing,
  int instance = 0,
  bool reducedMotion = false,
  double range = 1,
  double onBeat = 0,
}) {
  final ambient = ensembleAmbientFrame(
    kind,
    seconds,
    instance: instance,
    reducedMotion: reducedMotion,
    range: range,
  );
  if (reducedMotion || !beat.isFinite || beat < 0) return ambient;
  final strength = swing <= 0 ? 0.0 : partyPropStrength(swing, instance);
  final periodBeats = _propBeatPeriod(kind);
  if (strength <= 0) {
    if (onBeat <= 0) return ambient;
    final drift = _ambientLevel(kind, seconds, instance) * range;
    final inTime = 3 * (1 - (2 * ((beat / periodBeats) % 1) - 1).abs());
    final level = drift * (1 - onBeat) + inTime * onBeat;
    return '${kind}_${_propLevels[level.round().clamp(0, 3)]}';
  }
  final frames = strength < .4
      ? const ['a', 'b']
      : strength < .75
      ? const ['a', 'b', 'c', 'b']
      : const ['a', 'b', 'c', 'd', 'c', 'b'];
  final phase = (beat / periodBeats) % 1;
  return '${kind}_${frames[(phase * frames.length).floor()]}';
}

/// The response's existing final rest holds a finish, turns, then watches.
/// Accepted moves and flourishes own the body until their recovery completes.
String? ensembleHeroHandoverFrame({
  required PlayerDanceRole role,
  required double responseProgress,
  bool activeMove = false,
  bool activeFlourish = false,
  bool reducedMotion = false,
}) {
  if (!responseProgress.isFinite ||
      responseProgress < 0 ||
      responseProgress > 1 ||
      activeMove ||
      activeFlourish ||
      role == PlayerDanceRole.celebrating) {
    return null;
  }
  if (reducedMotion) {
    return responseProgress < .5 ? 'front_idle' : 'rear_idle';
  }
  if (responseProgress < .25) {
    return role == PlayerDanceRole.finishing ? 'spin_front' : 'front_idle';
  }
  if (responseProgress < .5) return 'profile';
  if (responseProgress < .75) return 'rear_turn';
  return 'rear_idle';
}

/// Stable ties put a chair behind its occupant at the exact same floor point.
int compareEnsembleDepth(
  ({double floorY, int layer, String id}) a,
  ({double floorY, int layer, String id}) b,
) {
  final depth = a.floorY.compareTo(b.floorY);
  if (depth != 0) return depth;
  final layer = a.layer.compareTo(b.layer);
  return layer != 0 ? layer : a.id.compareTo(b.id);
}
