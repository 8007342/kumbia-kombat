/// Oscillator-and-filter recipes for voices a score brief can name. No samples or
/// soundfonts. A track whose voice has no recipe keeps its existing track-based sound,
/// so shipped scores play exactly as before. tool/music/voices.json lists these names.
class VoiceRecipe {
  const VoiceRecipe({
    required this.wave,
    required this.cutoff,
    this.q = .7,
    this.gain = 1,
    this.attack = .006,
    this.sustain = .35,
    this.maxLength,
    this.glideSemitones = 0,
    this.glideSeconds = 0,
    this.drive = false,
  });

  /// Oscillator type: sine, triangle, square or sawtooth.
  final String wave;

  /// Lowpass cutoff in Hz.
  final double cutoff;
  final double q;

  /// Multiplies the note's velocity-derived gain.
  final double gain;

  /// Seconds to reach full level.
  final double attack;

  /// Level reached by the end of the note, as a fraction of full level.
  final double sustain;

  /// Longest note in seconds, for plucked or muted sounds.
  final double? maxLength;

  /// Each note slides up into its pitch from this many semitones below.
  final double glideSemitones;
  final double glideSeconds;

  /// Passes through the shared soft-clipping curve. This costs one extra node per
  /// note, so it stays limited to voices that need the grit.
  final bool drive;
}

const voiceRecipes = <String, VoiceRecipe>{
  'nylonPluck': VoiceRecipe(
    wave: 'triangle',
    cutoff: 2200,
    gain: .85,
    sustain: .12,
    maxLength: .6,
  ),
  'pedalSteel': VoiceRecipe(
    wave: 'triangle',
    cutoff: 2800,
    q: 1.2,
    attack: .03,
    sustain: .7,
    glideSemitones: 1,
    glideSeconds: .09,
  ),
  'subDrone': VoiceRecipe(
    wave: 'sine',
    cutoff: 320,
    gain: 1.4,
    attack: .12,
    sustain: .9,
  ),
  'chugGuitar': VoiceRecipe(
    wave: 'sawtooth',
    cutoff: 1500,
    q: 1.1,
    gain: .55,
    attack: .003,
    sustain: .25,
    maxLength: .22,
    drive: true,
  ),
  'montunoKeys': VoiceRecipe(
    wave: 'triangle',
    cutoff: 3200,
    q: 1,
    attack: .003,
    sustain: .2,
    maxLength: .4,
  ),
  'synthLead': VoiceRecipe(
    wave: 'square',
    cutoff: 2600,
    q: 2,
    gain: .6,
    attack: .008,
    sustain: .55,
    glideSemitones: .5,
    glideSeconds: .04,
  ),
  'synthArp': VoiceRecipe(
    wave: 'sawtooth',
    cutoff: 2400,
    q: 3,
    gain: .45,
    attack: .002,
    sustain: .1,
    maxLength: .16,
  ),
  'warmPad': VoiceRecipe(
    wave: 'sawtooth',
    cutoff: 900,
    gain: .4,
    attack: .18,
    sustain: .8,
  ),
};
