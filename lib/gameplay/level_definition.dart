import 'dart:ui' as ui;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../music/accent_voice.dart';
import '../music/transport.dart';
import 'band.dart';
import 'crowd_interest.dart';
import 'dance_floor.dart';
import 'dance_line.dart';
import 'garden_session.dart';
import 'gesture_shapes.dart';
import 'party_layout.dart';
import 'party_up.dart';
import 'progression.dart';
import 'rhythm.dart';
import 'duet_staging.dart';
import 'exit_shot.dart';
import 'room_departure.dart';
import 'room_layers.dart';
import 'thumb_layout.dart';

/// A level file or the campaign index is wrong. Thrown while loading, so a bad
/// file stops the game at the door instead of playing as some other room.
class LevelDataError implements Exception {
  const LevelDataError(this.path, this.message);
  final String path;
  final String message;
  @override
  String toString() => 'LevelDataError at $path: $message';
}

const _leadShapes = {'sine', 'square', 'sawtooth', 'triangle'};

/// One JSON object being read. Every key must be consumed, so a misspelt or
/// unsupported field is an error rather than data the game quietly ignores.
class _Fields {
  _Fields(this.path, Object? raw) : _raw = _object(path, raw);
  final String path;
  final Map<String, Object?> _raw;
  final _used = <String>{};

  static Map<String, Object?> _object(String path, Object? raw) {
    if (raw is Map<String, Object?>) return raw;
    throw LevelDataError(path, 'expected an object, found $raw');
  }

  String at(String key) => '$path.$key';

  Object? _take(String key) {
    _used.add(key);
    if (!_raw.containsKey(key)) throw LevelDataError(at(key), 'is required');
    return _raw[key];
  }

  bool has(String key) => _raw.containsKey(key);

  /// For an object whose keys are names the level chooses.
  Iterable<String> get keys => _raw.keys;

  String text(String key) {
    final value = _take(key);
    if (value is String && value.trim().isNotEmpty) return value;
    throw LevelDataError(at(key), 'expected text, found $value');
  }

  double number(String key, {double? min, double? max}) =>
      _number(at(key), _take(key), min: min, max: max);

  int whole(String key, {required int min}) {
    final value = _take(key);
    if (value is int && value >= min) return value;
    throw LevelDataError(at(key), 'expected a whole number >= $min: $value');
  }

  PartyPoint point(String key) => _point(at(key), _take(key));

  /// A move from somewhere, so either way: [dx, dy] in -1..1.
  PartyPoint offset(String key) => _point(at(key), _take(key), min: -1);

  bool flag(String key) {
    final value = _take(key);
    if (value is bool) return value;
    throw LevelDataError(at(key), 'expected true or false, found $value');
  }

  List<Object?> list(String key, {bool optional = false}) {
    if (optional && !has(key)) return const [];
    final value = _take(key);
    if (value is List<Object?>) return value;
    throw LevelDataError(at(key), 'expected a list, found $value');
  }

  _Fields child(String key) => _Fields(at(key), _take(key));

  T named<T extends Enum>(String key, List<T> values) =>
      _named(at(key), _take(key), values);

  /// Call last: anything not read by now is a field the game does not support.
  void finish() {
    final unknown = _raw.keys.where((key) => !_used.contains(key)).toList();
    if (unknown.isNotEmpty) {
      throw LevelDataError(path, 'unknown fields: ${unknown.join(', ')}');
    }
  }
}

double _number(String path, Object? value, {double? min, double? max}) {
  if (value is! num || !value.isFinite) {
    throw LevelDataError(path, 'expected a number, found $value');
  }
  final number = value.toDouble();
  if ((min != null && number < min) || (max != null && number > max)) {
    throw LevelDataError(path, '$number is outside ${min ?? ''}..${max ?? ''}');
  }
  return number;
}

PartyPoint _point(String path, Object? value, {double min = 0}) {
  if (value is! List<Object?> || value.length != 2) {
    throw LevelDataError(path, 'expected [x, y], found $value');
  }
  return PartyPoint(
    _number('$path[0]', value[0], min: min, max: 1),
    _number('$path[1]', value[1], min: min, max: 1),
  );
}

T _named<T extends Enum>(String path, Object? value, List<T> values) {
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  throw LevelDataError(
    path,
    'unknown value $value; expected one of '
    '${values.map((candidate) => candidate.name).join(', ')}',
  );
}

class LevelMusic {
  const LevelMusic({
    required this.score,
    required this.successScore,
    required this.leadShape,
    this.moveAccent,
  });

  /// A sound over the music when a move or a richer step lands: a room's reward.
  /// It reads nothing back, so it can't change timing or judging.
  final ExitShotCue? moveAccent;
  final String score;
  final String successScore;
  final String leadShape;
}

/// A dancer's path over the floor, repeating every [beats]. Size follows it
/// through the floor plane, so a move toward the viewer just grows.
class FloorTrack {
  const FloorTrack(this.beats, this.points);
  final double beats;
  final List<(double, PartyPoint)> points;

  PartyPoint at(double beat) {
    final t = beat % beats;
    for (var i = 0; i < points.length; i++) {
      final (from, a) = points[i];
      final (to, b) = i + 1 < points.length
          ? points[i + 1]
          : (beats, points.first.$2);
      if (t < to) {
        final u = ((t - from) / (to - from)).clamp(0.0, 1.0);
        final eased = u * u * (3 - 2 * u);
        return PartyPoint(a.x + (b.x - a.x) * eased, a.y + (b.y - a.y) * eased);
      }
    }
    return points.first.$2;
  }
}

/// One dancer's marks. A level may name several, and the scene draws them all.
class LevelChallenger {
  const LevelChallenger({
    required this.id,
    required this.atlas,
    required this.mark,
    required this.yieldMark,
    this.track,
    this.stature = 1,
    this.meetMark,
    this.facingAway,
    this.defeatStance,
    this.line,
  });
  final FloorTrack? track;

  /// Dancers who dance as one with this one, a little late. Null for most.
  final DanceLine? line;

  /// Dancing with their back to the room until the first call, if they do.
  final FacingAway? facingAway;

  /// Taken once as the win's shot begins, and then held: the drawings play in
  /// order from the shot's walk and stop on the last. Reduced motion shows the last.
  final FloorClip? defeatStance;

  /// Where this dancer steps in to meet the hero when the level is won. Her
  /// [yieldMark] is off the floor, too far for the shot's walk to reach.
  final PartyPoint? meetMark;

  /// Height against an adult guest, so a pair can differ in size.
  final double stature;
  final String id;

  /// Key in the ensemble manifest, which still lists a fixed set of atlases.
  final String atlas;
  final PartyPoint mark;

  /// Where this dancer stands once fully out of the hero's way.
  final PartyPoint yieldMark;

  /// [beat] drives the track when there is one; yielding always wins over it.
  PartyPoint floorAt(double floorYield, {double beat = 0}) {
    final from = track?.at(beat) ?? mark;
    return PartyPoint(
      from.x + (yieldMark.x - from.x) * floorYield,
      from.y + (yieldMark.y - from.y) * floorYield,
    );
  }
}

/// A dancer who starts with their back to the room, then turns to face it just
/// as the first call starts. Reads the music's beat, and only picks a drawing.
class FacingAway {
  const FacingAway({
    required this.back,
    required this.turn,
    required this.turnBeats,
  });
  final FloorClip back;

  /// The turn, in order, ending just before they face front.
  final List<String> turn;
  final double turnBeats;

  Iterable<String> get frames => [...back.frames, ...turn];

  /// Their drawing during the intro, or null once they've turned around.
  /// Reduced motion keeps their back to the room, then cuts to the front.
  String? frameAt(double beat, double introBeats, {bool reducedMotion = false}) {
    if (beat >= introBeats) return null;
    final into = beat - (introBeats - turnBeats);
    if (into < 0 || reducedMotion) {
      return back.at(beat, reducedMotion: reducedMotion);
    }
    return turn[(into / turnBeats * turn.length).floor().clamp(
      0,
      turn.length - 1,
    )];
  }
}

class LevelStage {
  const LevelStage({
    required this.heroHome,
    required this.heroEntrance,
    required this.heroRetreat,
    required this.challengers,
    PartyPoint? heroWatch,
    PartyPoint? heroAside,
    this.duet,
    this.heroEntersAt = 0,
  }) : heroWatch = heroWatch ?? heroHome,
       heroAside = heroAside ?? heroWatch ?? heroHome;
  final PartyPoint heroHome;

  /// The beat he starts walking in, so a room can be seen without him first.
  final double heroEntersAt;

  /// Where the hero starts walking in from during the intro.
  final PartyPoint heroEntrance;

  /// How far a stumble back to the entrance takes the hero, at its peak.
  final PartyPoint heroRetreat;

  /// The back mark: the hero's first step when the opponent's call starts.
  final PartyPoint heroWatch;

  /// Off the dance floor, where he keeps time through the opponent's call. He gets
  /// here from [heroWatch], and comes home the same way.
  final PartyPoint heroAside;
  final List<LevelChallenger> challengers;

  /// A pair's floor pattern, turn by turn. Null for a lone challenger.
  final LevelDuet? duet;

  /// A place along the hero's route off the floor, [along] as [HeroWatch.at]
  /// gives it: 0 home, .5 the back mark, 1 outside.
  PartyPoint heroOffFloor(double along) {
    final u = along.clamp(0.0, 1.0);
    final (from, to, t) = u < .5
        ? (heroHome, heroWatch, u * 2)
        : (heroWatch, heroAside, u * 2 - 1);
    return PartyPoint(from.x + (to.x - from.x) * t, from.y + (to.y - from.y) * t);
  }

