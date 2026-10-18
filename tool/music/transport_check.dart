// Dependency-free behavioral checks, runnable with the preview package config.
// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:io';
import '../../lib/music/score.dart';
import '../../lib/music/transport.dart';

class FakeAudio implements MusicAudioBackend {
  @override
  double nowSeconds = 0;
  @override
  bool ready = true;
  int silences = 0;
  final List<({ScoreNote note, double at, double duration})> scheduled = [];
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {
    scheduled.add((note: note, at: atSeconds, duration: durationSeconds));
  }

  @override
  void silence() {
    silences++;
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

void main() {
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
  stdout.writeln(
    'PASS: score parsing, deduplication, boundary tempo continuity, coalescing, pause/resume, starvation, suspended backend, completion',
  );
}
