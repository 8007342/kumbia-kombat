import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/gameplay/progression.dart';
import 'package:kumbia_kombat/music/game_audio_contract.dart';
import 'package:kumbia_kombat/music/rendered_library.dart';
import 'package:kumbia_kombat/music/rendered_music.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transition_conductor.dart';
import 'package:kumbia_kombat/music/transport.dart';

class FakeVoice implements ClipVoice {
  FakeVoice(this.clip, this.at, this.offset);
  final RenderedClip clip;
  final double at;
  final double offset;
  double? stoppedAt;
  double? fade;
  double fadeIn = 0;
  @override
  void stopAt(double atSeconds, {double fadeSeconds = .01}) {
    stoppedAt = atSeconds;
    fade = fadeSeconds;
  }
}

/// Clock, deck and synth in one fake, with a record of everything asked of them.
class FakeDeck implements MusicAudioBackend, ClipDeck {
  @override
  double nowSeconds = 0;
  @override
  bool ready = true;
  final notReady = <String>{};
  final voices = <FakeVoice>[];
  final notes = <ScoreNote>[];
  int silences = 0;

  @override
  bool clipReady(RenderedClip clip) => !notReady.contains(clip.id);
  @override
  ClipVoice playClip(
    RenderedClip clip, {
    required double atSeconds,
    required double offsetSeconds,
    double fadeInSeconds = 0,
  }) {
    final voice = FakeVoice(clip, atSeconds, offsetSeconds)
      ..fadeIn = fadeInSeconds;
    voices.add(voice);
    return voice;
  }

  @override
  void silence() {
    silences++;
    for (final voice in voices) {
      if (voice.stoppedAt == null || voice.stoppedAt! > nowSeconds) {
        voice.stoppedAt = nowSeconds;
      }
    }
  }

  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {
    notes.add(note);
  }

  /// Where a looping voice's file is at a device time, as the browser would have it.
  double filePosition(FakeVoice voice, double seconds) {
    final clip = voice.clip;
    final played = voice.offset + (seconds - voice.at);
    final end = clip.loopEndSeconds;
    if (end == null || played < end) return played;
    final length = end - clip.startSeconds;
    return clip.startSeconds + (played - clip.startSeconds) % length;
  }
}

RenderedClip take(String id, double bpm, {int bars = 4, double pad = .25}) =>
    RenderedClip(
      id: id,
      bpm: bpm,
      bars: bars,
      beatsPerBar: 4,
      files: const {'opus': 'x.ogg', 'aac': 'x.m4a'},
      startSeconds: pad,
      loopEndSeconds: pad + bars * 4 * 60 / bpm,
    );

RenderedClip segment(String id, double bpm, {int bars = 2}) => RenderedClip(
  id: id,
  bpm: bpm,
  bars: bars,
  beatsPerBar: 4,
  files: const {'opus': 'x.ogg'},
  startSeconds: .25,
  endSeconds: .25 + bars * 4 * 60 / bpm + .2,
);

/// The lawn's order, as the owner ruled it: 144, 160, 136.
RenderedLevel lawn({bool transitions = true}) => RenderedLevel(
  id: 'lawn',
  tierTakes: const ['mid', 'mid', 'high', 'high', 'low'],
  takes: {
    'mid': take('mid', 144),
    'high': take('high', 160),
    'low': take('low', 136),
  },
  transitions: transitions
      ? [
          RenderedTransition(
            from: 'mid',
            to: 'high',
            clip: segment('mid-high', 160),
            entryBar: 2,
          ),
          RenderedTransition(
            from: 'high',
            to: 'low',
            clip: segment('high-low', 136),
          ),
        ]
      : const [],
);

MusicScore synth(List<double> tempos) => MusicScore(
  id: 'song',
  beatsPerBar: 4,
  bars: 8,
  phraseBars: 2,
  tempos: tempos,
  notes: [
    for (var beat = 0; beat < 32; beat++)
      ScoreNote(
        track: 'bass',
        beat: beat.toDouble(),
        pitch: 40,
        duration: .5,
        velocity: 80,
      ),
  ],
);

