import 'crowd_interest.dart';
import 'party_layout.dart';

/// A line of dancers who dance as one with a level's opponent: the galería's
/// step dancers (`plan/levels/mansion-act-two-2026-11-08.md`). Each draws the
/// lead's own drawings at the lead's own beat, a little late, so one set of
/// frames reads as five people and a ripple runs down the line. Nothing here
/// reads back: it only says where each stands and how late they are.
class DanceLine {
  const DanceLine({required this.dancers, this.arch});

  /// "Offset by a frame or two at most": half a beat is two quarter-beat
  /// drawings, the quickest the choreography draws a step.
  static const maxLagBeats = .5;
  static const maxDancers = 8;

  final List<LineDancer> dancers;

  /// The win's arch: when the line splits and raises its arms.
  final LineArch? arch;

  /// How far into the arch they are at the shot's [shotBeat], 0 to 1, with no
  /// speed at either end. Reduced motion holds, then cuts, as everywhere else.
  double archAt(double? shotBeat, {bool reducedMotion = false}) {
    final a = arch;
    if (a == null || shotBeat == null) return 0;
    final u = (shotBeat - a.from) / a.beats;
    if (reducedMotion) return u >= .5 ? 1 : 0;
    return CrowdEngagement.reveal(u);
  }

  /// Where [dancer] stands when the lead stands at [lead].
  PartyPoint place(LineDancer dancer, PartyPoint lead, double arch) {
    final to = dancer.archOffset ?? dancer.offset;
    return PartyPoint(
      lead.x + dancer.offset.x + (to.x - dancer.offset.x) * arch,
      lead.y + dancer.offset.y + (to.y - dancer.offset.y) * arch,
    );
  }
}

class LineDancer {
  const LineDancer({
    required this.offset,
    this.lagBeats = 0,
    this.archOffset,
    this.archMirrored = false,
    this.stature = 1,
  });

  /// From the lead's feet, in plate fractions: the line yields and meets with her.
  final PartyPoint offset;
  final double lagBeats;

  /// From the lead's feet, once the arch has formed.
  final PartyPoint? archOffset;

  /// Facing back along the line in the arch, to reach the dancer opposite.
  final bool archMirrored;

  /// Height against the lead.
  final double stature;
}

class LineArch {
  const LineArch({required this.from, required this.beats});

  /// Beats of the win's shot, counted like every other part of it.
  final double from, beats;
}