  /// Where the hero is [t] beats into a call. Pure, so a floor pattern can read it
  /// to keep clear of him or to meet him: `duet_staging.dart` needs nothing else.
  PartyPoint heroDuringCall(
    double t,
    double callBeats, {
    bool firstCall = false,
    bool reducedMotion = false,
  }) => heroOffFloor(
    HeroWatch.at(
      t,
      callBeats,
      firstCall: firstCall,
      reducedMotion: reducedMotion,
    ),
  );

  /// [entrance] runs 0 to 1 over the intro; [retreat] is 0 at home.
  PartyPoint heroFloor({required double entrance, required double retreat}) {
    double at(double home, double from, double back) =>
        home + (from - home) * (1 - entrance) + (back - home) * retreat;
    return PartyPoint(
      at(heroHome.x, heroEntrance.x, heroRetreat.x),
      at(heroHome.y, heroEntrance.y, heroRetreat.y),
    );
  }
}

class LevelWaiter {
  const LevelWaiter({required this.home, required this.swayX});
  final PartyPoint home;
  final double swayX;
}

/// Soft light moving slowly over walls and windows, on the music's beat. Clipped
/// to [zones], which can't reach the tap band or the quiet area behind the
/// opponent. Never a flash: its brightness only follows the room's waking.
class WallLight {
  const WallLight({required this.zones, required this.periodBeats});
  final List<List<PartyPoint>> zones;
  final double periodBeats;
}

/// Something painted into the plate that people can stand behind, such as a table
/// or a hanging lamp. Anyone whose feet are further away than [frontY] is drawn
/// with [outline] left out, so the painting stays in front of them.
class SceneOccluder {
  const SceneOccluder({required this.outline, required this.frontY});
  final List<PartyPoint> outline;
  final double frontY;
}

class LevelScenery {
  const LevelScenery({
    required this.lamps,
    required this.plants,
    required this.waiter,
    this.platform,
    this.band,
    this.wallLight,
    this.occluders = const [],
  });

  final List<SceneOccluder> occluders;

  /// A raised floor painted into the plate, which nobody may stand in front of
  /// as if it weren't there.
  final RoomPlatform? platform;
  final LevelBand? band;
  final WallLight? wallLight;

  /// Glow centres, measured against the lamps painted on the background.
  final List<PartyPoint> lamps;
  final List<PartyPoint> plants;
  final LevelWaiter? waiter;
}

class LevelCopy {
  const LevelCopy({
    required this.invitation,
    required this.clearedTitle,
  });
  final String invitation;

  /// The level's two big words, one to a line: the only text during a run. An
  /// exit shot shows them at its highlight. A level with no exit shot has no
  /// highlight, so they wait for the end screen if it's the last level.
  final String clearedTitle;
  List<String> get titleWords => clearedTitle.split('\n');
  String get clearedShout => clearedTitle.replaceAll('\n', ' ');
}

/// Everything the game knows about one level, read from `levels/<id>.json`.
class LevelDefinition {
  const LevelDefinition({
    required this.id,
    required this.title,
    required this.background,
    required this.music,
    required this.rules,
    required this.chart,
    required this.crowd,
    required this.layout,
    required this.stage,
    required this.scenery,
    required this.route,
    required this.routeOriginY,
    required this.copy,
    this.exitShot,
    this.layers = const [],
    this.propSet,
    this.hardestCombo,
    this.floorDance,
    this.guestClips = const {},
  });

  /// What this room's standing guests dance, if it has any.
  final FloorDance? floorDance;

  /// `crowd.clipSets`: drawings for each step of the meter, for guests cast with
  /// their own atlas, such as diners and waiters. A guest names one by `clips`.
  final Map<String, GuestClipSet> guestClips;

  final String id;
  final String title;
  final String background;
  final LevelMusic music;
  final FightDefinition rules;
  final FightChart chart;
  final CrowdStageProfile crowd;
  final PartyRoomLayout layout;
  final LevelStage stage;
  final LevelScenery scenery;
  final DepartureRoute route;

  /// The route's y where the hero is at home; the route is applied relative to
  /// this, so an author can write absolute marks by setting it to home's y.
  final double routeOriginY;
  final LevelCopy copy;

  /// The win's celebration and close-up. Levels without one walk straight out.
  final ExitShot? exitShot;

  /// Props cut out of [background], which party up with the room.
  final List<RoomLayerProp> layers;

  /// Which room's furniture, from `assets/art/props/manifest.json`: one set of
  /// drawings, baked to each room's pixel size and light. Null uses the old atlas.
  final String? propSet;

  /// The opponent's hardest combo, for the late bathroom boss. Every level file
  /// names one; nothing plays it yet.
  final HardestCombo? hardestCombo;

  PartyPoint heroExitFloor(DeparturePose pose) =>
      PartyPoint(pose.x, stage.heroHome.y + pose.y - routeOriginY);

  GardenSession newSession(
    MusicTransport transport,
    MusicAudioBackend backend,
  ) => GardenSession(
    transport,
    backend,
    definition: rules,
    chart: chart,
    crowdProfile: crowd,
    guestCount: layout.guests.length,
  );

