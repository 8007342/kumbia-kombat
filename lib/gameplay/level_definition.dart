import 'dart:ui' as ui;

import 'dart:convert';

import 'package:flutter/services.dart';

import '../music/accent_voice.dart';
import '../music/transport.dart';
import 'crowd_interest.dart';
import 'garden_session.dart';
import 'party_layout.dart';
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

  bool flag(String key) {
    final value = _take(key);
    if (value is bool) return value;
    throw LevelDataError(at(key), 'expected true or false, found $value');
  }

  List<Object?> list(String key) {
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

PartyPoint _point(String path, Object? value) {
  if (value is! List<Object?> || value.length != 2) {
    throw LevelDataError(path, 'expected [x, y], found $value');
  }
  return PartyPoint(
    _number('$path[0]', value[0], min: 0, max: 1),
    _number('$path[1]', value[1], min: 0, max: 1),
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
  });
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
  });
  final FloorTrack? track;

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

class LevelStage {
  const LevelStage({
    required this.heroHome,
    required this.heroEntrance,
    required this.heroRetreat,
    required this.challengers,
    PartyPoint? heroWatch,
    PartyPoint? heroAside,
    this.duet,
  }) : heroWatch = heroWatch ?? heroHome,
       heroAside = heroAside ?? heroWatch ?? heroHome;
  final PartyPoint heroHome;

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

class LevelScenery {
  const LevelScenery({
    required this.lamps,
    required this.plants,
    required this.waiter,
  });

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
  });

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
      challengers: challengers,
    );
    stageFields.finish();

    final crowdFields = fields.child('crowd');
    final crowd = _crowd(id, crowdFields.child('budgets'));
    final guestPath = crowdFields.at('guests');
    final seat = crowdFields.has('seat')
        ? crowdFields.named('seat', PartySeat.values)
        : PartySeat.chair;
    final propSet = crowdFields.has('propSet')
        ? crowdFields.text('propSet')
        : null;
    final seats = <PartySeat>[];
    final anchors = [
      for (final (i, raw) in crowdFields.list('guests').indexed)
        () {
          final path = '$guestPath[$i]';
          // A bare point takes the room's seat; an object may name its own.
          if (raw is List<Object?>) {
            seats.add(seat);
            return onFloor(path, _point(path, raw));
          }
          final guest = _Fields(path, raw);
          seats.add(guest.named('seat', PartySeat.values));
          final at = onFloor(guest.at('at'), guest.point('at'));
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
    final guests = seatedGuestSlots(id, anchors, seats: seats);
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
    );
    sceneryFields.finish();

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
    );
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
      heroWaitFrame: fields.has('heroWaitFrame')
          ? fields.text('heroWaitFrame')
          : 'rear_idle',
      throwsDust: fields.has('dust') ? fields.flag('dust') : true,
    );
    fields.finish();
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
    );
    fields.finish();
    try {
      chart.validate();
    } on ArgumentError catch (error) {
      throw LevelDataError(fields.path, '${error.message}');
    }
    return chart;
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
          );
          prop.finish();
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
  LevelRegistry._(this.campaign, this.displayTotal);

  static const folder = 'levels';

  final List<LevelStep> campaign;

  /// The number the HUD shows after the level number.
  final int displayTotal;

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
    index.finish();
    return LevelRegistry._(List.unmodifiable(steps), displayTotal);
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
    return LevelRegistry.parse(indexText, (id) => texts[id]!);
  }

  static Future<LevelRegistry> loadShipping() => load(rootBundle);
}
