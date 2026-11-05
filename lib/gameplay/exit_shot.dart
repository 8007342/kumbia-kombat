import 'dart:math' as math;
import 'dart:ui' as ui;

/// Data for the moment a level is won: Mācron's celebration, his walk to the
/// challenger and a close-up on the beat. Beats count from the first beat of
/// the success score and run on into the bridge, so nothing here can move music.
class ExitShot {
  const ExitShot({
    required this.plate,
    required this.celebrateUntil,
    required this.walkFrom,
    required this.walkTo,
    required this.heroStep,
    required this.closeupFrom,
    required this.contactBeat,
    required this.closeupTo,
    required this.contactPoint,
    required this.actors,
    required this.cue,
  });

  final String plate;
  final double celebrateUntil;
  final double walkFrom;
  final double walkTo;

  /// Where he stands for the close-up, in floor coordinates.
  final ui.Offset heroStep;
  final double closeupFrom;
  final double contactBeat;
  final double closeupTo;

  /// Where the two meet, as a fraction of the screen.
  final ui.Offset contactPoint;
  final List<ExitShotActor> actors;
  final List<ExitShotCue> cue;

  Iterable<String> get images => [
    plate,
    for (final actor in actors) ...[actor.approach, actor.impact],
  ];

  bool closeupAt(double beat) => beat >= closeupFrom && beat < closeupTo;

  /// How far the hero has gone from home to his step, 0 to 1.
  double stepAt(double beat) =>
      _smooth(((beat - walkFrom) / (walkTo - walkFrom)).clamp(0.0, 1.0));

  bool walkingAt(double beat) => beat >= walkFrom && beat < walkTo;

  /// Departure route progress: it starts once the close-up has returned to the
  /// wide view, and finishes with the bridge at [endBeat].
  double routeAt(double beat, double endBeat) =>
      ((beat - closeupTo) / (endBeat - closeupTo)).clamp(0.0, 1.0);

  /// Actor positions and frames at [beat]. Pure, so a test can check the hit.
  List<ExitShotPlacement> sample(double beat, {required bool reducedMotion}) {
    final after = beat - contactBeat;
    final approach = reducedMotion
        ? 1.0
        : ((beat - closeupFrom) / (contactBeat - closeupFrom)).clamp(0.0, 1.0);
    // Accelerate into the hit, then give a little back.
    final closing = 1 - approach * approach;
    final recoil = after <= 0 || reducedMotion
        ? 0.0
        : _easeOut((after / (closeupTo - contactBeat)).clamp(0.0, 1.0));
    final striking = after >= 0 && after < .4;
    return [
      for (final actor in actors)
        ExitShotPlacement(
          actor,
          striking || reducedMotion ? actor.impact : actor.approach,
          ui.Offset(
            actor.entry.dx * closing + actor.recoil.dx * recoil,
            actor.entry.dy * closing + actor.recoil.dy * recoil,
          ),
        ),
    ];
  }

  /// Dust thrown at the contact: four art pixels flying out for half a beat.
  List<ExitShotMote> motes(double beat, {required bool reducedMotion}) {
    final age = beat - contactBeat;
    if (age < 0 || age >= .5 || reducedMotion) return const [];
    final t = age / .5;
    const headings = [-2.5, -1.2, .9, 2.2];
    return [
      for (final (i, heading) in headings.indexed)
        ExitShotMote(
          ui.Offset(math.cos(heading), math.sin(heading)) *
              (10 + 26 * _easeOut(t)),
          i.isEven ? 3 : 2,
          1 - t,
        ),
    ];
  }

  static double _smooth(double t) => t * t * (3 - 2 * t);
  static double _easeOut(double t) => 1 - (1 - t) * (1 - t);
}

class ExitShotActor {
  const ExitShotActor({
    required this.approach,
    required this.impact,
    required this.contact,
    required this.scale,
    required this.entry,
    required this.recoil,
  });
  final String approach;
  final String impact;

  /// The art pixel that meets the other actor.
  final ui.Offset contact;

  /// World units per art pixel. Fixed, so the pixels hold still in motion.
  final double scale;
  final ui.Offset entry;
  final ui.Offset recoil;
}

class ExitShotPlacement {
  const ExitShotPlacement(this.actor, this.image, this.offset);
  final ExitShotActor actor;
  final String image;
  final ui.Offset offset;
}

class ExitShotMote {
  const ExitShotMote(this.offset, this.size, this.opacity);
  final ui.Offset offset;
  final double size;
  final double opacity;
}

class ExitShotCue {
  const ExitShotCue(this.beat, this.track, this.pitch, this.velocity);
  final double beat;
  final String track;
  final int pitch;
  final int velocity;
}

/// One level-win flourish, beat by beat. Plays until the close-up cuts in.
class Celebration {
  const Celebration(this.frame, this.hop);
  final String frame;

  /// Height above the floor, in units of his own height.
  final double hop;

  static const _spin = [
    'spin_front',
    'profile',
    'spin_rear',
    'rear_finish',
    'spin_rear',
    'profile',
    'spin_front',
    'front_idle',
  ];

  /// [age] is beats since the win. Eight beats, then it repeats: a crouch, two
  /// jumps with the arms up, a full spin, then a groove to the side.
  factory Celebration.at(double age, {required bool reducedMotion}) {
    if (reducedMotion) return const Celebration('arm_sweep', 0);
    final t = age % 8;
    double arc(double from, double length, double height) {
      final u = ((t - from) / length).clamp(0.0, 1.0);
      return height * 4 * u * (1 - u);
    }

    if (t < .5) return const Celebration('anticipate', 0);
    if (t < 1.5) return Celebration('left_hand', arc(.5, 1, .22));
    if (t < 2.5) return Celebration('right_hand', arc(1.5, 1, .22));
    if (t < 3) return const Celebration('anticipate', 0);
    if (t < 5) {
      final frame = _spin[(((t - 3) / 2) * _spin.length).floor().clamp(0, 7)];
      return Celebration(frame, arc(3, 2, .3));
    }
    if (t < 7) {
      return Celebration(
        (t - 5) < 1 ? 'groove_left' : 'groove_right',
        arc(5 + ((t - 5).floorToDouble()), 1, .1),
      );
    }
    return Celebration('arm_sweep', arc(7, 1, .16));
  }
}