  factory LevelDefinition.fromJson(Map<String, Object?> json, {String? path}) {
    final fields = _Fields(path ?? 'level', json);
    final id = fields.text('id');
    final title = fields.text('title');
    final background = fields.text('background');

    final musicFields = fields.child('music');
    final leadShape = musicFields.text('leadShape');
    if (!_leadShapes.contains(leadShape)) {
      throw LevelDataError(musicFields.at('leadShape'), 'unknown $leadShape');
    }
    final music = LevelMusic(
      score: musicFields.text('score'),
      successScore: musicFields.text('successScore'),
      leadShape: leadShape,
      moveAccent: musicFields.has('moveAccent')
          ? _moveAccent(musicFields.child('moveAccent'))
          : null,
    );
    musicFields.finish();

    final rulesFields = fields.child('rules');
    final rules = FightDefinition(
      id,
      rulesFields.text('metric'),
      rulesFields.whole('cleanSeconds', min: 1),
      rulesFields.whole('successesPerTier', min: 1),
      rulesFields.whole('finalChallenges', min: 1),
      rulesFields.whole('resetAfterFailures', min: 1),
      earlyHitRatio: rulesFields.number('earlyHitRatio', min: .01, max: 1),
    );
    rulesFields.finish();

    final chart = _chart(fields.child('chart'));

    final stageFields = fields.child('stage');
    final calibration = stageFields.named(
      'calibration',
      PartyCalibration.values,
    );
    final floorFields = stageFields.child('floor');
    final horizonY = floorFields.number('horizonY', min: 0, max: 1);
    final referenceFootY = floorFields.number('referenceFootY', max: 1);
    final referenceHeight = floorFields.number('referenceHeight', min: .001);
    final vanishingX = floorFields.has('vanishingX')
        ? floorFields.number('vanishingX', min: 0, max: 1)
        : .5;
    floorFields.finish();
    if (horizonY >= referenceFootY) {
      throw LevelDataError(
        floorFields.path,
        'horizonY must be above referenceFootY',
      );
    }
    final floor = PartyFloorPlane(
      horizonY: horizonY,
      referenceFootY: referenceFootY,
      referenceHeight: referenceHeight,
      vanishingX: vanishingX,
    );
    // A mark on or above the horizon would throw on every painted frame.
    PartyPoint onFloor(String path, PartyPoint mark) {
      if (mark.y <= horizonY) {
        throw LevelDataError(path, 'y ${mark.y} is above the horizon');
      }
      return mark;
    }

    PartyPoint stageMark(_Fields from, String key) =>
        onFloor(from.at(key), from.point(key));
    final challengers = _challengers(stageFields, stageMark);
    final stage = LevelStage(
      duet: stageFields.has('duet')
          ? _duet(
              stageFields.child('duet'),
              challengers,
              chart.cycleBeats,
              stageMark(stageFields, 'heroHome'),
            )
          : null,
      heroHome: stageMark(stageFields, 'heroHome'),
      heroEntrance: stageMark(stageFields, 'heroEntrance'),
      heroRetreat: stageMark(stageFields, 'heroRetreat'),
      heroWatch: stageFields.has('heroWatch')
          ? stageMark(stageFields, 'heroWatch')
          : null,
      heroAside: stageFields.has('heroAside')
          ? stageMark(stageFields, 'heroAside')
          : null,
      heroEntersAt: stageFields.has('heroEntersAt')
          ? stageFields.number('heroEntersAt', min: 0, max: chart.introBeats)
          : 0,
      challengers: challengers,
    );
    stageFields.finish();

    final crowdFields = fields.child('crowd');
    final crowd = _crowd(id, crowdFields.child('budgets'));
    final guestClips = crowdFields.has('clipSets')
        ? _clipSets(crowdFields.child('clipSets'))
        : const <String, GuestClipSet>{};
    final guestPath = crowdFields.at('guests');
    final seat = crowdFields.has('seat')
        ? crowdFields.named('seat', PartySeat.values)
        : PartySeat.chair;
    final propSet = crowdFields.has('propSet')
        ? crowdFields.text('propSet')
        : null;
    final seats = <PartySeat>[];
    final partTo = <PartyPoint?>[];
    final cast = <FloorGuestCast?>[];
    final anchors = [
      for (final (i, raw) in crowdFields.list('guests').indexed)
        () {
          final path = '$guestPath[$i]';
          // A bare point takes the room's seat; an object may name its own.
          if (raw is List<Object?>) {
            seats.add(seat);
            partTo.add(null);
            cast.add(null);
            return onFloor(path, _point(path, raw));
          }
          final guest = _Fields(path, raw);
          seats.add(
            guest.has('seat') ? guest.named('seat', PartySeat.values) : seat,
          );
          final at = onFloor(guest.at('at'), guest.point('at'));
          partTo.add(
            guest.has('partTo')
                ? onFloor(guest.at('partTo'), guest.point('partTo'))
                : null,
          );
          cast.add(
            FloorGuestCast(
              atlas: guest.has('atlas') ? guest.text('atlas') : null,
              occupied: guest.has('occupied') ? guest.text('occupied') : null,
              facingRight: guest.has('faces')
                  ? guest.text('faces') == 'right'
                  : null,
              partner: guest.has('partner') ? guest.whole('partner', min: 0) : null,
              clips: guest.has('clips') ? guest.text('clips') : null,
            ),
          );
          guest.finish();
          return at;
        }(),
    ];
    if (anchors.isEmpty || anchors.length > CrowdInterestModel.maxGuests) {
      throw LevelDataError(
        guestPath,
        'expected 1 to ${CrowdInterestModel.maxGuests} guests, '
        'found ${anchors.length}',
      );
    }
    // The feet decide it: a body rises away from the band, but furniture or feet
    // inside it would sit right under the thumbs.
    for (final (i, anchor) in anchors.indexed) {
      if (anchor.y >= thumbBandTop) {
        throw LevelDataError('$guestPath[$i]', 'is on the tap band');
      }
    }
    for (final (i, to) in partTo.indexed) {
      if (to != null && to.y >= thumbBandTop) {
        throw LevelDataError('$guestPath[$i]', 'parts onto the tap band');
      }
    }
    final floorDance = crowdFields.has('floorDance')
        ? _floorDance(crowdFields.child('floorDance'), chart.introBeats)
        : null;
    for (final (i, guest) in cast.indexed) {
      final clips = guest?.clips;
      if (clips == null) continue;
      if (!guestClips.containsKey(clips)) {
        throw LevelDataError('$guestPath[$i]', 'no such clip set: $clips');
      }
      if (guest!.atlas == null) {
        throw LevelDataError('$guestPath[$i]', 'clips needs the guest\'s atlas');
      }
      if (partTo[i] != null || guest.occupied != null) {
        throw LevelDataError(
          '$guestPath[$i]',
          'a guest with clips draws only those: no partTo or occupied',
        );
      }
    }
    final dancers = [
      for (final (i, seated) in seats.indexed)
        if (seated == PartySeat.standing && cast[i]?.clips == null) i,
    ];
    if (dancers.isNotEmpty && floorDance == null) {
      throw LevelDataError(guestPath, 'standing guests need crowd.floorDance');
    }
    for (final (i, to) in partTo.indexed) {
      if (to == null) continue;
      if (seats[i] != PartySeat.standing || floorDance?.parting == null) {
        throw LevelDataError(
          '$guestPath[$i]',
          'partTo needs a standing guest and crowd.floorDance.parting',
        );
      }
    }
    for (final (i, guest) in cast.indexed) {
      final partner = guest?.partner;
      final path = '$guestPath[$i]';
      if (guest?.occupied != null && floorDance?.occupied[guest!.occupied] == null) {
        throw LevelDataError(path, 'no such occupied clip: ${guest!.occupied}');
      }
      if (partner == null) continue;
      if (partner >= cast.length || partner == i || cast[partner]?.partner != i) {
        throw LevelDataError(path, 'partner must be a guest naming them back');
      }
      if ((partTo[i] == null) != (partTo[partner] == null)) {
        throw LevelDataError(path, 'partners part together, or not at all');
      }
    }
    final delays = _partDelays(
      anchors,
      partTo,
      stage.challengers.first.mark,
      floorDance?.parting?.stagger ?? 0,
    );
    final guests = seatedGuestSlots(
      id,
      anchors,
      seats: seats,
      partTo: partTo,
      // Partners set off together, when the nearer of the two would.
      partDelays: [
        for (final (i, delay) in delays.indexed)
          cast[i]?.partner == null
              ? delay
              : math.min(delay, delays[cast[i]!.partner!]),
      ],
      cast: cast,
    );
    final propPath = crowdFields.at('props');
    final placed = [
      for (final (i, raw) in crowdFields.list('props').indexed)
        _prop(_Fields('$propPath[$i]', raw), onFloor),
    ];
    for (final (i, prop) in placed.indexed) {
      if (prop.floor.y >= thumbBandTop) {
        throw LevelDataError('$propPath[$i]', '${prop.id} is on the tap band');
      }
    }
    final props = [...chairSlotsFor(guests, seats: seats), ...placed];
    crowdFields.finish();
    final propIds = <String>{};
    for (final prop in props) {
      if (!propIds.add(prop.id)) {
        throw LevelDataError(propPath, 'duplicate prop id ${prop.id}');
      }
    }

    final sceneryFields = fields.child('scenery');
    final platformBuilt = sceneryFields.has('platform')
        ? _platform(sceneryFields.child('platform'), floor)
        : null;
    final lampPath = sceneryFields.at('lamps');
    final plantPath = sceneryFields.at('plants');
    final scenery = LevelScenery(
      lamps: [
        for (final (i, raw) in sceneryFields.list('lamps').indexed)
          _point('$lampPath[$i]', raw),
      ],
      plants: [
        for (final (i, raw) in sceneryFields.list('plants').indexed)
          onFloor('$plantPath[$i]', _point('$plantPath[$i]', raw)),
      ],
      waiter: sceneryFields.has('waiter')
          ? _waiter(sceneryFields.child('waiter'), onFloor)
          : null,
      platform: platformBuilt,
      band: sceneryFields.has('band')
          ? _band(sceneryFields.child('band'), onFloor, platformBuilt)
          : null,
      wallLight: sceneryFields.has('wallLight')
          ? _wallLight(sceneryFields.child('wallLight'))
          : null,
      occluders: [
        for (final (i, raw) in sceneryFields.list('occluders', optional: true).indexed)
          _occluder(_Fields('${sceneryFields.at('occluders')}[$i]', raw)),
      ],
    );
    sceneryFields.finish();
    final platform = scenery.platform;
    if (platform != null) {
      for (final (i, anchor) in anchors.indexed) {
        for (final place in [anchor, ?partTo[i]]) {
          if (platform.covers(place)) {
            throw LevelDataError('$guestPath[$i]', 'is on the platform');
          }
        }
      }
    }

    final departureFields = fields.child('departure');
    final routeOriginY = departureFields.number('originY', min: 0, max: 1);
    final route = _route(departureFields);
    departureFields.finish();
    for (final (i, waypoint) in route.waypoints.indexed) {
      onFloor(
        '${departureFields.path}.waypoints[$i]',
        PartyPoint(
          waypoint.pose.x,
          stage.heroHome.y + waypoint.pose.y - routeOriginY,
        ),
      );
    }

    final copyFields = fields.child('copy');
    final copy = LevelCopy(
      invitation: copyFields.text('invitation'),
      clearedTitle: copyFields.text('clearedTitle'),
    );
    copyFields.finish();
    if (!RegExp(r'^\S+\n\S+$').hasMatch(copy.clearedTitle)) {
      throw LevelDataError(
        copyFields.at('clearedTitle'),
        'expected two words, one to a line: ${copy.clearedTitle}',
      );
    }
    final exitShot = fields.has('exitShot')
        ? _exitShot(fields.child('exitShot'))
        : null;
    final hardestCombo = _hardestCombo(
      fields.child('hardestCombo'),
      [for (final challenger in stage.challengers) challenger.id],
    );
    final layers = fields.has('layers')
        ? _layers(fields.child('layers'))
        : const <RoomLayerProp>[];
    fields.finish();

    return LevelDefinition(
      id: id,
      title: title,
      background: background,
      music: music,
      rules: rules,
      chart: chart,
      crowd: crowd,
      layout: PartyRoomLayout(
        id: id,
        calibration: calibration,
        floor: floor,
        guests: guests,
        props: List.unmodifiable(props),
      ),
      stage: stage,
      scenery: scenery,
      route: route,
      routeOriginY: routeOriginY,
      copy: copy,
      exitShot: exitShot,
      layers: layers,
      propSet: propSet,
      hardestCombo: hardestCombo,
      floorDance: floorDance,
      guestClips: guestClips,
    );
  }

  static FloorClip _floorClip(_Fields fields) {
    final path = fields.at('frames');
    final frames = [
      for (final (i, raw) in fields.list('frames').indexed)
        raw is String && raw.isNotEmpty
            ? raw
            : throw LevelDataError('$path[$i]', 'a drawing name'),
    ];
    if (frames.isEmpty) throw LevelDataError(path, 'needs a drawing');
    final clip = FloorClip(
      List.unmodifiable(frames),
      fields.number('beatsPerFrame', min: .125),
    );
    fields.finish();
    return clip;
  }

