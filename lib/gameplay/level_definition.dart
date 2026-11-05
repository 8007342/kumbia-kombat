import 'dart:ui' as ui;

import 'dart:convert';

import 'package:flutter/services.dart';

import '../music/transport.dart';
import 'crowd_interest.dart';
import 'garden_session.dart';
import 'party_layout.dart';
import 'progression.dart';
import 'rhythm.dart';
import 'exit_shot.dart';
import 'room_departure.dart';

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
  });
  final FloorTrack? track;
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
  });
  final PartyPoint heroHome;

  /// Where the hero starts walking in from during the intro.
  final PartyPoint heroEntrance;

  /// How far a stumble back to the entrance takes the hero, at its peak.
  final PartyPoint heroRetreat;
  final List<LevelChallenger> challengers;

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
    required this.clearedClaim,
    required this.resetLine,
  });
  final String invitation;

  /// May hold a line break for the large results title.
  final String clearedTitle;
  final String clearedClaim;
  final String resetLine;
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
    final stage = LevelStage(
      heroHome: stageMark(stageFields, 'heroHome'),
      heroEntrance: stageMark(stageFields, 'heroEntrance'),
      heroRetreat: stageMark(stageFields, 'heroRetreat'),
      challengers: _challengers(stageFields, stageMark),
    );
    stageFields.finish();

    final crowdFields = fields.child('crowd');
    final crowd = _crowd(id, crowdFields.child('budgets'));
    final guestPath = crowdFields.at('guests');
    final anchors = [
      for (final (i, raw) in crowdFields.list('guests').indexed)
        onFloor('$guestPath[$i]', _point('$guestPath[$i]', raw)),
    ];
    if (anchors.isEmpty || anchors.length > CrowdInterestModel.castSize) {
      throw LevelDataError(
        guestPath,
        'expected 1 to ${CrowdInterestModel.castSize} guests, '
        'found ${anchors.length}',
      );
    }
    final guests = seatedGuestSlots(id, anchors);
    final propPath = crowdFields.at('props');
    final props = [
      ...chairSlotsFor(guests),
      for (final (i, raw) in crowdFields.list('props').indexed)
        _prop(_Fields('$propPath[$i]', raw), onFloor),
    ];
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
      clearedClaim: copyFields.text('clearedClaim'),
      resetLine: copyFields.text('resetLine'),
    );
    copyFields.finish();
    final exitShot = fields.has('exitShot')
        ? _exitShot(fields.child('exitShot'))
        : null;
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
      actors.add(
        ExitShotActor(
          approach: actor.text('approach'),
          impact: actor.text('impact'),
          contact: offset(actor, 'contact'),
          scale: actor.number('scale', min: .1),
          entry: offset(actor, 'entry'),
          recoil: offset(actor, 'recoil'),
        ),
      );
      actor.finish();
    }
    final cuePath = fields.at('cue');
    final cue = <ExitShotCue>[];
    for (final (i, raw) in fields.list('cue').indexed) {
      final note = _Fields('$cuePath[$i]', raw);
      cue.add(
        ExitShotCue(
          note.number('beat', min: 0),
          note.text('track'),
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
    if (kind == PartyPropKind.chair || kind == PartyPropKind.drink) {
      // Chairs come with the guests; drinks belong to the seated poses. The
      // scene would draw neither of these from a prop entry.
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

/// A level's place in the campaign and what links it to the next. Bridges and
/// "next" lines are written from one level to another, so they live here:
/// adding a level changes this list and leaves its neighbours' files alone.
class LevelStep {
  const LevelStep({
    required this.level,
    required this.next,
    required this.bridgeToNext,
    required this.exitLine,
    required this.nextLine,
  });
  final LevelDefinition level;
  final LevelDefinition? next;
  final String? bridgeToNext;
  final String exitLine;
  final String nextLine;
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
          exitLine: entry.text('exitLine'),
          nextLine: entry.text('nextLine'),
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