MusicTransport ladder(FakeDeck deck, {RenderedLevel? level, int entryBar = 0}) {
  final music = level ?? lawn();
  return MusicTransport(
    synth(music.tempos),
    deck,
    loop: true,
    lookaheadSeconds: .3,
    rendered: RenderedPlan.ladder(music, deck, entryBar: entryBar),
  );
}

void run(FakeDeck deck, double until, void Function() pump) {
  while (deck.nowSeconds < until - 1e-9) {
    deck.nowSeconds = math.min(until, deck.nowSeconds + .02);
    pump();
  }
}

void main() {
  _shippedFilesExist();
  group('the manifest', () {
    Map<String, Object?> clip(double bpm, double end) => {
      'bpm': bpm,
      'bars': 24,
      'loopStartSeconds': .25,
      'loopEndSeconds': end,
      'files': {'opus': 'a.ogg', 'aac': 'a.m4a'},
    };

    test('reads ladders whose tempo does not rise, and pads', () {
      final manifest = RenderedManifest.fromJson({
        'schemaVersion': 1,
        'levels': {
          'lawn': {
            'tierTakes': ['mid', 'mid', 'high', 'high', 'low'],
            'takes': {
              'mid': clip(144, .25 + 40),
              'high': clip(160, .25 + 36),
              'low': clip(136, .25 + 96 * 60 / 136),
            },
          },
        },
      });
      final level = manifest.levels['lawn']!;
      expect(level.tempos, [144, 144, 160, 160, closeTo(136, 1e-9)]);
      expect(level.takeForTier(4).fileSecondsAt(0), .25);
      // A beat past the loop is back near its start, on the same grid.
      expect(
        level.takeForTier(0).fileSecondsAt(96 + 2),
        closeTo(.25 + 2 * 60 / 144, 1e-9),
      );
    });

    test('takes its tempo from the loop points, so the clock cannot drift', () {
      final raw = clip(92, .25 + 96 * 60 / 92 + 1 / 48000);
      final parsed = RenderedClip.fromJson('t', 't', raw);
      expect(parsed.lengthSeconds, closeTo(96 * 60 / 92 + 1 / 48000, 1e-9));
    });

    test('refuses loop points that disagree with the stated tempo', () {
      expect(
        () => RenderedClip.fromJson('t', 't', clip(92, 30)),
        throwsA(isA<RenderedManifestError>()),
      );
    });

    test('picks the first format the browser can play', () {
      final parsed = RenderedClip.fromJson('t', 't', clip(92, .25 + 96 * 60 / 92));
      expect(parsed.pathFor((f) => f == 'aac'), 'a.m4a');
      expect(parsed.pathFor((f) => true), 'a.ogg');
      expect(parsed.pathFor((f) => false), isNull);
    });

    test('the shipped manifest parses', () {
      RenderedManifest.fromJson(
        jsonDecode(
          File('assets/music/rendered/manifest.json').readAsStringSync(),
        ),
      );
    });
  });

  group('takes on the clock', () {
    test('the song starts on beat 0, past the pad, and plays no synth notes', () {
      final deck = FakeDeck();
      final transport = ladder(deck)..start();
      run(deck, 1, transport.pump);
      expect(deck.voices.single.clip.id, 'mid');
      expect(deck.voices.single.at, closeTo(.12, 1e-9));
      expect(deck.voices.single.offset, closeTo(.25, 1e-9));
      expect(deck.notes, isEmpty);
    });

    test('the file and the beat agree after many loops', () {
      final deck = FakeDeck();
      final transport = ladder(deck)..start();
      run(deck, 600, transport.pump);
      final voice = deck.voices.single;
      final clip = voice.clip;
      final beat = transport.positionBeats;
      expect(
        deck.filePosition(voice, deck.nowSeconds),
        closeTo(clip.fileSecondsAt(beat), 1e-6),
      );
    });

    test('a tier on the same take changes nothing you could hear', () {
      final deck = FakeDeck();
      final transport = ladder(deck)..start();
      run(deck, 1, transport.pump);
      transport.requestTier(1);
      run(deck, 20, transport.pump);
      expect(transport.currentTier, 1);
      expect(deck.voices, hasLength(1));
      expect(deck.voices.single.stoppedAt, isNull);
    });

    test('a written transition starts on the boundary and lands in time', () {
      final deck = FakeDeck();
      final transport = ladder(deck)..start();
      run(deck, 1, transport.pump);
      final boundary = transport.requestTier(2);
      expect(boundary % 8, 0);
      final at = transport.secondsAt(boundary);
      final landAt = at + 8 * 60 / 160;
      run(deck, landAt + 1, transport.pump);

      expect(deck.voices.map((v) => v.clip.id), ['mid', 'mid-high', 'high']);
      final [outgoing, join, next] = deck.voices;
      // No gap and no doubled beat: each ends where the next begins.
      expect(outgoing.stoppedAt, closeTo(at, 1e-9));
      expect(join.at, closeTo(at, 1e-9));
      expect(join.offset, closeTo(.25, 1e-9));
      expect(join.stoppedAt, closeTo(landAt, 1e-9));
      expect(next.at, closeTo(landAt, 1e-9));
      // The join asked to land on bar 2 of the loop.
      expect(next.offset, closeTo(.25 + 2 * 4 * 60 / 160, 1e-9));
      // The clock runs at the destination from the transition's first beat.
      expect(transport.secondsAt(boundary + 8), closeTo(landAt, 1e-9));
      expect(transport.currentBpm, 160);
    });

    test('a slower take after a faster one is an ordinary change', () {
      final deck = FakeDeck();
      final transport = ladder(deck)..start(tier: 2);
      run(deck, 1, transport.pump);
      final boundary = transport.requestTier(4);
      run(deck, transport.secondsAt(boundary) + 5, transport.pump);
      expect(transport.currentBpm, closeTo(136, 1e-9));
      // Time still moves forward through the slowdown, one beat at a time.
      var previous = -1.0;
      for (var beat = 0.0; beat < boundary + 16; beat += .25) {
        final at = transport.secondsAt(beat);
        expect(at, greaterThan(previous));
        expect(transport.beatAt(at), closeTo(beat, 1e-9));
        previous = at;
      }
    });

    test('a pair with nothing written cuts on the boundary at the new tempo', () {
      final deck = FakeDeck();
      final transport = ladder(deck, level: lawn(transitions: false))..start();
      run(deck, 1, transport.pump);
      final boundary = transport.requestTier(4);
      final at = transport.secondsAt(boundary);
      run(deck, at + 1, transport.pump);
      expect(deck.voices.map((v) => v.clip.id), ['mid', 'low']);
      expect(deck.voices.first.stoppedAt, closeTo(at, 1e-9));
      expect(deck.voices.last.at, closeTo(at, 1e-9));
      expect(deck.voices.last.offset, closeTo(.25, 1e-9));
    });

    test('layered takes change on the same bar, crossfading, with no clip', () {
      final level = RenderedLevel(
        id: 'layers',
        tierTakes: const ['low', 'low', 'mid', 'mid', 'high'],
        takes: {
          'low': take('low', 100),
          'mid': take('mid', 100),
          'high': take('high', 100),
        },
        layerFadeBeats: 2,
      );
      final deck = FakeDeck();
      final transport = ladder(deck, level: level)..start();
      run(deck, 1, transport.pump);
      final boundary = transport.requestTier(2);
      final at = transport.secondsAt(boundary);
      run(deck, at + 1, transport.pump);
      expect(deck.voices.map((v) => v.clip.id), ['low', 'mid']);
      final [outgoing, next] = deck.voices;
      expect(next.at, closeTo(at, 1e-9));
      // The incoming file is at the bar the outgoing one has reached.
      expect(
        next.offset,
        closeTo(level.takes['low']!.fileSecondsAt(boundary), 1e-9),
      );
      expect(next.fadeIn, closeTo(1.2, 1e-9));
      expect(outgoing.fade, closeTo(1.2, 1e-9));
      expect(transport.currentBpm, closeTo(100, 1e-9));
      expect(transport.secondsAt(boundary + 4), closeTo(at + 2.4, 1e-9));
    });

    test('layered takes at another tempo keep the bar, on the new clock', () {
      final level = RenderedLevel(
        id: 'layers',
        tierTakes: const ['low', 'low', 'high', 'high', 'high'],
        takes: {'low': take('low', 100), 'high': take('high', 110)},
        layerFadeBeats: .5,
      );
      final deck = FakeDeck();
      final transport = ladder(deck, level: level)..start();
      run(deck, 1, transport.pump);
      final boundary = transport.requestTier(2);
      run(deck, transport.secondsAt(boundary) + 1, transport.pump);
      expect(
        deck.voices.last.offset,
        closeTo(level.takes['high']!.fileSecondsAt(boundary), 1e-9),
      );
      expect(transport.currentBpm, closeTo(110, 1e-9));
    });

    test('a cut takes the entry written for the bar it leaves on', () {
      final level = RenderedLevel(
        id: 'cuts',
        tierTakes: const ['mid', 'mid', 'high', 'high', 'high'],
        takes: {'mid': take('mid', 144, bars: 8), 'high': take('high', 160, bars: 8)},
        cuts: [
          RenderedCut(
            from: 'mid',
            to: 'high',
            entryBars: const [6, 4, 2, 0],
            fadeOutBeats: 1,
          ),
        ],
      );
      final deck = FakeDeck();
      final transport = ladder(deck, level: level)..start();
      run(deck, 1, transport.pump);
      final boundary = transport.requestTier(2);
      final at = transport.secondsAt(boundary);
      run(deck, at + 1, transport.pump);
      expect(deck.voices.map((v) => v.clip.id), ['mid', 'high']);
      // The first phrase boundary is bar 2, the table's second entry.
      expect(boundary, 8);
      final [outgoing, next] = deck.voices;
      expect(next.offset, closeTo(.25 + 4 * 4 * 60 / 160, 1e-9));
      expect(next.fadeIn, closeTo(RenderedLevel.defaultJoinSeconds, 1e-9));
      expect(outgoing.fade, closeTo(60 / 160, 1e-9));
      // The loop then runs on from there, on the new clock.
      expect(
        deck.filePosition(next, at + 1),
        closeTo(next.offset + 1, 1e-9),
      );
    });

    test('a cut past the end of its take is refused', () {
      expect(
        () => RenderedLevel(
          id: 'cuts',
          tierTakes: const ['mid', 'mid', 'high', 'high', 'high'],
          takes: {'mid': take('mid', 144), 'high': take('high', 160)},
          cuts: [RenderedCut(from: 'mid', to: 'high', entryBars: const [9])],
        ),
        throwsA(isA<RenderedManifestError>()),
      );
    });

    test('a request during a transition waits for it to finish', () {
      final deck = FakeDeck();
      final transport = ladder(deck)..start();
      run(deck, 1, transport.pump);
      final first = transport.requestTier(2);
      run(deck, transport.secondsAt(first) + 1, transport.pump);
      final second = transport.requestTier(0);
      expect(second, greaterThanOrEqualTo(first + 8));
    });

    test('resume lands on the beat it paused on, in loop and in transition', () {
      final deck = FakeDeck();
      final transport = ladder(deck)..start();
      run(deck, 5, transport.pump);
      transport.pause();
      final frozen = transport.positionBeats;
      expect(deck.silences, greaterThan(0));
      deck.nowSeconds += 30;
      transport.resume(leadSeconds: 1);
      run(deck, deck.nowSeconds + .8, transport.pump);
      var voice = deck.voices.last;
      expect(voice.offset, closeTo(voice.clip.fileSecondsAt(frozen), 1e-9));
      expect(voice.at, closeTo(transport.secondsAt(frozen), 1e-9));

      final boundary = transport.requestTier(2);
      run(deck, transport.secondsAt(boundary) + 1, transport.pump);
      expect(transport.currentClip!.id, 'mid-high');
      transport.pause();
      final inside = transport.positionBeats;
      deck.nowSeconds += 10;
      transport.resume(leadSeconds: 1);
      expect(transport.currentBpm, 160);
      final landing = transport.secondsAt(boundary + 8);
      run(deck, landing + .5, transport.pump);
      final resumed = deck.voices[deck.voices.length - 2];
      final last = deck.voices.last;
      expect(resumed.clip.id, 'mid-high');
      expect(
        resumed.offset,
        closeTo(.25 + (inside - boundary) * 60 / 160, 1e-9),
      );
      expect(last.clip.id, 'high');
      expect(last.at, closeTo(landing, 1e-9));
    });

    test('a replay inside the take keeps its place in the song', () {
      final deck = FakeDeck();
      final transport = ladder(deck)..start();
      run(deck, 20, transport.pump);
      transport.seek(20, tier: 0);
      transport.resume(leadSeconds: 1);
      run(deck, deck.nowSeconds + .9, transport.pump);
      expect(
        deck.voices.last.offset,
        closeTo(deck.voices.last.clip.fileSecondsAt(20), 1e-9),
      );
    });

    test('cues still sound over a take, and on the beat', () {
      final deck = FakeDeck();
      final music = lawn();
      final transport = MusicTransport(
        synth(music.tempos).withNotes(const [
          ScoreNote(
            track: 'bump',
            beat: 2,
            pitch: 60,
            duration: .5,
            velocity: 100,
          ),
        ]),
        deck,
        loop: true,
        lookaheadSeconds: .3,
        rendered: RenderedPlan.ladder(music, deck),
      )..start();
      run(deck, 2, transport.pump);
      expect(deck.notes.map((n) => n.track), ['bump']);
    });
  });

  group('when the audio is not there', () {
    test('a take still decoding means the synth at that tier\'s tempo', () {
      final deck = FakeDeck()..notReady.add('high');
      final transport = ladder(deck)..start();
      run(deck, 1, transport.pump);
      final boundary = transport.requestTier(2);
      run(deck, transport.secondsAt(boundary) + 1, transport.pump);
      expect(transport.currentTier, 2);
      expect(transport.currentClip, isNull);
      expect(transport.currentBpm, 160, reason: 'the chart is fair at this tempo');
      expect(
        deck.voices.single.stoppedAt,
        closeTo(transport.secondsAt(boundary), 1e-9),
      );
      expect(deck.notes, isNotEmpty);

      deck.notReady.remove('high');
      transport.pump();
      final join = transport.sections.last;
      expect(join.take, 'high');
      expect(join.beat % 8, 0);
      run(deck, join.seconds + 4, transport.pump);
      expect(transport.currentClip!.id, 'high');
      expect(transport.currentBpm, 160);
    });

    test('the lawn\'s top tier is at 136 whatever the audio is doing', () {
      final manifest = RenderedManifest.fromJson(
        jsonDecode(
          File('assets/music/rendered/manifest.json').readAsStringSync(),
        ),
      );
      final level = manifest.levels['pool-garden']!;
      final ids = level.clips.map((clip) => clip.id).toList();
      for (final missing in <List<String>>[
        const [],
        ['pool-garden/low'],
        ['pool-garden/high-low'],
        ids,
      ]) {
        final deck = FakeDeck()..notReady.addAll(missing);
        final transport = ladder(deck, level: level)..start(tier: 2);
        run(deck, 1, transport.pump);
        final boundary = transport.requestTier(4);
        run(deck, transport.secondsAt(boundary) + 8, transport.pump);
        expect(transport.currentTier, 4);
        expect(transport.currentBpm, closeTo(136, .01), reason: '$missing');
      }
    });

    test('every rich chart is fair at the tempo the manifest gives its tier', () {
      final manifest = RenderedManifest.fromJson(
        jsonDecode(
          File('assets/music/rendered/manifest.json').readAsStringSync(),
        ),
      );
      final levels = LevelRegistry.parse(
        File('levels/index.json').readAsStringSync(),
        (id) => File('levels/$id.json').readAsStringSync(),
      );
      for (final step in levels.campaign) {
        final level = step.level;
        // Garden declares no limits of its own. Its plain chart is as it was, at
        // the tempos it always had, including 326 ms for one limb at 92 BPM.
        if (level.chart.richPatterns.isEmpty) continue;
        // A level whose takes aren't rendered yet plays the synth score, whose
        // tempos its own level test holds the chart to.
        final rendered = manifest.levels[level.id];
        if (rendered == null) continue;
        final tempos = rendered.tempos;
        for (var tier = 0; tier < 5; tier++) {
          final peaks = tier == 4 ? level.rules.finalChallenges : 1;
          for (var peak = 0; peak < peaks; peak++) {
            final index = level.chart.patternIndex(tier, peak);
            expect(
              level.chart.fairnessProblems(index, tempos[tier]),
              isEmpty,
              reason: '${level.id} tier $tier at ${tempos[tier]} BPM',
            );
          }
        }
      }
    });

    test('nothing decoded plays the synth at the takes\' tempos', () {
      final deck = FakeDeck()..notReady.addAll(['mid', 'high', 'low']);
      final transport = ladder(deck)..start();
      run(deck, 2, transport.pump);
      expect(deck.voices, isEmpty);
      expect(deck.notes, isNotEmpty);
      expect(transport.currentBpm, 144);
      expect(
        transport.secondsAt(8) - transport.secondsAt(4),
        closeTo(4 * 60 / 144, 1e-9),
      );
    });

    test('a late take joins a run that started on the synth', () {
      final deck = FakeDeck()..notReady.addAll(['mid']);
      final transport = ladder(deck)..start();
      run(deck, 2, transport.pump);
      deck.notReady.clear();
      transport.requestTier(0);
      deck.notes.clear();
      run(deck, 12, transport.pump);
      expect(transport.currentClip!.id, 'mid');
      expect(deck.voices.single.clip.id, 'mid');
    });

    test('the library records a failure instead of throwing', () async {
      final audio = _FailingAudio();
      final library = RenderedLibrary(
        audio,
        RenderedManifest(levels: {'lawn': lawn()}),
      );
      await library.fetchLevel('lawn');
      await library.decodeStart('lawn');
      await library.decodeRest('lawn');
      await library.decodeExit('lawn');
      expect(library.failures.keys, containsAll(['mid', 'high', 'low']));
      expect(audio.clipReady(lawn().takes['mid']!), isFalse);
    });

    test('a shared job finishes, and can run again', () async {
      final flight = SingleFlight();
      var runs = 0;
      Future<void> job() async {
        runs++;
        await Future<void>.delayed(Duration.zero);
      }

      await Future.wait([flight.run('a', job), flight.run('a', job)]).timeout(
        const Duration(seconds: 2),
      );
      expect(runs, 1);
      await flight.run('a', job).timeout(const Duration(seconds: 2));
      expect(runs, 2);
    });

    test('a shared job that fails reports it, and can run again', () async {
      final flight = SingleFlight();
      await expectLater(
        flight.run('a', () async => throw StateError('bad')),
        throwsStateError,
      );
      await flight.run('a', () async {}).timeout(const Duration(seconds: 2));
    });

    test('a decode that never answers costs that clip and nothing else', () async {
      final audio = _FailingAudio()..hang = true;
      final library = RenderedLibrary(
        audio,
        RenderedManifest(levels: {'lawn': lawn()}),
      )..decodePatience = const Duration(milliseconds: 5);
      await library.decodeRest('lawn').timeout(const Duration(seconds: 5));
      expect(library.failures.keys, containsAll(['mid', 'high', 'low']));
    });

    test('a decode that hangs only costs its patience', () async {
      final audio = _FailingAudio()..hang = true;
      final library = RenderedLibrary(
        audio,
        RenderedManifest(levels: {'lawn': lawn()}),
      );
      await library.decodeStart(
        'lawn',
        patience: const Duration(milliseconds: 10),
      );
    });
  });

  group('the exit', () {
    test('success, bridge and next room each start where the last ended', () {
      final deck = FakeDeck();
      final conductor = TransitionConductor(deck, lookaheadSeconds: .6);
      final source = ladder(deck)..start();
      run(deck, 3, source.pump);
      final successClip = segment('success', 136);
      final bridgeClip = segment('bridge', 100);
      final next = RenderedLevel(
        id: 'bar',
        tierTakes: const ['first', 'first', 'first', 'first', 'first'],
        takes: {'first': take('first', 100, bars: 8)},
      );
      deck.silences = 0;
      final handoff = conductor.handoff(
        source: source,
        success: MusicScore.silent(
          id: 'success',
          beatsPerBar: 4,
          bars: 2,
          bpm: 136,
        ),
        bridge: MusicScore.silent(
          id: 'bridge',
          beatsPerBar: 4,
          bars: 2,
          bpm: 100,
        ),
        nextScore: synth(next.tempos),
        successPlan: RenderedPlan.single(successClip, deck),
        bridgePlan: RenderedPlan.single(bridgeClip, deck),
        nextPlan: RenderedPlan.ladder(next, deck, entryBar: 4),
      );
      run(deck, handoff.nextAtSeconds + 1, conductor.pump);
      final byId = {for (final v in deck.voices) v.clip.id: v};
      expect(byId['mid']!.stoppedAt, closeTo(handoff.exitAtSeconds, 1e-9));
      expect(byId['success']!.at, closeTo(handoff.exitAtSeconds, 1e-9));
      expect(byId['bridge']!.at, closeTo(handoff.bridgeAtSeconds, 1e-9));
      expect(byId['first']!.at, closeTo(handoff.nextAtSeconds, 1e-9));
      expect(byId['first']!.offset, closeTo(.25 + 4 * 4 * 60 / 100, 1e-9));
      expect(deck.silences, 0, reason: 'a musical handoff never silences');
    });

    test('a pause inside the handoff resumes every part in time', () {
      final deck = FakeDeck();
      final conductor = TransitionConductor(deck, lookaheadSeconds: .6);
      final source = ladder(deck)..start();
      run(deck, 3, source.pump);
      final successClip = segment('success', 136);
      final bridgeClip = segment('bridge', 100);
      final handoff = conductor.handoff(
        source: source,
        success: MusicScore.silent(
          id: 'success',
          beatsPerBar: 4,
          bars: 2,
          bpm: 136,
        ),
        bridge: MusicScore.silent(
          id: 'bridge',
          beatsPerBar: 4,
          bars: 2,
          bpm: 100,
        ),
        nextScore: synth(lawn().tempos),
        successPlan: RenderedPlan.single(successClip, deck),
        bridgePlan: RenderedPlan.single(bridgeClip, deck),
        nextPlan: RenderedPlan.ladder(lawn(), deck),
      );
      run(deck, handoff.exitAtSeconds + 1, conductor.pump);
      conductor.pause();
      final frozen = handoff.success.positionBeats;
      deck.nowSeconds += 12;
      conductor.resume(leadSeconds: 1);
      run(deck, handoff.nextAtSeconds + .5, conductor.pump);
      final resumed = deck.voices.lastWhere((v) => v.clip.id == 'success');
      expect(resumed.offset, closeTo(.25 + frozen * 60 / 136, 1e-9));
      final bridge = deck.voices.lastWhere((v) => v.clip.id == 'bridge');
      expect(bridge.at, closeTo(handoff.bridgeAtSeconds, 1e-9));
      expect(
        handoff.nextAtSeconds - handoff.bridgeAtSeconds,
        closeTo(8 * 60 / 100, 1e-9),
      );
      expect(
        deck.voices.first.stoppedAt,
        lessThanOrEqualTo(handoff.exitAtSeconds),
      );
    });

    test('a level clears on the lawn\'s order of tempos', () {
      final deck = FakeDeck();
      final music = lawn();
      final transport = ladder(deck, level: music);
      final session = GardenSession(
        transport,
        deck,
        definition: const FightDefinition('garden', 'Grace', 70, 1, 1, 5),
      )..start();
      final tempos = <double>{};
      void update() {
        transport.pump();
        session.advance();
        tempos.add(transport.currentBpm);
      }

      for (
        var cycle = 0;
        cycle < 20 && session.phase != GardenPhase.cleared;
        cycle++
      ) {
        final start =
            session.chart.introBeats + cycle * session.chart.cycleBeats;
        for (var i = 0; i < session.activeLimbs.length; i++) {
          final when = transport.secondsAt(
            start + session.chart.callBeats + session.chart.offsets[i],
          );
          run(deck, when, update);
          expect(
            session.tap(session.activeLimbs[i]).note,
            isNotNull,
            reason: 'cycle $cycle note $i at ${transport.currentBpm} BPM',
          );
        }
        run(
          deck,
          transport.secondsAt(start + session.chart.cycleBeats - .05),
          update,
        );
      }
      expect(session.phase, GardenPhase.cleared);
      expect(tempos, containsAll(<double>[144, 160]));
      expect(tempos.any((t) => (t - 136).abs() < 1e-6), isTrue);
    });
  });
}

