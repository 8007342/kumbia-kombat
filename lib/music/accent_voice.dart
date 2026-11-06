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