  static Map<String, GuestClipSet> _clipSets(_Fields fields) {
    final sets = <String, GuestClipSet>{};
    for (final name in fields.keys.toList()) {
      final set = fields.child(name);
      final reference = set.text('reference');
      final clips = <CrowdClip, GuestClip>{};
      for (final clip in CrowdClip.values) {
        final entry = set.child(clip.name);
        final frames = entry.list('frames');
        if (frames.isEmpty || frames.any((f) => f is! String)) {
          throw LevelDataError(entry.at('frames'), 'expected drawing names');
        }
        final once = entry.has('once') && entry.flag('once');
        clips[clip] = GuestClip(
          List.unmodifiable(frames.cast<String>()),
          once: once,
          beatsPerFrame: once
              ? 1
              : entry.number('beatsPerFrame', min: .25),
        );
        entry.finish();
      }
      GuestClip? applause;
      if (set.has('applause')) {
        final entry = set.child('applause');
        final frames = entry.list('frames');
        if (frames.isEmpty || frames.any((f) => f is! String)) {
          throw LevelDataError(entry.at('frames'), 'expected drawing names');
        }
        applause = GuestClip(
          List.unmodifiable(frames.cast<String>()),
          beatsPerFrame: entry.number('beatsPerFrame', min: .25),
        );
        entry.finish();
      }
      set.finish();
      sets[name] = GuestClipSet(
        reference: reference,
        clips: Map.unmodifiable(clips),
        applause: applause,
      );
    }
    fields.finish();
    return Map.unmodifiable(sets);
  }

  static FloorDance _floorDance(_Fields fields, double introBeats) {
    final ownThing = _floorClip(fields.child('ownThing'));
    final glance = _floorClip(fields.child('glance'));
    final occupied = <String, FloorClip>{};
    if (fields.has('occupied')) {
      final clips = fields.child('occupied');
      for (final name in clips.keys) {
        occupied[name] = _floorClip(clips.child(name));
      }
    }
    final sidestep = fields.has('sidestep')
        ? _floorClip(fields.child('sidestep'))
        : null;
    final following = fields.has('following')
        ? _floorClip(fields.child('following'))
        : null;
    final castGlance = fields.has('castGlance')
        ? _floorClip(fields.child('castGlance'))
        : null;
    CrowdParting? parting;
    if (fields.has('parting')) {
      final part = fields.child('parting');
      parting = CrowdParting(
        from: part.number('from', min: 0),
        beats: part.number('beats', min: .5),
        stagger: part.number('stagger', min: 0),
        slowTo: part.number('slowTo', min: .1, max: 1),
      );
      part.finish();
      // The fight's first call has to be readable from its first beat.
      if (parting.end > introBeats) {
        throw LevelDataError(
          part.path,
          'the floor must be open by beat $introBeats, not ${parting.end}',
        );
      }
    }
    fields.finish();
    return FloorDance(
      ownThing: ownThing,
      glance: glance,
      occupied: occupied,
      castGlance: castGlance,
      sidestep: sidestep,
      following: following,
      parting: parting,
    );
  }

  /// Those nearest the dancer move first, as if the fight pushed the floor open.
  static List<double> _partDelays(
    List<PartyPoint> anchors,
    List<PartyPoint?> partTo,
    PartyPoint heart,
    double stagger,
  ) {
    double distance(PartyPoint p) =>
        (p.x - heart.x).abs() + (p.y - heart.y).abs();
    final moving = [
      for (final (i, anchor) in anchors.indexed)
        if (partTo[i] != null) distance(anchor),
    ];
    if (moving.isEmpty) return List.filled(anchors.length, 0);
    final near = moving.reduce((a, b) => a < b ? a : b);
    final far = moving.reduce((a, b) => a > b ? a : b);
    return [
      for (final anchor in anchors)
        far == near ? 0 : stagger * (distance(anchor) - near) / (far - near),
    ];
  }

  static List<PartyPoint> _outline(_Fields fields, String key) {
    final path = fields.at(key);
    final points = [
      for (final (i, raw) in fields.list(key).indexed) _point('$path[$i]', raw),
    ];
    if (points.length < 3) throw LevelDataError(path, 'needs three corners');
    return List.unmodifiable(points);
  }

  /// A platform's corners may run off the plate, so these aren't held to 0..1.
  static RoomPlatform _platform(_Fields fields, PartyFloorPlane floor) {
    final path = fields.at('deck');
    final deck = <PartyPoint>[];
    for (final (i, raw) in fields.list('deck').indexed) {
      if (raw is! List<Object?> || raw.length != 2) {
        throw LevelDataError('$path[$i]', 'expected [x, y]');
      }
      deck.add(PartyPoint(_number('$path[$i]', raw[0]), _number('$path[$i]', raw[1])));
    }
    if (deck.length < 3) throw LevelDataError(path, 'needs three corners');
    final lift = fields.number('lift', min: 0, max: 1);
    fields.finish();
    return RoomPlatform(
      lift: lift,
      deck: List.unmodifiable(deck),
      horizonY: floor.horizonY,
      // The same eye the floor plane's numbers come from.
      eyeHeightAdults:
          (floor.referenceFootY - floor.horizonY) / floor.referenceHeight,
    );
  }

  static LevelBand _band(
    _Fields fields,
    PartyPoint Function(String, PartyPoint) onFloor,
    RoomPlatform? platform,
  ) {
    final standIn = fields.flag('standIn');
    final laddersFields = fields.child('ladders');
    final ladders = <String, List<BandRung>>{};
    List<BandRung> ladder(_Fields from, String key) {
      final name = from.text(key);
      return ladders[name] ??= () {
        final path = laddersFields.at(name);
        final rungs = <BandRung>[];
        for (final (i, raw) in laddersFields.list(name).indexed) {
          final rung = _Fields('$path[$i]', raw);
          final input = rung.named('input', BandInput.values);
          final fromValue = rung.number('from', min: 0);
          final clipFields = _Fields(rung.path, {
            'frames': rung.list('frames'),
            'beatsPerFrame': rung.number('beatsPerFrame', min: .125),
          });
          rungs.add(
            BandRung(clip: _floorClip(clipFields), input: input, from: fromValue),
          );
          rung.finish();
        }
        if (rungs.isEmpty) throw LevelDataError(path, 'needs a rung');
        if (rungs.first.from != 0) {
          throw LevelDataError('$path[0]', 'the first rung is where they start');
        }
        return List<BandRung>.unmodifiable(rungs);
      }();
    }

    final path = fields.at('players');
    final players = [
      for (final (i, raw) in fields.list('players').indexed)
        () {
          final player = _Fields('$path[$i]', raw);
          final feet = player.point('feet');
          if (platform != null && !platform.holds(feet)) {
            throw LevelDataError(player.at('feet'), 'is off the platform');
          }
          final parsed = BandPlayer(
            id: player.text('id'),
            atlas: player.text('atlas'),
            feet: feet,
            at: onFloor(player.at('feet'), platform?.groundUnder(feet) ?? feet),
            ladder: ladder(player, 'ladder'),
            reference: player.text('reference'),
            palette: player.has('palette')
                ? player.whole('palette', min: 0)
                : null,
            stature: player.has('stature')
                ? player.number('stature', min: .1)
                : 1,
            flipX: player.has('flipX') && player.flag('flipX'),
            beatOffset: player.has('beatOffset')
                ? player.number('beatOffset', min: 0)
                : 0,
            lateBy: player.has('lateBy') ? player.number('lateBy', min: 0) : 0,
          );
          player.finish();
          return parsed;
        }(),
    ];
    if (players.isEmpty) throw LevelDataError(path, 'a band needs a player');
    laddersFields.finish();
    fields.finish();
    return LevelBand(players: List.unmodifiable(players), standIn: standIn);
  }

  static ExitShotCue _moveAccent(_Fields fields) {
    final track = fields.text('track');
    if (!isAccentTrack(track)) {
      throw LevelDataError(fields.at('track'), 'no such accent: $track');
    }
    final accent = ExitShotCue(
      0,
      track,
      fields.whole('pitch', min: 0),
      fields.whole('velocity', min: 1),
    );
    fields.finish();
    return accent;
  }

  static SceneOccluder _occluder(_Fields fields) {
    final path = fields.at('outline');
    final occluder = SceneOccluder(
      outline: List.unmodifiable([
        for (final (i, raw) in fields.list('outline').indexed)
          _point('$path[$i]', raw),
      ]),
      frontY: fields.number('frontY', min: 0, max: 1),
    );
    if (occluder.outline.length < 3) {
      throw LevelDataError(path, 'an outline needs three points');
    }
    fields.finish();
    return occluder;
  }

  static WallLight _wallLight(_Fields fields) {
    final path = fields.at('zones');
    final zones = <List<PartyPoint>>[];
    for (final (i, raw) in fields.list('zones').indexed) {
      final zone = _Fields('$path[$i]', raw);
      final points = _outline(zone, 'outline');
      zone.finish();
      for (final point in points) {
        if (point.y >= thumbBandTop) {
          throw LevelDataError(zone.path, 'reaches the tap band');
        }
        if (point.x > roomLayerQuietLeft &&
            point.x < roomLayerQuietRight &&
            point.y > roomLayerQuietTop &&
            point.y < roomLayerQuietBottom) {
          throw LevelDataError(zone.path, 'reaches the quiet area');
        }
      }
      zones.add(points);
    }
    if (zones.isEmpty) throw LevelDataError(path, 'needs a zone');
    final light = WallLight(
      zones: List.unmodifiable(zones),
      periodBeats: fields.number('periodBeats', min: 4),
    );
    fields.finish();
    return light;
  }

