import 'dart:ui' as ui;

import 'crowd_interest.dart';
import 'rhythm.dart';

const heroFrameIds = [
  'rear_idle',
  'rear_walk_left',
  'rear_walk_right',
  'rear_turn',
  'front_idle',
  'groove_left',
  'groove_right',
  'anticipate',
  'left_hand',
  'right_hand',
  'left_foot',
  'right_foot',
  'spin_front',
  'profile',
  'spin_rear',
  'rear_finish',
];
const guestPoseIds = [
  'occupied',
  'notice',
  'step_left',
  'step_right',
  'clap',
  'cheer',
];

/// Rectangles and anchors are measured from reviewed art, never inferred from
/// an AI-generated contact sheet's nominal row or column count.
class PartySpriteFrame {
  const PartySpriteFrame(
    this.source,
    this.anchor,
    this.pixelsPerUnit, {
    this.hold,
  });
  final ui.Rect source;
  final ui.Offset anchor;
  final double pixelsPerUnit;

  /// Where this drawing's holding hand is, in the same pixels as [anchor]. Only
  /// the drawings that hold a partner's hand have one.
  final ui.Offset? hold;

  /// The holding hand on screen, for a drawing placed at [ground].
  ui.Offset? holdAt(ui.Offset ground, double scale, {bool flipX = false}) {
    final at = hold;
    if (at == null) return null;
    final factor = scale / pixelsPerUnit;
    final across = (at.dx - anchor.dx) * factor;
    return ground.translate(flipX ? -across : across, (at.dy - anchor.dy) * factor);
  }

  ui.Rect destination(ui.Offset ground, double scale) {
    final factor = scale / pixelsPerUnit;
    return ui.Rect.fromLTWH(
      ground.dx - anchor.dx * factor,
      ground.dy - anchor.dy * factor,
      source.width * factor,
      source.height * factor,
    );
  }
}

class PartyAtlasDefinition {
  PartyAtlasDefinition._(this.image, this.width, this.height, this.frames);
  final String image;
  final int width;
  final int height;
  final Map<String, PartySpriteFrame> frames;

  factory PartyAtlasDefinition.fromJson(Map<String, dynamic> data) {
    final image = data['image'];
    final width = data['imageWidth'];
    final height = data['imageHeight'];
    final rawFrames = data['frames'];
    if (image is! String ||
        image.isEmpty ||
        image.contains('..') ||
        image.contains('/') ||
        width is! int ||
        height is! int ||
        width <= 0 ||
        height <= 0 ||
        rawFrames is! Map ||
        rawFrames.isEmpty) {
      throw const FormatException('Invalid party sprite atlas header');
    }
    final frames = <String, PartySpriteFrame>{};
    for (final entry in rawFrames.entries) {
      final id = entry.key;
      final frame = entry.value;
      if (id is! String || frame is! Map) {
        throw const FormatException('Invalid party sprite frame');
      }
      final rect = frame['rect'];
      final anchor = frame['anchor'];
      final units = frame['pixelsPerUnit'];
      bool numbers(dynamic values, int length) =>
          values is List &&
          values.length == length &&
          values.every((value) => value is num && value.isFinite);
      if (!numbers(rect, 4) ||
          !numbers(anchor, 2) ||
          units is! num ||
          !units.isFinite ||
          units <= 0) {
        throw FormatException('Invalid geometry for party sprite $id');
      }
      final source = ui.Rect.fromLTWH(
        (rect[0] as num).toDouble(),
        (rect[1] as num).toDouble(),
        (rect[2] as num).toDouble(),
        (rect[3] as num).toDouble(),
      );
      final pivot = ui.Offset(
        (anchor[0] as num).toDouble(),
        (anchor[1] as num).toDouble(),
      );
      if (source.left < 0 ||
          source.top < 0 ||
          source.width <= 0 ||
          source.height <= 0 ||
          source.right > width ||
          source.bottom > height ||
          rect.any((value) => value != (value as num).roundToDouble()) ||
          pivot.dx < 0 ||
          pivot.dy < 0 ||
          pivot.dx > source.width ||
          pivot.dy > source.height) {
        throw FormatException('Party sprite $id extends beyond its image');
      }
      final hold = frame['hold'];
      if (hold != null && !numbers(hold, 2)) {
        throw FormatException('Invalid hold for party sprite $id');
      }
      frames[id] = PartySpriteFrame(
        source,
        pivot,
        units.toDouble(),
        hold: hold == null
            ? null
            : ui.Offset((hold[0] as num).toDouble(), (hold[1] as num).toDouble()),
      );
    }
    return PartyAtlasDefinition._(
      image,
      width,
      height,
      Map.unmodifiable(frames),
    );
  }

  void requireFrames(Iterable<String> ids) {
    for (final id in ids) {
      if (!frames.containsKey(id)) {
        throw FormatException('Party atlas $image is missing frame $id');
      }
    }
  }
}

class PartySpriteManifest {
  PartySpriteManifest._(this.hero, this.crowd);
  final PartyAtlasDefinition hero;
  final PartyAtlasDefinition crowd;

