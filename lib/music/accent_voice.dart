/// One-shot sounds for cinematic moments, as pure data so a test can read them.
///
/// An exit shot's `cue` names one of these as its `track`. Its `pitch` transposes
/// the patch around middle C and its `velocity` scales it. They run through the
/// ordinary score queue, so pause, hidden tab and mute still stop them, but they
/// keep their own length and a louder bus: at the old drum voices' level a hit
/// was only one more drum, under the score's own kick on the same beat.
library;

import 'dart:math' as math;

/// The song's own levels. The synth uses these, and tests compare against them.
const musicMasterGain = .32;
const musicVoiceGain = .18;

/// The accents' bus, in place of [musicMasterGain].
const accentBusGain = .4;

class AccentLayer {
  const AccentLayer({
    required this.shape,
    required this.fromHz,
    required this.toHz,
    required this.seconds,
    required this.gain,
    required this.filter,
    required this.filterHz,
    this.q = .7,
    this.sweep = .09,
  });

  /// `sine`, `triangle`, `square`, or `noise`, which ignores the two pitches.
  final String shape;
  final double fromHz;
  final double toHz;

  /// How long the pitch takes to move from [fromHz] to [toHz].
  final double sweep;
  final double seconds;
  final double gain;

  /// A Web Audio filter type: `lowpass` or `bandpass`.
  final String filter;
  final double filterHz;
  final double q;

  bool get noise => shape == 'noise';
}