  static ExitShot _exitShot(_Fields fields) {
    ui.Offset offset(_Fields from, String key) {
      final point = from.list(key);
      if (point.length != 2) {
        throw LevelDataError(from.at(key), 'expected [x, y]');
      }
      return ui.Offset(
        _number(from.at(key), point[0]),
        _number(from.at(key), point[1]),
      );
    }

    final actorsPath = fields.at('actors');
    final actors = <ExitShotActor>[];
    for (final (i, raw) in fields.list('actors').indexed) {
      final actor = _Fields('$actorsPath[$i]', raw);
      final frames = <ExitShotFrame>[];
      if (actor.has('frames')) {
        final framesPath = actor.at('frames');
        var previous = double.negativeInfinity;
        for (final (j, rawFrame) in actor.list('frames').indexed) {
          final frame = _Fields('$framesPath[$j]', rawFrame);
          final beat = frame.number('beat');
          if (beat <= previous) {
            throw FormatException('$framesPath[$j] must start after the frame before it');
          }
          previous = beat;
          frames.add(ExitShotFrame(beat, frame.text('image')));
          frame.finish();
        }
      }
      actors.add(
        ExitShotActor(
          approach: actor.text('approach'),
          impact: actor.text('impact'),
          contact: offset(actor, 'contact'),
          scale: actor.number('scale', min: .1),
          entry: offset(actor, 'entry'),
          recoil: offset(actor, 'recoil'),
          frames: frames,
          keepsReading: actor.has('keepsReading') && actor.flag('keepsReading'),
          sway: actor.has('sway') ? _sway(actor.child('sway')) : null,
        ),
      );
      actor.finish();
    }
    final cuePath = fields.at('cue');
    final cue = <ExitShotCue>[];
    for (final (i, raw) in fields.list('cue').indexed) {
      final note = _Fields('$cuePath[$i]', raw);
      final track = note.text('track');
      if (!isCueTrack(track)) {
        throw LevelDataError(note.at('track'), 'no such sound: $track');
      }
      cue.add(
        ExitShotCue(
          note.number('beat', min: 0),
          track,
          note.whole('pitch', min: 0),
          note.whole('velocity', min: 1),
        ),
      );
      note.finish();
    }
    final shot = ExitShot(
      plate: fields.text('plate'),
      celebrateUntil: fields.number('celebrateUntil', min: 0),
      walkFrom: fields.number('walkFrom', min: 0),
      walkTo: fields.number('walkTo', min: 0),
      heroStep: offset(fields, 'heroStep'),
      closeupFrom: fields.number('closeupFrom', min: 0),
      contactBeat: fields.number('contactBeat', min: 0),
      closeupTo: fields.number('closeupTo', min: 0),
      contactPoint: offset(fields, 'contactPoint'),
      actors: List.unmodifiable(actors),
      cue: List.unmodifiable(cue),
      impactBeats: fields.has('impactBeats')
          ? fields.number('impactBeats', min: .1)
          : .4,
      recoilBeats: fields.has('recoilBeats')
          ? fields.number('recoilBeats', min: .5)
          : null,
      heroWaitFrame: fields.has('heroWaitFrame')
          ? fields.text('heroWaitFrame')
          : 'rear_idle',
      throwsDust: fields.has('dust') ? fields.flag('dust') : true,
      opponent: [
        for (final (i, raw) in fields.list('opponent', optional: true).indexed)
          _shotClip(_Fields('${fields.at('opponent')}[$i]', raw)),
      ],
      flare: fields.has('flare') ? _flare(fields.child('flare')) : null,
      applause: fields.has('applause')
          ? _shotClip(fields.child('applause'))
          : null,
      keepsake: fields.has('keepsake')
          ? _keepsake(fields.child('keepsake'), offset)
          : null,
      walkOut: fields.has('walkOut') ? _walkOut(fields.child('walkOut')) : null,
    );
    fields.finish();
    for (var i = 1; i < shot.opponent.length; i++) {
      if (shot.opponent[i].from <= shot.opponent[i - 1].from) {
        throw LevelDataError(
          '${fields.at('opponent')}[$i]',
          'must start after the clip before it',
        );
      }
    }
    final walkOut = shot.walkOut;
    if (walkOut != null &&
        !(walkOut.from >= shot.closeupTo && walkOut.from < walkOut.to)) {
      throw LevelDataError(
        fields.at('walkOut'),
        'starts after the close-up and before it ends',
      );
    }
    final flare = shot.flare;
    if (flare != null && flare.from < shot.closeupTo) {
      throw LevelDataError(fields.at('flare'), 'belongs to the wide shot');
    }
    final keepsake = shot.keepsake;
    if (keepsake != null && keepsake.from > shot.closeupTo) {
      throw LevelDataError(
        fields.at('keepsake'),
        'is his from the close-up, so it starts by the cut out',
      );
    }
    if (!(shot.walkFrom < shot.walkTo &&
        shot.walkTo <= shot.closeupFrom &&
        shot.closeupFrom < shot.contactBeat &&
        shot.contactBeat < shot.closeupTo)) {
      throw LevelDataError(
        fields.path,
        'beats must run walk, close-up, contact',
      );
    }
    return shot;
  }

  static ExitShotClip _shotClip(_Fields fields) {
    final path = fields.at('frames');
    final frames = [
      for (final (i, raw) in fields.list('frames').indexed)
        raw is String && raw.isNotEmpty
            ? raw
            : throw LevelDataError('$path[$i]', 'a drawing name'),
    ];
    if (frames.isEmpty) throw LevelDataError(path, 'needs a drawing');
    final clip = ExitShotClip(
      from: fields.number('from', min: 0),
      frames: List.unmodifiable(frames),
      beatsPerFrame: fields.number('beatsPerFrame', min: .125),
      loop: fields.has('loop') && fields.flag('loop'),
    );
    fields.finish();
    return clip;
  }

  static ExitShotFlare _flare(_Fields fields) {
    final flare = ExitShotFlare(
      from: fields.number('from', min: 0),
      beats: fields.number('beats', min: 1),
      rise: fields.has('rise') ? fields.number('rise', min: .25) : 1,
      gain: fields.has('gain') ? fields.number('gain', min: 0, max: 1.5) : 1,
    );
    fields.finish();
    if (flare.rise >= flare.beats) {
      throw LevelDataError(fields.at('rise'), 'must leave time to settle');
    }
    return flare;
  }

  static ExitShotKeepsake _keepsake(
    _Fields fields,
    ui.Offset Function(_Fields, String) offset,
  ) {
    final keepsake = ExitShotKeepsake(
      image: fields.text('image'),
      from: fields.number('from', min: 0),
      at: offset(fields, 'at'),
      anchor: offset(fields, 'anchor'),
      height: fields.number('height', min: .02, max: .6),
    );
    fields.finish();
    return keepsake;
  }

  static ExitShotWalkOut _walkOut(_Fields fields) {
    final walk = ExitShotWalkOut(
      from: fields.number('from', min: 0),
      to: fields.number('to', min: 0),
      fadeBeats: fields.has('fadeBeats')
          ? fields.number('fadeBeats', min: .25)
          : 1,
    );
    fields.finish();
    return walk;
  }

  static ExitShotSway _sway(_Fields fields) {
    final by = fields.list('by');
    if (by.length != 2) {
      throw LevelDataError(fields.at('by'), 'expected [x, y]');
    }
    final sway = ExitShotSway(
      from: fields.number('from', min: 0),
      beats: fields.number('beats', min: .5),
      by: ui.Offset(
        _number(fields.at('by'), by[0]),
        _number(fields.at('by'), by[1]),
      ),
    );
    fields.finish();
    return sway;
  }

  static FightChart _chart(_Fields fields) {
    List<Limb> limbs(String path, Object? raw) {
      if (raw is! List<Object?>) {
        throw LevelDataError(path, 'expected a list of limbs, found $raw');
      }
      return List.unmodifiable([
        for (final (i, limb) in raw.indexed)
          _named('$path[$i]', limb, Limb.values),
      ]);
    }

    final offsetsPath = fields.at('offsets');
    final variantsPath = fields.at('variants');
    final rich = fields.has('rich') ? _rich(fields.child('rich')) : null;
    final chart = FightChart(
      introBeats: fields.number('introBeats', min: .25),
      callBeats: fields.number('callBeats', min: .25),
      flourishDestination: fields.named('flourishDestination', Limb.values),
      offsets: List.unmodifiable([
        for (final (i, offset) in fields.list('offsets').indexed)
          _number('$offsetsPath[$i]', offset),
      ]),
      limbs: limbs(fields.at('limbs'), fields.list('limbs')),
      variants: List.unmodifiable([
        for (final (i, variant) in fields.list('variants').indexed)
          limbs('$variantsPath[$i]', variant),
      ]),
      richPatterns: rich?.patterns ?? const {},
      limits: rich?.limits ?? const MoveLimits(),
    );
    fields.finish();
    try {
      chart.validate();
    } on ArgumentError catch (error) {
      throw LevelDataError(fields.path, '${error.message}');
    }
    return chart;
  }

  /// The chart's richer moves: `plan/double-moves-2026-11-07.md`. A chart without
  /// this field plays exactly as it did before they existed.
  static ({Map<int, List<ChartStep>> patterns, MoveLimits limits}) _rich(
    _Fields fields,
  ) {
    final limits = fields.child('limits');
    int ms(String key) => limits.whole(key, min: 0);
    final parsedLimits = MoveLimits(
      pairToleranceMs: ms('pairToleranceMs'),
      sameSpotMs: ms('sameSpotMs'),
      thumbHopMs: ms('thumbHopMs'),
      crossThumbMs: ms('crossThumbMs'),
      sameLimbMs: ms('sameLimbMs'),
      phraseEndMs: ms('phraseEndMs'),
    );
    limits.finish();
    final patterns = fields.child('patterns');
    final raw = patterns._raw;
    final parsed = <int, List<ChartStep>>{};
    for (final key in raw.keys.toList()) {
      final index = int.tryParse(key);
      if (index == null) {
        throw LevelDataError(patterns.at(key), 'expected a pattern number');
      }
      parsed[index] = List.unmodifiable([
        for (final (i, step) in patterns.list(key).indexed)
          _step(_Fields('${patterns.at(key)}[$i]', step)),
      ]);
    }
    patterns.finish();
    fields.finish();
    return (patterns: Map.unmodifiable(parsed), limits: parsedLimits);
  }