  factory PartySpriteManifest.fromJson(Map<String, dynamic> data) {
    final atlases = data['atlases'];
    if (data['version'] != 1 ||
        atlases is! Map ||
        atlases['hero'] is! Map ||
        atlases['crowd'] is! Map) {
      throw const FormatException('Unsupported party sprite manifest');
    }
    final hero = PartyAtlasDefinition.fromJson(
      Map<String, dynamic>.from(atlases['hero'] as Map),
    )..requireFrames(heroFrameIds);
    final crowd =
        PartyAtlasDefinition.fromJson(
          Map<String, dynamic>.from(atlases['crowd'] as Map),
        )..requireFrames([
          for (var i = 0; i < 3; i++)
            for (final pose in guestPoseIds) 'guest${i}_$pose',
        ]);
    return PartySpriteManifest._(hero, crowd);
  }
}

class PartySpriteAtlas {
  PartySpriteAtlas(this.definition, this.image) {
    if (image.width != definition.width || image.height != definition.height) {
      throw FormatException('Party atlas ${definition.image} size mismatch');
    }
  }
  final PartyAtlasDefinition definition;
  final ui.Image image;
  final _paint = ui.Paint()..filterQuality = ui.FilterQuality.none;

  void draw(
    ui.Canvas canvas,
    String frameId,
    ui.Offset ground,
    double scale, {
    bool flipX = false,
    ui.FilterQuality filter = ui.FilterQuality.none,
  }) {
    final frame = definition.frames[frameId];
    if (frame == null) throw StateError('Missing party sprite $frameId');
    _paint.filterQuality = filter;
    canvas.save();
    canvas.translate(ground.dx.roundToDouble(), ground.dy.roundToDouble());
    if (flipX) canvas.scale(-1, 1);
    canvas.drawImageRect(
      image,
      frame.source,
      frame.destination(ui.Offset.zero, scale),
      _paint,
    );
    canvas.restore();
  }
}

String _cycle(List<String> frames, double beat, double beatsPerFrame) =>
    frames[(beat / beatsPerFrame).floor() % frames.length];

/// Musical frame selection has no timer, score or transport side effects.
String heroSpriteFrame({
  required double beat,
  required double phaseBeat,
  required bool front,
  required bool walking,
  required bool reducedMotion,
  required double actionAge,
  required Limb? action,
  required double flourishAge,
  bool sideOn = false,
  bool stumbling = false,
}) {
  final flourish = flourishAge >= 0 && flourishAge < 1;
  final hit = action != null && actionAge >= 0 && actionAge < .65;
  if (hit && (!flourish || actionAge < flourishAge)) {
    if (actionAge < .28 || reducedMotion) {
      return switch (action) {
        Limb.leftHand => 'left_hand',
        Limb.rightHand => 'right_hand',
        Limb.leftFoot => 'left_foot',
        Limb.rightFoot => 'right_foot',
      };
    }
    return actionAge < .43 ? 'anticipate' : 'front_idle';
  }
  if (flourish) {
    if (reducedMotion) return 'spin_front';
    return _cycle(
      [
        'spin_front',
        'profile',
        'spin_rear',
        'rear_finish',
        'spin_rear',
        'profile',
        'spin_front',
        'front_idle',
      ],
      flourishAge,
      .125,
    );
  }
  if (stumbling) return 'anticipate';
  if (walking) {
    if (sideOn) return 'profile';
    return reducedMotion
        ? 'rear_idle'
        : _cycle(
            ['rear_walk_left', 'rear_idle', 'rear_walk_right', 'rear_idle'],
            beat,
            .25,
          );
  }
  if (!front) return 'rear_idle';
  if (phaseBeat < .5 && !reducedMotion && (action == null || actionAge > 1)) {
    return phaseBeat < .25 ? 'rear_turn' : 'profile';
  }
  return reducedMotion
      ? 'front_idle'
      : _cycle(
          ['front_idle', 'groove_left', 'anticipate', 'groove_right'],
          beat,
          .25,
        );
}

String guestSpriteFrame({
  required int archetype,
  required CrowdGuestState state,
  required double beat,
  required double styleEnergy,
  required bool settled,
  required bool escorting,
  required bool reducedMotion,
}) {
  String pose;
  if (escorting || (!settled && styleEnergy > .2)) {
    pose = reducedMotion ? 'clap' : _cycle(['clap', 'cheer'], beat, .5);
  } else if (settled || state == CrowdGuestState.occupied) {
    pose = 'occupied';
  } else {
    final frames = switch (state) {
      CrowdGuestState.curious => ['occupied', 'notice'],
      CrowdGuestState.following => [
        'notice',
        'step_left',
        'notice',
        'step_right',
      ],
      CrowdGuestState.participating => [
        'step_left',
        'clap',
        'step_right',
        'notice',
      ],
      CrowdGuestState.celebrating => ['clap', 'cheer', 'step_right', 'cheer'],
      CrowdGuestState.occupied => ['occupied'],
    };
    pose = reducedMotion
        ? frames.first
        : _cycle(frames, beat, state == CrowdGuestState.curious ? 2 : .5);
  }
  return 'guest${archetype}_$pose';
}