const accentPatches = <String, List<AccentLayer>>{
  // Knuckles: a thump to feel, a knock a phone speaker can play, a crack for the
  // moment of contact and a trace of steel for Mācron's hand.
  'bump': [
    AccentLayer(
      shape: 'sine',
      fromHz: 190,
      toHz: 62,
      seconds: .17,
      gain: .55,
      filter: 'lowpass',
      filterHz: 900,
    ),
    AccentLayer(
      shape: 'triangle',
      fromHz: 520,
      toHz: 180,
      sweep: .05,
      seconds: .08,
      gain: .4,
      filter: 'lowpass',
      filterHz: 2400,
    ),
    AccentLayer(
      shape: 'noise',
      fromHz: 0,
      toHz: 0,
      seconds: .05,
      gain: .45,
      filter: 'bandpass',
      filterHz: 2200,
      q: .8,
    ),
    AccentLayer(
      shape: 'square',
      fromHz: 1480,
      toHz: 1480,
      seconds: .22,
      gain: .05,
      filter: 'bandpass',
      filterHz: 1800,
      q: 2,
    ),
  ],
  // A bubble: the pitch jumps upward as it lets go, which is what reads as glug.
  'glug': [
    AccentLayer(
      shape: 'sine',
      fromHz: 150,
      toHz: 420,
      sweep: .1,
      seconds: .14,
      gain: .8,
      filter: 'lowpass',
      filterHz: 1400,
    ),
    AccentLayer(
      shape: 'triangle',
      fromHz: 300,
      toHz: 840,
      sweep: .1,
      seconds: .1,
      gain: .3,
      filter: 'lowpass',
      filterHz: 2200,
    ),
  ],
  // A peck on a cheek: a small round pop that lifts, and a warm trace after it.
  // Well under the others, since this is a tender moment and not a hit.
  'peck': [
    AccentLayer(
      shape: 'sine',
      fromHz: 620,
      toHz: 980,
      sweep: .05,
      seconds: .09,
      gain: .45,
      filter: 'lowpass',
      filterHz: 2400,
    ),
    AccentLayer(
      shape: 'noise',
      fromHz: 0,
      toHz: 0,
      seconds: .025,
      gain: .1,
      filter: 'bandpass',
      filterHz: 3000,
      q: .9,
    ),
    AccentLayer(
      shape: 'sine',
      fromHz: 1760,
      toHz: 1760,
      seconds: .28,
      gain: .08,
      filter: 'lowpass',
      filterHz: 4000,
    ),
  ],
  // Ivory on ivory: a very short, hard knock with two high partials that don't
  // share a pitch, and a tick for the contact. All of it is in a phone's range.
  'clack': [
    AccentLayer(
      shape: 'sine',
      fromHz: 2650,
      toHz: 2350,
      sweep: .02,
      seconds: .05,
      gain: .55,
      filter: 'lowpass',
      filterHz: 7000,
    ),
    AccentLayer(
      shape: 'triangle',
      fromHz: 1180,
      toHz: 980,
      sweep: .02,
      seconds: .045,
      gain: .4,
      filter: 'bandpass',
      filterHz: 1400,
      q: 1.2,
    ),
    AccentLayer(
      shape: 'noise',
      fromHz: 0,
      toHz: 0,
      seconds: .012,
      gain: .4,
      filter: 'bandpass',
      filterHz: 4200,
      q: .7,
    ),
  ],
  // Chalk on a cue tip: a soft dry twist, a narrow rasp that lifts a little. Small,
  // since it's dabbed on a friend's antenna.
  'chalk': [
    AccentLayer(
      shape: 'noise',
      fromHz: 0,
      toHz: 0,
      seconds: .14,
      gain: .4,
      filter: 'bandpass',
      filterHz: 3400,
      q: 2.5,
    ),
    AccentLayer(
      shape: 'sine',
      fromHz: 2300,
      toHz: 3100,
      sweep: .1,
      seconds: .12,
      gain: .16,
      filter: 'lowpass',
      filterHz: 6000,
    ),
  ],
  // A glass changing hands: two high partials that don't share a pitch, and a tick.
  'clink': [
    AccentLayer(
      shape: 'sine',
      fromHz: 2100,
      toHz: 2100,
      seconds: .2,
      gain: .25,
      filter: 'lowpass',
      filterHz: 6000,
    ),
    AccentLayer(
      shape: 'sine',
      fromHz: 3170,
      toHz: 3170,
      seconds: .13,
      gain: .2,
      filter: 'lowpass',
      filterHz: 6000,
    ),
    AccentLayer(
      shape: 'noise',
      fromHz: 0,
      toHz: 0,
      seconds: .02,
      gain: .25,
      filter: 'bandpass',
      filterHz: 5200,
      q: .6,
    ),
  ],
  // A nod of respect: a low, dry knock with a little room in it. Under the bump and
  // the peck on purpose, so it stays cool: nobody here is impressed out loud.
  'nod': [
    AccentLayer(
      shape: 'sine',
      fromHz: 240,
      toHz: 120,
      sweep: .06,
      seconds: .16,
      gain: .42,
      filter: 'lowpass',
      filterHz: 1100,
    ),
    AccentLayer(
      shape: 'noise',
      fromHz: 0,
      toHz: 0,
      seconds: .018,
      gain: .12,
      filter: 'bandpass',
      filterHz: 1700,
      q: .8,
    ),
    AccentLayer(
      shape: 'triangle',
      fromHz: 480,
      toHz: 480,
      seconds: .24,
      gain: .06,
      filter: 'lowpass',
      filterHz: 1500,
    ),
  ],
};

/// The tracks an exit shot may name: the score's voices, and the accents.
const scoreTracks = {'pulse', 'bass', 'guitar', 'brass', 'lead', 'answer'};
bool isAccentTrack(String track) => accentPatches.containsKey(track);
bool isCueTrack(String track) =>
    scoreTracks.contains(track) || isAccentTrack(track);

/// Multiplies a patch's pitches: middle C leaves it as written.
double accentTranspose(int pitch) => math.pow(2, (pitch - 60) / 12).toDouble();

/// The most a patch can reach at the output, if every layer peaks together.
double accentPeak(String track, int velocity) =>
    accentPatches[track]!.fold(0.0, (sum, layer) => sum + layer.gain) *
    velocity /
    127 *
    accentBusGain;