  static ChartStep _step(_Fields fields) {
    final move = fields.has('move')
        ? fields.named('move', RichMove.values)
        : null;
    final step = ChartStep(
      fields.number('at', min: 0),
      fields.named('limb', Limb.values),
      move: move,
      partner: fields.has('with') ? fields.named('with', Limb.values) : null,
      gap: fields.has('gap') ? fields.number('gap', min: .001) : 0,
      offer: fields.has('offer')
          ? fields.named('offer', GestureKind.values)
          : null,
    );
    fields.finish();
    return step;
  }

  static List<LevelChallenger> _challengers(
    _Fields stage,
    PartyPoint Function(_Fields, String) mark,
  ) {
    final path = stage.at('challengers');
    final challengers = <LevelChallenger>[];
    for (final (i, raw) in stage.list('challengers').indexed) {
      final fields = _Fields('$path[$i]', raw);
      challengers.add(
        LevelChallenger(
          id: fields.text('id'),
          atlas: fields.text('atlas'),
          mark: mark(fields, 'mark'),
          yieldMark: mark(fields, 'yieldMark'),
          track: fields.has('floorTrack')
              ? _floorTrack(fields.child('floorTrack'))
              : null,
          stature: fields.has('stature')
              ? fields.number('stature', min: .1)
              : 1,
          meetMark: fields.has('meetMark') ? mark(fields, 'meetMark') : null,
          facingAway: fields.has('facingAway')
              ? _facingAway(fields.child('facingAway'))
              : null,
          defeatStance: fields.has('defeatStance')
              ? _floorClip(fields.child('defeatStance'))
              : null,
          line: fields.has('line')
              ? _line(fields.child('line'), fields.point('mark'))
              : null,
        ),
      );
      fields.finish();
    }
    if (challengers.isEmpty) {
      throw LevelDataError(path, 'a level needs at least one challenger');
    }
    if (challengers.map((c) => c.id).toSet().length != challengers.length) {
      throw LevelDataError(path, 'challenger ids must be unique');
    }
    return List.unmodifiable(challengers);
  }

  static DanceLine _line(_Fields fields, PartyPoint lead) {
    final path = fields.at('dancers');
    final raw = fields.list('dancers');
    if (raw.isEmpty || raw.length > DanceLine.maxDancers) {
      throw LevelDataError(path, 'a line has 1 to ${DanceLine.maxDancers} more');
    }
    final dancers = <LineDancer>[];
    for (final (i, entry) in raw.indexed) {
      final dancer = _Fields('$path[$i]', entry);
      final offset = dancer.offset('offset');
      final arch = dancer.has('archOffset') ? dancer.offset('archOffset') : null;
      final lag = dancer.has('lagBeats')
          ? dancer.number('lagBeats', min: 0, max: DanceLine.maxLagBeats)
          : 0.0;
      // Their marks must be floor a person can stand on, off the thumbs.
      for (final (key, by) in [('offset', offset), ('archOffset', arch)]) {
        if (by == null) continue;
        final at = PartyPoint(lead.x + by.x, lead.y + by.y);
        if (at.y >= thumbBandTop || at.x < 0 || at.x > 1) {
          throw LevelDataError(dancer.at(key), 'puts them off the floor: $at');
        }
      }
      dancers.add(
        LineDancer(
          offset: offset,
          lagBeats: lag,
          archOffset: arch,
          archMirrored: dancer.has('archMirrored') && dancer.flag('archMirrored'),
          stature: dancer.has('stature')
              ? dancer.number('stature', min: .1)
              : 1,
          image: dancer.has('image') ? dancer.text('image') : null,
        ),
      );
      dancer.finish();
    }
    LineArch? arch;
    if (fields.has('arch')) {
      final a = fields.child('arch');
      final framesPath = a.at('frames');
      arch = LineArch(
        from: a.number('from', min: 0),
        beats: a.number('beats', min: .25),
        frames: a.has('frames')
            ? [
                for (final (i, f) in a.list('frames').indexed)
                  f is String && f.isNotEmpty
                      ? f
                      : throw LevelDataError('$framesPath[$i]', 'a drawing name'),
              ]
            : const [],
        beatsPerFrame: a.has('beatsPerFrame')
            ? a.number('beatsPerFrame', min: .25)
            : 1,
      );
      a.finish();
    }
    fields.finish();
    return DanceLine(dancers: List.unmodifiable(dancers), arch: arch);
  }

  static FacingAway _facingAway(_Fields fields) {
    final path = fields.at('turn');
    final turn = [
      for (final (i, raw) in fields.list('turn').indexed)
        raw is String && raw.isNotEmpty
            ? raw
            : throw LevelDataError('$path[$i]', 'a drawing name'),
    ];
    if (turn.isEmpty) throw LevelDataError(path, 'a turn needs drawings');
    final away = FacingAway(
      back: _floorClip(fields.child('back')),
      turn: List.unmodifiable(turn),
      turnBeats: fields.number('turnBeats', min: .5),
    );
    fields.finish();
    return away;
  }

  /// Refuses a pattern the scene couldn't keep: a dancer on the tap band or past
  /// a phone's edge, a turn that repeats a lead, or an end mark like her last.
  static LevelDuet _duet(
    _Fields fields,
    List<LevelChallenger> challengers,
    double cycleBeats,
    PartyPoint heroHome,
  ) {
    final path = fields.path;
    if (challengers.length != 2) {
      throw LevelDataError(path, 'a duet needs exactly two challengers');
    }
    final markFields = fields.child('marks');
    final marks = <String, PartyPoint>{};
    PartyPoint mark(_Fields from, String key) {
      final name = from.text(key);
      if (!marks.containsKey(name)) {
        marks[name] = markFields.point(name);
      }
      final point = marks[name]!;
      if (point.y >= thumbBandTop || point.x < .17 || point.x > .83) {
        throw LevelDataError(from.at(key), '$name is off the dance floor');
      }
      return point;
    }

    final outgoing = fields.number('outgoingBeats', min: .25);
    final incoming = fields.number('incomingBeats', min: .25);
    final gap = fields.number('partnerGap', min: .05, max: .6);
    final upstage = fields.number('partnerUpstage', min: 0, max: .2);
    PartyPoint beside(bool left) {
      final point = PartyPoint(heroHome.x + (left ? -gap : gap), heroHome.y - upstage);
      if (point.y >= thumbBandTop || point.x < .17 || point.x > .83) {
        throw LevelDataError(fields.at('partnerGap'), 'beside Mācron is off the dance floor');
      }
      return point;
    }

    int dancerOf(_Fields from, String key) {
      final id = from.text(key);
      final index = challengers.indexWhere((c) => c.id == id);
      if (index < 0) {
        throw LevelDataError(from.at(key), 'no such challenger: $id');
      }
      return index;
    }

    final turnsPath = fields.at('turns');
    final turns = <DuetTurn>[];
    for (final (i, raw) in fields.list('turns').indexed) {
      final turn = _Fields('$turnsPath[$i]', raw);
      final partner = dancerOf(turn, 'partner');
      final left = dancerOf(turn, 'left');
      final steps = <DuetOffStep>[];
      var last = 0.0;
      for (final (j, rawStep) in turn.list('offSteps').indexed) {
        final step = _Fields('${turn.at('offSteps')}[$j]', rawStep);
        final at = step.number('at', min: cycleBeats / 2, max: cycleBeats - incoming);
        if (at <= last) {
          throw LevelDataError(step.path, 'steps must run forward in time');
        }
        last = at;
        steps.add(DuetOffStep(at, mark(step, 'to')));
        step.finish();
      }
      turns.add(
        DuetTurn(
          partner: partner,
          left: left,
          from: mark(turn, 'from'),
          to: mark(turn, 'to'),
          // She steps out from the pair on the side she was already on.
          dance: beside(partner == left),
          off: mark(turn, 'off'),
          offSteps: List.unmodifiable(steps),
        ),
      );
      turn.finish();
    }
    if (turns.length.isOdd || turns.isEmpty) {
      throw LevelDataError(turnsPath, 'turns alternate, so they come in pairs');
    }
    for (var i = 0; i < turns.length; i++) {
      final next = turns[(i + 1) % turns.length];
      final again = turns[(i + 2) % turns.length];
      if (turns[i].partner == next.partner) {
        throw LevelDataError('$turnsPath[$i]', 'his partner must alternate');
      }
      if (turns.length > 2 && identical(turns[i].to, again.to)) {
        throw LevelDataError(
          '$turnsPath[$i]',
          'the pair must end somewhere new each turn',
        );
      }
    }
    final pairFields = fields.child('pairFrames');
    final pairFrames = DuetPairFrames(
      rest: List.unmodifiable([
        for (final (j, frame) in pairFields.list('rest').indexed)
          frame is String && frame.isNotEmpty
              ? frame
              : throw LevelDataError('${pairFields.at('rest')}[$j]', 'a drawing name'),
      ]),
      arm: pairFields.text('arm'),
      kick: pairFields.text('kick'),
    );
    pairFields.finish();
    if (pairFrames.rest.isEmpty) {
      throw LevelDataError(pairFields.at('rest'), 'a pair needs a resting drawing');
    }
    final spinFields = fields.child('spin');
    final spin = DuetSpinSpec(
      beats: spinFields.number('beats', min: .25),
      reachFrame: spinFields.text('reachFrame'),
      heroFrames: List.unmodifiable([
        for (final (j, frame) in spinFields.list('heroFrames').indexed)
          frame is String && frame.isNotEmpty
              ? frame
              : throw LevelDataError('${spinFields.at('heroFrames')}[$j]', 'a drawing name'),
      ]),
      catchUpBeats: spinFields.number('catchUpBeats', min: .25),
    );
    spinFields.finish();
    if (spin.heroFrames.isEmpty) {
      throw LevelDataError(spinFields.at('heroFrames'), 'a spin needs drawings');
    }
    final exitFields = fields.child('exit');
    final exit = DuetExit(
      left: mark(exitFields, 'left'),
      right: mark(exitFields, 'right'),
      leftReach: mark(exitFields, 'leftReach'),
      rightReach: mark(exitFields, 'rightReach'),
      sideBeats: exitFields.number('sideBeats', min: .25),
      reachFrom: exitFields.number('reachFrom', min: 0),
      reachTo: exitFields.number('reachTo', min: 0),
      reachFrame: exitFields.text('reachFrame'),
      backBeats: exitFields.number('backBeats', min: .25),
      danceClip: exitFields.text('danceClip'),
    );
    exitFields.finish();
    if (exit.reachFrom >= exit.reachTo || exit.sideBeats > exit.reachFrom) {
      throw LevelDataError(
        exitFields.path,
        'beats must run to the sides, then reach',
      );
    }
    final duet = LevelDuet(
      turns: List.unmodifiable(turns),
      offClip: fields.text('offClip'),
      partnerClip: fields.text('partnerClip'),
      outgoingBeats: outgoing,
      incomingBeats: incoming,
      spread: fields.number('spread', min: .01, max: .2),
      pairFrames: pairFrames,
      spin: spin,
      exit: exit,
    );
    markFields.finish();
    fields.finish();
    return duet;
  }