class _FailingAudio implements RenderedAudio {
  bool hang = false;
  @override
  bool clipReady(RenderedClip clip) => false;
  @override
  ClipVoice playClip(
    RenderedClip clip, {
    required double atSeconds,
    required double offsetSeconds,
    double fadeInSeconds = 0,
  }) => throw StateError('nothing decoded');
  @override
  Future<void> fetchClip(RenderedClip clip) async =>
      throw StateError('network down');
  @override
  Future<void> decodeClip(RenderedClip clip) async {
    if (hang) await Future<void>.delayed(const Duration(days: 1));
    throw StateError('bad file');
  }

  @override
  void releaseClip(RenderedClip clip) {}
  @override
  void setMix(RenderedMix mix) {}
  @override
  void clipGainChanged(RenderedClip clip) {}
  @override
  int get decodedBytes => 0;
  @override
  int get compressedBytes => 0;
}

void _shippedFilesExist() {
  test('every campaign clip exists in both formats and fits the budget', () {
    final manifest = RenderedManifest.fromJson(
      jsonDecode(
        File('assets/music/rendered/manifest.json').readAsStringSync(),
      ),
    );
    for (final id in ['garden', 'pool-garden', 'bar']) {
      final level = manifest.levels[id]!;
      expect(level.tempos, hasLength(5));
      var bytes = 0;
      for (final clip in level.clips) {
        for (final format in ['opus', 'aac']) {
          final file = File(clip.files[format]!);
          expect(file.existsSync(), isTrue, reason: file.path);
          if (format == 'opus') bytes += file.lengthSync();
        }
      }
      expect(bytes, lessThan(8 * 1024 * 1024), reason: id);
    }
    // 2026-11-09: the lawn is layered from its 136 take, rising about 3 % a tier
    // to that take's own tempo at the top (owner).
    expect(manifest.levels['pool-garden']!.tempos.map((t) => t.round()), [
      128,
      128,
      132,
      132,
      136,
    ]);
  });
}
