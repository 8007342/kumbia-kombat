// Dependency-free behavioral checks, runnable with the preview package config.
// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:io';
import '../../lib/music/score.dart';
import '../../lib/music/game_audio.dart';
import '../../lib/music/transport.dart';

class FakeAudio implements MusicAudioBackend {
  @override
  double nowSeconds = 0;
  @override
  bool ready = true;
  int silences = 0;
  final List<double> queued = [];
  final List<({ScoreNote note, double at, double duration})> scheduled = [];
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {
    scheduled.add((note: note, at: atSeconds, duration: durationSeconds));
    queued.add(atSeconds);
  }

  @override
  void silence() {
    silences++;
    queued.clear();
  }
}

void check(bool condition, String description) {
  if (!condition) throw StateError(description);
}

bool close(double a, double b) => (a - b).abs() < .000001;
void tick(MusicTransport transport, FakeAudio audio, double target) {
  while (audio.nowSeconds < target) {
    audio.nowSeconds = (audio.nowSeconds + .02).clamp(0.0, target).toDouble();
    transport.pump();
  }
}

Future<void> main() async {
  final score = MusicScore(
    id: 'test',
    beatsPerBar: 4,
    bars: 8,
    phraseBars: 2,
    tempos: [120, 126, 132, 138, 144],
    notes: List.generate(
      64,
      (i) => ScoreNote(
        track: 'bass',
        beat: i * .5,
        pitch: 48,
        duration: .25,
        velocity: 70,
      ),
    ),
  );
  final audio = FakeAudio();
  final transport = MusicTransport(score, audio);
  transport.start();
  tick(transport, audio, .2);
  check(
    audio.scheduled.length == 1,
    'Only the first attack should be scheduled',
  );
  final scheduled = audio.scheduled.length;
  transport.pump();
  transport.pump();
  check(
    audio.scheduled.length == scheduled,
    'Repeated pumps must not duplicate notes',
  );
  final boundary = transport.requestTier(4);
  check(boundary == 8, 'Changes land at two-bar boundary');
  check(
    close(transport.secondsAt(8), 4.12),
    'Old tempo reaches boundary without a jump',
  );
  check(
    close(transport.secondsAt(12), 4.12 + 4 * 60 / 144),
    'New tempo applies after boundary',
  );
  transport.requestTier(2);
  check(
    transport.sections.length == 2 && transport.sections.last.tier == 2,
    'Pending changes coalesce',
  );
  tick(transport, audio, 4.3);
  check(
    transport.currentTier == 2,
    'Tier becomes active only when audio reaches boundary',
  );
  check(transport.droppedNotes == 0, 'Normal pumping must not lose notes');
  final frozen = transport.positionBeats;
  transport.pause();
  audio.nowSeconds += 10;
  check(
    close(frozen, transport.positionBeats),
    'Pause freezes musical position',
  );
  transport.resume(leadSeconds: 1);
  check(
    close(transport.positionBeats, frozen),
    'Resume count-in must preserve frozen beat',
  );
  tick(transport, audio, audio.nowSeconds + 1.2);
  check(
    transport.positionBeats > frozen,
    'Resume advances from the paused beat',
  );
  final safeBeforeGap = transport.positionBeats;
  audio.nowSeconds += 2;
  transport.pump();
  check(
    transport.state == TransportState.paused,
    'Scheduling starvation pauses explicitly',
  );
  check(
    transport.positionBeats < safeBeforeGap + 1,
    'Starvation must not skip seconds of unheard music',
  );
  audio.ready = false;
  var rejected = false;
  try {
    transport.resume();
  } on StateError {
    rejected = true;
  }
  check(rejected, 'Suspended audio cannot silently resume transport');
  audio.ready = true;
  transport.start(tier: 4);
  tick(transport, audio, audio.nowSeconds + 15);
  check(
    transport.state == TransportState.completed,
    'Written score completes exactly once',
  );
  check(close(transport.positionBeats, 32), 'Completion holds final beat');
  check(
    audio.scheduled.every((n) => n.duration > 0 && n.at >= 0),
    'All scheduled notes have valid timing',
  );
  for (final file in Directory(
    'assets/music/scores',
  ).listSync().whereType<File>()) {
    final parsed = MusicScore.fromJson(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );
    check(
      parsed.notes.isNotEmpty,
      'Generated score parses into transport model',
    );
  }
  final loopingAudio = FakeAudio();
  final looping = MusicTransport(score, loopingAudio, loop: true);
  looping.start();
  tick(looping, loopingAudio, 15.5);
  final seam = looping.requestTier(4);
  check(seam == 32, 'Tier request near EOF must target the first loop seam');
  check(
    close(looping.secondsAt(32), 16.12),
    'Loop seam keeps the preceding tempo time',
  );
  check(
    close(looping.secondsAt(36), 16.12 + 4 * 60 / 144),
    'New-loop tempo maps continuously',
  );
  tick(looping, loopingAudio, 20);
  check(
    looping.state == TransportState.playing && looping.positionBeats > 32,
    'Loop EOF must preserve playing state and absolute beat position',
  );
  final seamAttacks = loopingAudio.scheduled
      .where((n) => close(n.at, 16.12))
      .toList();
  check(
    seamAttacks.length == 1 && seamAttacks.single.note.beat == 0,
    'First note of next form plays exactly once at the seam',
  );
  check(
    looping.currentTier == 4 && looping.droppedNotes == 0,
    'Tempo change across seam must commit without late notes',
  );
  tick(looping, loopingAudio, looping.secondsAt(97));
  check(
    looping.positionBeats >= 97 &&
        close(looping.scorePositionBeats, looping.positionBeats % 32),
    'Several loop iterations preserve absolute and score-local positions',
  );
  for (var i = 1; i < loopingAudio.scheduled.length; i++) {
    check(
      loopingAudio.scheduled[i].at > loopingAudio.scheduled[i - 1].at,
      'No duplicated or out-of-order attacks across repeated loops',
    );
  }
  final cancellations = loopingAudio.silences;
  looping.seek(40.75, tier: 1);
  check(
    loopingAudio.silences == cancellations + 1 && loopingAudio.queued.isEmpty,
    'Seek cancels all pending and sounding voices',
  );
  check(
    looping.state == TransportState.paused &&
        close(looping.positionBeats, 40.75) &&
        looping.currentTier == 1,
    'Seek accepts an arbitrary absolute beat and checkpoint tier',
  );
  looping.resume(leadSeconds: .3);
  check(
    looping.countingIn && close(looping.positionBeats, 40.75),
    'Seeking then resuming holds the target through count-in',
  );
  final resumeSeconds = loopingAudio.nowSeconds;
  tick(looping, loopingAudio, resumeSeconds + .6);
  check(
    !looping.countingIn && looping.positionBeats > 40.75,
    'Count-in ends on the audio clock',
  );
  check(
    looping.requestTier(3) == 48,
    'Tier request after seek uses absolute phrase grid',
  );
  final beforePause = looping.positionBeats;
  looping.pause();
  check(loopingAudio.queued.isEmpty, 'Pause cancels future loop attacks');
  loopingAudio.nowSeconds += 5;
  looping.resume(leadSeconds: .2);
  check(
    close(looping.positionBeats, beforePause) &&
        looping.sections.last.beat == 48 &&
        looping.sections.last.tier == 3,
    'Pending boundary intent survives ordinary pause/resume',
  );
  tick(looping, loopingAudio, looping.secondsAt(49));
  check(
    looping.currentTier == 3,
    'Preserved pending tier commits after resume',
  );
  looping.restartPhrase(tier: 2, leadSeconds: .5);
  check(
    close(looping.positionBeats, 48) &&
        looping.currentTier == 2 &&
        looping.countingIn,
    'Explicit phrase restart rewinds to the current phrase and restored tier',
  );
  check(
    looping.sections.length == 1,
    'Phrase restart clears obsolete pending tier changes',
  );
  final beforeStarvation = looping.positionBeats;
  tick(looping, loopingAudio, loopingAudio.nowSeconds + .6);
  loopingAudio.nowSeconds += 5;
  looping.pump();
  check(
    looping.state == TransportState.paused &&
        looping.positionBeats < beforeStarvation + 2,
    'Loop starvation pauses at the last scheduled beat, not the late wall clock',
  );

  final native = createGameAudio();
  var unsupported = false;
  try {
    await native.activate();
  } on UnsupportedError {
    unsupported = true;
  }
  check(
    unsupported && !native.ready,
    'Native facade rejects unsupported audio, never silent scoring',
  );
  await native.dispose();
  await native.dispose();

  stdout.writeln(
    'PASS: score parsing, deduplication, boundary tempo continuity, coalescing, pause/resume, starvation, suspended backend, completion, repeated loop seams, loop-boundary tempo, absolute seek/cancel, phrase restart, preserved pending tier, conditional native facade',
  );
}