  static FloorTrack _floorTrack(_Fields fields) {
    final beats = fields.number('beats', min: 1);
    final path = fields.at('points');
    final points = <(double, PartyPoint)>[];
    var last = -1.0;
    for (final (i, raw) in fields.list('points').indexed) {
      final point = _Fields('$path[$i]', raw);
      final at = point.number('at', min: 0, max: beats);
      if (at <= last) {
        throw LevelDataError('$path[$i]', 'points must run forward in time');
      }
      last = at;
      points.add((at, point.point('floor')));
      point.finish();
    }
    fields.finish();
    if (points.length < 2 || points.first.$1 != 0) {
      throw LevelDataError(
        path,
        'a track needs a start at beat 0 and a second point',
      );
    }
    return FloorTrack(beats, List.unmodifiable(points));
  }

  static CrowdStageProfile _crowd(String id, _Fields fields) {
    int budget(String key) {
      final value = fields.whole(key, min: 0);
      if (value > CrowdInterestModel.castSize) {
        throw LevelDataError(fields.at(key), '$value is above the cast size');
      }
      return value;
    }

    final profile = CrowdStageProfile(
      id,
      budget('interested'),
      budget('following'),
      budget('standing'),
      budget('cheering'),
    );
    fields.finish();
    if (profile.interested < profile.following ||
        profile.following < profile.standing ||
        profile.standing < profile.cheering) {
      throw LevelDataError(
        fields.path,
        'budgets are cumulative: interested >= following >= standing >= '
        'cheering',
      );
    }
    return profile;
  }

  static PartyPropSlot _prop(
    _Fields fields,
    PartyPoint Function(String, PartyPoint) onFloor,
  ) {
    final kind = fields.named('kind', PartyPropKind.values);
    if (kind == PartyPropKind.chair ||
        kind == PartyPropKind.stool ||
        kind == PartyPropKind.drink) {
      // Seats come with the guests; drinks belong to the tables and the seated
      // poses. The scene would draw none of these from a prop entry.
      throw LevelDataError(fields.at('kind'), '${kind.name} cannot be placed');
    }
    final prop = PartyPropSlot(
      fields.text('id'),
      kind,
      onFloor(fields.at('at'), fields.point('at')),
      heightInAdults: fields.number('heightInAdults', min: .01),
      widthInAdults: fields.number('widthInAdults', min: .01),
    );
    fields.finish();
    return prop;
  }

  static List<RoomLayerProp> _layers(_Fields fields) {
    final plateWidth = fields.whole('plateWidth', min: 1);
    final plateHeight = fields.whole('plateHeight', min: 1);
    final propsPath = fields.at('props');
    final ids = <String>{};
    final props = [
      for (final (i, raw) in fields.list('props').indexed)
        () {
          final path = '$propsPath[$i]';
          final prop = _Fields(path, raw);
          final layer = RoomLayerProp(
            id: prop.text('id'),
            atlas: prop.text('atlas'),
            atlasY: prop.whole('atlasY', min: 0),
            left: prop.whole('left', min: 0),
            top: prop.whole('top', min: 0),
            width: prop.whole('width', min: 1),
            height: prop.whole('height', min: 1),
            frames: prop.whole('frames', min: 2),
            motion: prop.named('motion', RoomLayerMotion.values),
            periodBeats: prop.number('periodBeats', min: .25),
            instance: prop.whole('instance', min: 0),
            kind: prop.named('kind', PartyLifeKind.values),
            minTier: prop.has('minTier') ? prop.whole('minTier', min: 1) : null,
            phaseBeats: prop.has('phaseBeats')
                ? prop.number('phaseBeats', min: 0)
                : 0,
          );
          prop.finish();
          if ((layer.minTier ?? 0) > PartyUp.topTier) {
            throw LevelDataError(
              '$path.minTier',
              'the top tier is ${PartyUp.topTier}',
            );
          }
          if (!ids.add(layer.id)) {
            throw LevelDataError(path, 'duplicate layer id ${layer.id}');
          }
          final problem = layer.placementProblem(plateWidth, plateHeight);
          if (problem != null) {
            throw LevelDataError(path, '${layer.id} $problem');
          }
          return layer;
        }(),
    ];
    fields.finish();
    return List.unmodifiable(props);
  }

  static LevelWaiter _waiter(
    _Fields fields,
    PartyPoint Function(String, PartyPoint) onFloor,
  ) {
    final waiter = LevelWaiter(
      home: onFloor(fields.at('home'), fields.point('home')),
      swayX: fields.number('swayX', min: 0, max: 1),
    );
    fields.finish();
    return waiter;
  }

  static DepartureRoute _route(_Fields fields) {
    final threshold = fields.text('threshold');
    final path = fields.at('waypoints');
    final waypoints = <DepartureWaypoint>[];
    for (final (i, raw) in fields.list('waypoints').indexed) {
      final waypoint = _Fields('$path[$i]', raw);
      waypoints.add(
        DepartureWaypoint(
          waypoint.number('at', min: 0, max: 1),
          // Pose scale is omitted on purpose: the scene sizes the hero from
          // the floor plane and has never read it.
          DeparturePose(
            waypoint.number('x', min: 0, max: 1),
            waypoint.number('y', min: 0, max: 1),
            1,
            waypoint.named('facing', DepartureFacing.values),
          ),
        ),
      );
      waypoint.finish();
    }
    if (waypoints.length < 2 ||
        waypoints.first.progress != 0 ||
        waypoints.last.progress != 1) {
      throw LevelDataError(path, 'a route runs from at: 0 to at: 1');
    }
    for (var i = 1; i < waypoints.length; i++) {
      if (waypoints[i].progress <= waypoints[i - 1].progress) {
        throw LevelDataError('$path[$i]', 'at must increase along the route');
      }
    }
    return DepartureRoute(
      threshold: threshold,
      waypoints: List.unmodifiable(waypoints),
    );
  }
}

/// A level's place in the campaign and what links it to the next. Bridges are
/// written from one level to another, so they live here:
/// adding a level changes this list and leaves its neighbours' files alone.
/// Whether the owner has signed off on a combo's name and shape.
enum HardestComboStatus { proposal, accepted }

/// One move an opponent dances in a combo's call, from a clip it has today.
class HardestComboMove {
  const HardestComboMove({
    required this.dancer,
    required this.at,
    required this.beats,
    required this.clip,
  });
  final String dancer;
  final double at, beats;
  final String clip;
}

/// An opponent's named hardest combo: what they dance in the call, and the notes
/// the player answers with. Data only. Nothing plays it until the bathroom boss.
class HardestCombo {
  const HardestCombo({
    required this.name,
    required this.status,
    required this.callBeats,
    required this.moves,
    required this.chart,
    this.lastNoteMove,
  });
  final String name;
  final HardestComboStatus status;
  final double callBeats;
  final List<HardestComboMove> moves;

  /// The player's notes, in the shape the session already plays.
  final FightChart chart;

  /// The optional move its last note invites, if it asks for a particular one.
  final GestureKind? lastNoteMove;
}

/// Someone the campaign doesn't reach yet, who already needs a place in the boss.
class UpcomingOpponent {
  const UpcomingOpponent({
    required this.id,
    required this.name,
    required this.level,
    required this.hardestCombo,
  });
  final String id;
  final String name;

  /// The planned room. It need not exist, so it isn't looked up.
  final String level;

  /// Null only when the entry says it's a placeholder.
  final HardestCombo? hardestCombo;
}

