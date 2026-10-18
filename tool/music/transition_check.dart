// ignore_for_file: avoid_relative_lib_imports
import 'dart:io';
import 'dart:convert';
import '../../lib/music/score.dart';
import '../../lib/music/transport.dart';
import '../../lib/music/transition_conductor.dart';
import 'transport_check.dart' show FakeAudio, check, close, tick;

MusicScore mini(String id, {double bpm = 120}) => MusicScore(
  id: id,
  beatsPerBar: 4,
  bars: 2,
  phraseBars: 2,
  tempos: List.filled(5, bpm),
  notes: List.generate(
    8,
    (i) => ScoreNote(
      track: id,
      beat: i.toDouble(),
      pitch: 60,
      duration: .5,
      velocity: 70,
    ),
  ),
);
void advance(TransitionConductor conductor, FakeAudio audio, double target) {
  while (audio.nowSeconds < target) {
    audio.nowSeconds = (audio.nowSeconds + .02).clamp(0.0, target).toDouble();
    conductor.pump();
  }
}

void main() {
  final sourceScore = mini('source');
  final successScore = mini('success');
  final bridgeScore = mini('bridge', bpm: 100);
  final nextScore = mini('next', bpm: 100);
  final audio = FakeAudio();
  final source = MusicTransport(sourceScore, audio, loop: true);
  source.start();
  tick(source, audio, .3);
  final conductor = TransitionConductor(audio, lookaheadSeconds: .3);
  final handoff = conductor.handoff(
    source: source,
    success: successScore,
    bridge: bridgeScore,
    nextScore: nextScore,
  );
  check(
    handoff.nextTransport.lookaheadSeconds == .3 &&
        handoff.bridge.lookaheadSeconds == .3,
    'Conductor propagates its scheduling lookahead to every segment',
  );
  final cancellationCount = audio.silences;
  check(
    close(handoff.exitAtSeconds, 4.12),
    'Source exits on the next uncommitted phrase boundary',
  );
  check(
    close(handoff.bridgeAtSeconds, 8.12),
    'Success starts exactly at source exit and occupies its written duration',
  );
  check(
    close(handoff.nextAtSeconds, 12.92),
    'Bridge and destination meet on one device timestamp',
  );
  check(
    handoff.nextTransport.countingIn,
    'Destination does not accept input while exit and bridge play',
  );
  advance(conductor, audio, handoff.nextAtSeconds + 1);
  check(
    audio.silences == cancellationCount,
    'Handoffs and finite segment completion never silence the common backend',
  );
  check(
    source.state == TransportState.completed &&
        handoff.success.state == TransportState.completed &&
        handoff.bridge.state == TransportState.completed,
    'Retired segments complete independently',
  );
  check(
    handoff.nextTransport.state == TransportState.playing &&
        !handoff.nextTransport.countingIn,
    'Destination enters its looping form without restart',
  );
  for (final boundary in [
    (track: 'success', time: handoff.exitAtSeconds),
    (track: 'bridge', time: handoff.bridgeAtSeconds),
    (track: 'next', time: handoff.nextAtSeconds),
  ]) {
    final attacks = audio.scheduled.where(
      (e) => e.note.track == boundary.track && close(e.at, boundary.time),
    );
    check(
      attacks.length == 1,
      'Each boundary gets exactly one destination downbeat, with no time gap',
    );
  }
  check(
    audio.scheduled
        .where((e) => e.note.track == 'source')
        .every((e) => e.at < handoff.exitAtSeconds),
    'Retired source never schedules attacks into the success phrase',
  );

  // Reuse the same conductor for another complete handoff after destination entry.
  final second = conductor.handoff(
    source: handoff.nextTransport,
    success: mini('second_success'),
    bridge: mini('second_bridge'),
    nextScore: mini('third'),
  );
  advance(conductor, audio, second.nextAtSeconds + .2);
  check(
    audio.silences == cancellationCount &&
        second.nextTransport.state == TransportState.playing,
    'Successive handoffs discard old decks without cancelling destination voices',
  );
  final finish = conductor.finish(
    source: second.nextTransport,
    success: mini('final_tag'),
  );
  advance(conductor, audio, finish.endAtSeconds + .02);
  check(
    conductor.completed && audio.silences == cancellationCount,
    'Final success tag completes naturally, without blanket backend silence',
  );

  // Pause while the success is active: every future segment moves by one offset.
  final pa = FakeAudio();
  final ps = MusicTransport(sourceScore, pa, loop: true)..start();
  tick(ps, pa, .3);
  final pc = TransitionConductor(pa);
  final ph = pc.handoff(
    source: ps,
    success: successScore,
    bridge: bridgeScore,
    nextScore: nextScore,
  );
  advance(pc, pa, ph.exitAtSeconds + .5);
  final oldNext = ph.nextAtSeconds, oldBridge = ph.bridgeAtSeconds;
  final beforePause = pa.silences;
  pc.pause();
  check(
    pc.isPaused && pa.silences == beforePause + 1 && pa.queued.isEmpty,
    'One coordinated pause flushes all current and future queued voices',
  );
  final frozen = ph.success.positionBeats;
  pa.nowSeconds += 3;
  pc.resume(leadSeconds: 1);
  check(
    pc.isPlaying && close(ph.success.positionBeats, frozen),
    'Active success phrase holds its beat through count-in',
  );
  check(
    close(ph.nextAtSeconds, oldNext + 4) &&
        close(ph.bridgeAtSeconds, oldBridge + 4),
    'Remaining bridge and destination anchors shift together after pause',
  );
  advance(pc, pa, ph.nextAtSeconds + .2);
  check(
    !ph.nextTransport.countingIn && pa.silences == beforePause + 1,
    'Resumed handoff reaches destination with no extra cancellation or inserted stop',
  );
  check(
    [
      ps,
      ph.success,
      ph.bridge,
      ph.nextTransport,
    ].every((t) => t.droppedNotes == 0),
    'Normal transition pumping never drops attacks',
  );

  // A pause before source retirement must preserve the retirement deadline too.
  final ea = FakeAudio();
  final es = MusicTransport(sourceScore, ea, loop: true)..start();
  tick(es, ea, .3);
  final ec = TransitionConductor(ea);
  final eh = ec.handoff(
    source: es,
    success: successScore,
    bridge: bridgeScore,
    nextScore: nextScore,
  );
  final oldExit = eh.exitAtSeconds;
  ec.pause();
  ea.nowSeconds += 2;
  ec.resume(leadSeconds: .5);
  check(
    close(eh.exitAtSeconds, oldExit + 2.5),
    'Source retirement shifts with all successor anchors',
  );
  advance(ec, ea, eh.nextAtSeconds + .2);
  check(
    ec.isPlaying && !eh.nextTransport.countingIn,
    'Early paused chain still reaches destination',
  );
  final qa = FakeAudio();
  final qs = MusicTransport(sourceScore, qa, loop: true)..start();
  tick(qs, qa, .3);
  final qc = TransitionConductor(qa, lookaheadSeconds: .3);
  final qh = qc.handoff(
    source: qs,
    success: successScore,
    bridge: bridgeScore,
    nextScore: nextScore,
  );
  advance(qc, qa, qh.bridgeAtSeconds - .05);
  check(
    qa.scheduled.any((e) => e.note.track == 'bridge' && e.at > qa.nowSeconds),
    'Test reaches a boundary where future bridge attacks are already queued',
  );
  qc.pause();
  check(
    qa.queued.isEmpty,
    'Coordinated pause also cancels already queued future-segment attacks',
  );
  qa.nowSeconds += .5;
  qc.resume(leadSeconds: .2);
  final shiftedBridge = qh.bridgeAtSeconds;
  advance(qc, qa, shiftedBridge + .1);
  check(
    qa.scheduled
            .where(
              (e) => e.note.track == 'bridge' && close(e.at, shiftedBridge),
            )
            .length ==
        1,
    'Paused future segment is queued exactly once at its shifted boundary',
  );
  // Real bar score at a nonzero device epoch exposes inverse-tempo rounding:
  // secondsAt(128) maps back to 128.00000000000003 at 112 BPM.
  MusicScore loadScore(String id) => MusicScore.fromJson(
    jsonDecode(File('assets/music/scores/$id.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final barScore = loadScore('bar_swag');
  final barSuccess = loadScore('bar_swag_success');
  final fa = FakeAudio()..nowSeconds = 95.267573 - .12;
  final fs = MusicTransport(barScore, fa, loop: true, lookaheadSeconds: .3);
  fs.startAt(95.267573, tier: 4);
  tick(fs, fa, fs.secondsAt(126));
  final fc = TransitionConductor(fa, lookaheadSeconds: .3);
  final ending = fc.finish(source: fs, success: barSuccess);
  check(
    fs.beatAt(ending.exitAtSeconds) > 128,
    'Regression fixture must straddle the loop endpoint through floating-point inversion',
  );
  advance(fc, fa, ending.endAtSeconds + .02);
  check(
    fa.scheduled.every((e) => e.duration > 0),
    'Fractional-tempo retirement never submits zero-duration attacks',
  );
  check(
    fa.scheduled
        .where((e) => barScore.notes.contains(e.note))
        .every((e) => e.at < ending.exitAtSeconds),
    'Source never duplicates the successor downbeat at a rounded loop retirement boundary',
  );
  check(
    fa.scheduled.any(
      (e) =>
          barSuccess.notes.contains(e.note) &&
          close(e.at, ending.exitAtSeconds),
    ),
    'Success still owns its exact downbeat when the source boundary is excluded',
  );
  final lateAudio = FakeAudio();
  final shortNote = MusicScore(
    id: 'expired',
    beatsPerBar: 4,
    bars: 2,
    phraseBars: 2,
    tempos: List.filled(5, 120),
    notes: [
      const ScoreNote(
        track: 'bass',
        beat: 0,
        pitch: 48,
        duration: .0002,
        velocity: 70,
      ),
    ],
  );
  final lateTransport = MusicTransport(shortNote, lateAudio)..startAt(.12);
  lateAudio.nowSeconds = .121;
  lateTransport.pump();
  check(
    lateAudio.scheduled.isEmpty && lateTransport.droppedNotes == 1,
    'A slightly late attack with an already expired release is dropped instead of receiving a nonpositive duration',
  );
  stdout.writeln(
    'PASS: exact boundary downbeats, no handoff silences, source retirement, successive handoffs, final tag, coordinated pause cancellation, shifted anchors, preserved source retirement',
  );
}