/// Refuses a combo the boss couldn't stage: a clip with no room in the call, two
/// moves at once for one dancer, a dancer who isn't in the room or who sits it
/// out, or notes the session's own chart check wouldn't pass.
HardestCombo _hardestCombo(_Fields fields, List<String> dancers) {
  final callBeats = fields.number('callBeats', min: .25);
  final name = fields.text('name');
  final status = fields.named('status', HardestComboStatus.values);
  if (fields.has('note')) fields.text('note');

  final movesPath = fields.at('moves');
  final moves = <HardestComboMove>[];
  for (final (i, raw) in fields.list('moves').indexed) {
    final path = '$movesPath[$i]';
    final move = _Fields(path, raw);
    final String dancer;
    if (move.has('dancer')) {
      dancer = move.text('dancer');
      if (!dancers.contains(dancer)) {
        throw LevelDataError(move.at('dancer'), 'no such dancer: $dancer');
      }
    } else if (dancers.length == 1) {
      dancer = dancers.single;
    } else {
      throw LevelDataError(path, 'a pair\'s move must name its dancer');
    }
    final parsed = HardestComboMove(
      dancer: dancer,
      at: move.number('at', min: 0),
      beats: move.number('beats', min: .25),
      clip: move.text('clip'),
    );
    move.finish();
    if (parsed.at + parsed.beats > callBeats) {
      throw LevelDataError(path, '${parsed.clip} runs past the call');
    }
    final before = moves.where((m) => m.dancer == dancer).lastOrNull;
    if (before != null && parsed.at < before.at + before.beats) {
      throw LevelDataError(path, '${parsed.clip} starts before $dancer is free');
    }
    moves.add(parsed);
  }
  for (final dancer in dancers) {
    if (!moves.any((m) => m.dancer == dancer)) {
      throw LevelDataError(movesPath, '$dancer has no moves');
    }
  }

  final notesPath = fields.at('notes');
  final offsets = <double>[];
  final limbs = <Limb>[];
  GestureKind? lastNoteMove;
  final notes = fields.list('notes');
  for (final (i, raw) in notes.indexed) {
    final path = '$notesPath[$i]';
    final note = _Fields(path, raw);
    offsets.add(note.number('at', min: 0));
    limbs.add(note.named('limb', Limb.values));
    if (note.has('move')) {
      if (i != notes.length - 1) {
        throw LevelDataError(
          note.at('move'),
          'only the last note has room for a longer shape',
        );
      }
      lastNoteMove = note.named('move', GestureKind.values);
    }
    note.finish();
  }
  fields.finish();
  final chart = FightChart(
    limbs: List.unmodifiable(limbs),
    offsets: List.unmodifiable(offsets),
    callBeats: callBeats,
  );
  try {
    chart.validate();
  } on ArgumentError catch (error) {
    throw LevelDataError(notesPath, '${error.message}');
  }
  return HardestCombo(
    name: name,
    status: status,
    callBeats: callBeats,
    moves: List.unmodifiable(moves),
    chart: chart,
    lastNoteMove: lastNoteMove,
  );
}

class LevelStep {
  const LevelStep({
    required this.level,
    required this.next,
    required this.bridgeToNext,
  });
  final LevelDefinition level;
  final LevelDefinition? next;
  final String? bridgeToNext;
}

/// The ordered campaign, and the single source of level order.
class LevelRegistry {
  LevelRegistry._(
    this.campaign,
    this.displayTotal,
    this.upcomingOpponents, [
    this.reviewLevels = const {},
  ]);

  static const folder = 'levels';

  final List<LevelStep> campaign;

  /// The number the HUD shows after the level number.
  final int displayTotal;

  /// Opponents with no level yet, so the boss can count on them from the start.
  final List<UpcomingOpponent> upcomingOpponents;

  /// Levels not in the campaign yet, reachable only from a review link. Checked
  /// like any other, so one that goes bad fails at the door.
  final Map<String, LevelDefinition> reviewLevels;

  /// This campaign, or for a review link's [id] that one level alone: a level on
  /// its own has no bridge and ends on its end screen. A level joining the
  /// campaign needs no change here. An unknown id is an error, never another room.
  LevelRegistry reviewing(String? id) {
    if (id == null || id.isEmpty) return this;
    final level =
        reviewLevels[id] ?? levels.where((l) => l.id == id).firstOrNull;
    if (level == null) {
      throw ArgumentError.value(id, 'level', 'No such level');
    }
    return LevelRegistry._(
      List.unmodifiable([
        LevelStep(level: level, next: null, bridgeToNext: null),
      ]),
      1,
      upcomingOpponents,
    );
  }

  Iterable<LevelDefinition> get levels => campaign.map((step) => step.level);
  LevelDefinition get first => campaign.first.level;

  LevelDefinition byId(String id) {
    for (final level in levels) {
      if (level.id == id) return level;
    }
    throw ArgumentError.value(id, 'id', 'No such level in this campaign');
  }

  /// Music scores that must be ready before the run starts.
  Iterable<String> get roomScoreIds => levels.map((l) => l.music.score);

  /// Success phrases and bridges, each listed once.
  Set<String> get exitScoreIds => {
    for (final step in campaign) ...[
      step.level.music.successScore,
      if (step.bridgeToNext != null) step.bridgeToNext!,
    ],
  };

  /// [readLevel] returns the text of `<id>.json`; a test can serve it from a
  /// string, the game serves it from the asset bundle.
  factory LevelRegistry.parse(
    String indexText,
    String Function(String id) readLevel,
  ) {
    final index = _Fields('index', jsonDecode(indexText));
    final path = index.at('campaign');
    final entries = [
      for (final (i, raw) in index.list('campaign').indexed)
        _Fields('$path[$i]', raw),
    ];
    if (entries.isEmpty) throw LevelDataError(path, 'needs at least one level');

    final levels = <LevelDefinition>[];
    for (final entry in entries) {
      final id = entry.text('level');
      final file = '$id.json';
      final raw = jsonDecode(readLevel(id));
      if (raw is! Map<String, Object?>) {
        throw LevelDataError(file, 'expected an object');
      }
      final level = LevelDefinition.fromJson(raw, path: file);
      if (level.id != id) {
        throw LevelDataError(file, 'holds level "${level.id}", not "$id"');
      }
      if (levels.any((other) => other.id == id)) {
        throw LevelDataError(entry.path, 'level "$id" appears twice');
      }
      levels.add(level);
    }

    final steps = <LevelStep>[];
    for (var i = 0; i < levels.length; i++) {
      final entry = entries[i];
      final last = i == levels.length - 1;
      if (last && entry.has('bridgeToNext')) {
        throw LevelDataError(
          entry.at('bridgeToNext'),
          'the last level has nowhere to go',
        );
      }
      steps.add(
        LevelStep(
          level: levels[i],
          next: last ? null : levels[i + 1],
          bridgeToNext: last ? null : entry.text('bridgeToNext'),
        ),
      );
      entry.finish();
    }

    final displayTotal = index.has('displayTotal')
        ? index.whole('displayTotal', min: levels.length)
        : levels.length;
    final upcomingPath = index.at('upcomingOpponents');
    final upcoming = <UpcomingOpponent>[];
    if (index.has('upcomingOpponents')) {
      for (final (i, raw) in index.list('upcomingOpponents').indexed) {
        final entry = _Fields('$upcomingPath[$i]', raw);
        final id = entry.text('id');
        final placeholder = entry.has('placeholder') && entry.flag('placeholder');
        if (placeholder == entry.has('hardestCombo')) {
          throw LevelDataError(
            entry.path,
            'needs a hardestCombo, or placeholder: true, and not both',
          );
        }
        upcoming.add(
          UpcomingOpponent(
            id: id,
            name: entry.text('name'),
            level: entry.text('level'),
            hardestCombo: placeholder
                ? null
                : _hardestCombo(entry.child('hardestCombo'), [id]),
          ),
        );
        entry.finish();
      }
    }
    final review = <String, LevelDefinition>{};
    if (index.has('review')) {
      final reviewPath = index.at('review');
      for (final (i, raw) in index.list('review').indexed) {
        if (raw is! String || levels.any((l) => l.id == raw)) {
          throw LevelDataError('$reviewPath[$i]', 'not a level off the campaign: $raw');
        }
        final parsed = jsonDecode(readLevel(raw));
        if (parsed is! Map<String, Object?>) {
          throw LevelDataError('$raw.json', 'expected an object');
        }
        review[raw] = LevelDefinition.fromJson(parsed, path: '$raw.json');
        if (review[raw]!.id != raw) {
          throw LevelDataError('$raw.json', 'holds level "${review[raw]!.id}"');
        }
      }
    }
    index.finish();
    return LevelRegistry._(
      List.unmodifiable(steps),
      displayTotal,
      List.unmodifiable(upcoming),
      Map.unmodifiable(review),
    );
  }

  static Future<LevelRegistry> load(AssetBundle bundle) async {
    final indexText = await bundle.loadString('$folder/index.json');
    final index = jsonDecode(indexText);
    final campaign = index is Map<String, Object?> ? index['campaign'] : null;
    final texts = <String, String>{};
    if (campaign is List<Object?>) {
      for (final entry in campaign) {
        final id = entry is Map<String, Object?> ? entry['level'] : null;
        if (id is String) {
          texts[id] = await bundle.loadString('$folder/$id.json');
        }
      }
    }
    final review = index is Map<String, Object?> ? index['review'] : null;
    if (review is List<Object?>) {
      for (final id in review.whereType<String>()) {
        texts[id] = await bundle.loadString('$folder/$id.json');
      }
    }
    return LevelRegistry.parse(indexText, (id) => texts[id]!);
  }

  static Future<LevelRegistry> loadShipping() => load(rootBundle);
}
