import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../music/game_audio.dart';
import '../music/score.dart';
import '../music/transport.dart';
import '../music/transition_conductor.dart';
import 'garden_scene.dart';
import 'garden_session.dart';
import 'gesture_glyph.dart';
import 'gesture_shapes.dart';
import 'level_definition.dart';
import 'party_autoplay.dart';
import 'pause_overlay.dart';
import 'progression.dart';
import 'rhythm.dart';
import 'cue_links.dart';
import 'cue_path.dart';
import 'tap_feedback.dart';
import 'tap_resolution.dart';
import 'thumb_layout.dart';
import 'touch_gesture.dart';

const _cream = Color(0xFFFFF0D1);
const _gold = Color(0xFFFFC35F);
const _mint = Color(0xFF7CE2C4);
const _ink = Color(0xFF101F29);

/// A browser without WebGL paints in software: 120 to 160 ms a frame, with
/// spikes of a second. Audio keeps running through that, so a stall this short
/// costs a few notes rather than stopping the run for a count-in.
const _starvationGraceSeconds = 1.5;

class GardenPage extends StatefulWidget {
  const GardenPage({super.key, this.audioFactory, this.levels});

  final GameAudio Function()? audioFactory;

  /// The campaign to play; the shipping `levels/` files unless a test says so.
  final Future<LevelRegistry> Function()? levels;

  @override
  State<GardenPage> createState() => _GardenPageState();
}

class _GardenPageState extends State<GardenPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Future<LevelRegistry> _levelsLoad =
      (widget.levels ?? LevelRegistry.loadShipping)();
  late final _scene = GardenSceneGame(
    firstLevel: () async => (await _levelsLoad).first,
  );
  LevelRegistry? _levels;
  final _focus = FocusNode();
  late final _touches = DanceTouchGestures(clock: () => _audio.nowSeconds);
  // `?autoplay=flawless` makes flawless the first press: the top of the ladder.
  final _autoplay = PartyAutoplay(
    startFlawless: Uri.base.queryParameters['autoplay'] == 'flawless',
  );
  bool _usedAutoplay = false;

  /// AutoPlay was pressed before the campaign finished loading. A press isn't
  /// dropped just because it came early: it's kept, and the run starts on load.
  bool _startWhenLoaded = false;
  late final GameAudio _audio;
  late final Ticker _ticker;
  Timer? _pump;
  GardenSession? _session;
  MusicTransport? _transport;
  Map<String, dynamic>? _scoreData;
  final _roomScores = <String, Map<String, dynamic>>{};
  int _roomIndex = 0;
  int _bankedPizazz = 0;
  int _bankedPerfects = 0;
  LevelStep get _step => _levels!.campaign[_roomIndex];
  LevelDefinition get _level => _step.level;
  String get _levelNumber => (_roomIndex + 1).toString().padLeft(2, '0');
  final _exitScores = <String, MusicScore>{};
  TransitionConductor? _conductor;
  MusicHandoff? _handoff;
  MusicFinish? _finish;
  bool _exitReady = false;
  bool _exitStarted = false;
  bool _handoffPaused = false;
  bool _adoptingRoom = false;
  bool _starting = false;
  bool _foreground = true;
  int _activationEpoch = 0;
  bool _reducedMotion = false;
  String? _error;
  String? _styleNote;
  String _resultSignature = '';
  final _marks = <FeedbackMark>[];
  final _pressedAt = <Limb, double>{};
  double _sagUntil = 0;
  Size _stage = Size.zero;
  Limb? _lastTapLimb;
  double _lastTapBeat = 0;
  String _lastTapNote = '';
  final _resumeFade = ResumeFade();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audio = (widget.audioFactory ?? createGameAudio)();
    _loadScore();
    _ticker = createTicker((_) {
      // Slow frames can crowd out the timer, so each frame pumps as well.
      _pumpGame();
      if (mounted &&
          (_session?.running == true || _conductor?.isPlaying == true)) {
        setState(() {});
      }
    })..start();
    _pump = Timer.periodic(
      const Duration(milliseconds: 20),
      (_) => _pumpGame(),
    );
  }

  void _pumpGame() {
    final session = _session;
    if (session == null) return;
    if (_conductor != null) {
      _conductor!.pump();
      if (_conductor!.isPaused && !_handoffPaused) {
        _handoffPaused = true;
        _scene.presentationPaused = true;
        if (mounted) setState(() {});
      }
      final next = _handoff?.nextTransport;
      if (!_handoffPaused) {
        final success = _handoff?.success ?? _finish?.success;
        final source = _handoff?.source ?? _finish?.source;
        if (success != null && source != null) {
          final exitAt = source.retirementSeconds;
          final bridge = _handoff?.bridge;
          final successBeat = success.positionBeats;
          final bridgeBeat = bridge?.positionBeats ?? 0;
          _scene.presentationBeat = _audio.nowSeconds < exitAt
              ? source.positionBeats
              : source.beatAt(exitAt) + successBeat + bridgeBeat;
          // Let applause breathe through the first bar, then settle by guest.
          final coda = ((successBeat - 4) / 4).clamp(0.0, 1.0);
          final exitBeat = successBeat + bridgeBeat;
          final shot = _level.exitShot;
          final travel = bridge == null
              ? 0.0
              : shot != null
              ? shot.routeAt(
                  exitBeat,
                  success.score.lengthBeats + bridge.score.lengthBeats,
                )
              : (bridgeBeat / bridge.score.lengthBeats).clamp(0.0, 1.0);
          if (_audio.nowSeconds >= exitAt) _scene.exitBeat = exitBeat;
          _scene.warmDown = bridge == null ? coda : coda * .55 + travel * .45;
          // A cinematic replaces the walk out; the room still cools with travel.
          _scene.exitTravel = shot == null ? travel : 0;
        }
      }
      if (next != null &&
          next.state == TransportState.playing &&
          !next.countingIn &&
          !_adoptingRoom &&
          !_handoffPaused) {
        _adoptNextRoom();
      }
      if (_conductor!.completed && _handoff == null) {
        _conductor = null;
        if (mounted) setState(() {});
      }
    } else if (_transport!.state == TransportState.playing) {
      _transport!.pump();
    }
    if (session.phase == GardenPhase.cleared && !_exitStarted && _exitReady) {
      _beginExit();
    }
    if (!session.running) {
      _autoplay.suspend();
      return;
    }
    session.advance();
    if (_conductor == null &&
        !_handoffPaused &&
        !_adoptingRoom &&
        _foreground) {
      _autoplay.pump(
        session,
        onTap: _tap,
        onMove: _moveLanded,
        touches: _touches,
        origin: (note) {
          final at = _anchor(
            note.limb,
            _stage,
            _transport!.beatAt(note.atMs / 1000),
            note.id,
          );
          return (at.dx, at.dy);
        },
      );
    } else {
      _autoplay.suspend();
    }
    final signature =
        '${session.progress.tier}:${session.progress.consecutiveFailures}:'
        '${session.progress.entranceResets}:${session.passedPhrases}';
    if (signature != _resultSignature) {
      _resultSignature = signature;
      if (session.lastOutcome == ChallengeOutcome.entranceReset) {
        // His walk back says it all, and the band goes dull behind him.
        _scene.resetEntrance();
        _sagUntil = _audio.nowSeconds + TurnLook.sagSeconds;
      } else if (session.lastOutcome == ChallengeOutcome.retry) {
        _sagUntil = _audio.nowSeconds + TurnLook.sagSeconds;
      } else if (session.lastOutcome != null) {
        _addMark(FeedbackMark(MarkKind.phrase, _bandCentre));
      }
    }
    _settleStrokes(session);
    if (session.phase == GardenPhase.paused ||
        session.phase == GardenPhase.cleared) {
      if (session.phase == GardenPhase.paused) {
        _scene.presentationPaused = true;
      }
      _touches.clear();
      _styleNote = null;
      if (mounted) setState(() {});
    }
  }

  /// A thumb held past its time, or still drawing as the room is won, is read as
  /// it stands: holding on a moment too long must not lose a finished shape.
  void _settleStrokes(GardenSession session) {
    final over = session.phase == GardenPhase.cleared;
    for (final stroke in _touches.live.toList()) {
      if (stroke.pointer == autoplayPointer && !over) continue;
      final ends = session.moveEndsAt(stroke.noteId);
      if (!over && ends != null && _audio.nowSeconds <= ends) continue;
      final result = _touches.settle(stroke.pointer);
      if (result != null) _land(session, result);
    }
    _touches.prune();
  }

  void _land(GardenSession session, DanceStrokeResult result) {
    final move = landStroke(session, result);
    if (move != null) _moveLanded(move);
  }

  Future<void> _loadScore() async {
    try {
      final levels = await _levelsLoad;
      if (!mounted) return;
      setState(() => _levels = levels);
      for (final id in levels.roomScoreIds) {
        final json = await rootBundle.loadString(
          'assets/music/scores/$id.json',
        );
        _roomScores[id] = jsonDecode(json) as Map<String, dynamic>;
      }
      final data = _roomScores[_level.music.score]!;
      if (!mounted) return;
      _scoreData = data;
      _newSession();
      setState(() {});
      if (_startWhenLoaded && _autoplay.enabled) unawaited(_start());
      _startWhenLoaded = false;
      await _prepareExits();
    } catch (error) {
      debugPrint('The campaign could not load: $error');
      if (mounted) {
        setState(() => _error = 'The garden could not load. Please refresh.');
      }
    }
  }

  void _newSession() {
    _autoplay.suspend();
    _usedAutoplay = _autoplay.enabled;
    _transport?.stop();
    _transport = MusicTransport(
      MusicScore.fromJson(_scoreData!),
      _audio,
      loop: true,
      lookaheadSeconds: .3,
      starvationGraceSeconds: _starvationGraceSeconds,
    );
    _audio.leadShape = _level.music.leadShape;
    _session = _level.newSession(_transport!, _audio);
    _scene.session = _session;
    _marks.clear();
    _resultSignature = '';
    _exitStarted = false;
  }

  Future<void> _prepareExits() async {
    try {
      for (final id in _levels!.exitScoreIds) {
        if (_exitScores.containsKey(id)) continue;
        final data = jsonDecode(
          await rootBundle.loadString('assets/music/scores/$id.json'),
        ) as Map<String, dynamic>;
        _exitScores[id] = MusicScore.fromJson(data);
      }
      await _scene.loaded;
      final next = _step.next;
      if (next != null) await _scene.images.load(next.background);
      if (mounted) setState(() => _exitReady = true);
    } catch (error) {
      // The current loop continues safely if the next room cannot be prepared.
      if (mounted) {
        setState(
          () => _error = 'The next room could not load. Tap to try again.',
        );
      }
    }
  }

  void _beginExit() {
    _exitStarted = true;
    _finish = null;
    _conductor = TransitionConductor(
      _audio,
      // Queued further ahead than play, so a stalled frame at the very moment of
      // contact can't drop the hit: the transport never plays a note late.
      lookaheadSeconds: .6,
      starvationGraceSeconds: _starvationGraceSeconds,
    );
    final step = _step;
    final next = step.next;
    final shot = step.level.exitShot;
    final successScore = _exitScores[step.level.music.successScore]!;
    final success = shot?.mixCue(successScore, 0) ?? successScore;
    if (next != null) {
      final bridgeScore = _exitScores[step.bridgeToNext!]!;
      _handoff = _conductor!.handoff(
        source: _transport!,
        success: success,
        bridge:
            shot?.mixCue(bridgeScore, successScore.lengthBeats) ?? bridgeScore,
        nextScore: MusicScore.fromJson(_roomScores[next.music.score]!),
      );
    } else {
      _finish = _conductor!.finish(source: _transport!, success: success);
    }
    _scene.exitCodaBeat = _transport!.beatAt(_transport!.retirementSeconds) + 4;
    if (mounted) setState(() {});
  }

  Future<void> _adoptNextRoom() async {
    _adoptingRoom = true;
    final nextIndex = _roomIndex + 1;
    final next = _handoff!.nextTransport;
    try {
      await _scene.showLevel(_step.next!, dissolve: true);
      if (!mounted || !_foreground || _conductor?.isPaused == true) return;
      _bankedPizazz += _session!.pizazz;
      _bankedPerfects += _session!.perfects;
      _roomIndex = nextIndex;
      _scoreData = _roomScores[_level.music.score];
      _transport = next;
      _audio.leadShape = _level.music.leadShape;
      _session = _level.newSession(next, _audio)..start(startTransport: false);
      _scene.session = _session;
      // Old decks have scheduled their own releases; never stop/silence them here.
      _handoff = null;
      _finish = null;
      _conductor = null;
      _exitStarted = false;
      _marks.clear();
      _styleNote = null;
      _resultSignature = '';
      // Ready this level's own exit: its bridge's next room is not loaded yet.
      _exitReady = false;
      unawaited(_prepareExits());
      setState(() {});
    } catch (error) {
      _conductor?.pause();
      _handoffPaused = true;
      if (mounted) {
        setState(
          () => _error = 'We kept your spot. Tap to try the doorway again.',
        );
      }
    } finally {
      _adoptingRoom = false;
    }
  }

  Future<void> _start() async {
    if (_starting || _session == null) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    final activationEpoch = ++_activationEpoch;
    try {
      await _audio.activate().timeout(const Duration(seconds: 7));
      if (!mounted) return;
      if (!_foreground || activationEpoch != _activationEpoch) {
        _audio.silence();
        return;
      }
      await _scene.loaded.timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (!_foreground || activationEpoch != _activationEpoch) {
        _audio.silence();
        return;
      }
      _scene.presentationPaused = false;
      if (_handoffPaused) {
        final barSeconds =
            4 * 60 / _transport!.score.tempos[_transport!.currentTier];
        _conductor!.resume(leadSeconds: barSeconds);
        _playCountIn(barSeconds);
        _beginResumeFade(_audio.nowSeconds + barSeconds);
        _handoffPaused = false;
        return;
      }
      if (_session!.phase == GardenPhase.cleared) {
        if (!_exitReady) {
          await _prepareExits();
          return;
        }
        _conductor = null;
        _handoff = null;
        _finish = null;
        _roomIndex = 0;
        _bankedPizazz = 0;
        _bankedPerfects = 0;
        _scoreData = _roomScores[_level.music.score];
        await _scene.showLevel(_level);
        if (!mounted || !_foreground || activationEpoch != _activationEpoch) {
          return;
        }
        _newSession();
      }
      if (_session!.phase == GardenPhase.paused) {
        _session!.resume();
        final anchor = _transport!.secondsAt(_transport!.positionBeats);
        _playCountIn(anchor - _audio.nowSeconds);
        _beginResumeFade(anchor);
      } else {
        _session!.start();
      }
      _focus.requestFocus();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              _scene.artLoadError ??
              'Sound needs your permission. Tap again to start the music.',
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _pause() {
    _autoplay.suspend();
    _scene.presentationPaused = true;
    if (_conductor?.isPlaying == true) {
      _conductor!.pause();
      _handoffPaused = true;
    } else {
      _session?.pause();
    }
    _touches.clear();
    _styleNote = null;
    setState(() {});
  }

  /// Only while paused. A second tap can arrive after the resume and before the
  /// next frame takes this callback away, and it must not start anything.
  void _resumeFromPause() {
    if (_handoffPaused || _session?.phase == GardenPhase.paused) {
      unawaited(_start());
    }
  }

  /// A second tap right after a resume is one thumb, not a wish to pause again.
  void _pauseFromButton() {
    if (!_resumeFade.guardsPauseAt(_audio.nowSeconds)) _pause();
  }

  bool get _calmPause =>
      _reducedMotion || MediaQuery.disableAnimationsOf(context);

  /// Volume and opacity only: the transport has already anchored the music, and
  /// this reads that time without being able to change it.
  void _beginResumeFade(double anchor) {
    final calm = _calmPause;
    _resumeFade.begin(
      now: _audio.nowSeconds,
      anchor: anchor,
      reducedMotion: calm,
    );
    final Object audio = _audio;
    if (audio is MusicFader) {
      audio.fadeMusicIn(
        atSeconds: anchor,
        seconds: calm ? musicFadeSecondsCalm : musicFadeSeconds,
      );
    }
  }

  /// Off, on with errors, flawless, off.
  void _cycleAutoplay() {
    setState(() {
      _autoplay.mode = _autoplay.nextMode;
      if (_autoplay.enabled) _usedAutoplay = true;
      _touches.clear();
      _styleNote = null;
    });
    if (!_autoplay.enabled) {
      _startWhenLoaded = false;
      return;
    }
    if (_session == null) {
      _startWhenLoaded = true;
      // The browser unlocks sound only inside this press, so ask for it now.
      unawaited(_audio.activate().catchError((Object _) {}));
      return;
    }
    if (_session!.phase == GardenPhase.ready && !_starting) {
      // Activate sound in this same user gesture on desktop browsers.
      unawaited(_start());
    }
  }

  void _playCountIn(double seconds) {
    final now = _audio.nowSeconds;
    for (var i = 0; i < 4; i++) {
      _audio.schedule(
        const ScoreNote(
          track: 'pulse',
          beat: 0,
          pitch: 76,
          duration: .045,
          velocity: 45,
        ),
        now + seconds * i / 4,
        .045,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On the web `inactive` only means the window lost focus. The game is still
    // on screen and audible, so only leaving the screen interrupts a run.
    _foreground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    _scene.presentationPaused =
        !_foreground || _handoffPaused || _session?.phase == GardenPhase.paused;
    if (!_foreground) _activationEpoch++;
    if (!_foreground &&
        (_session?.running == true || _conductor?.isPlaying == true)) {
      _pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _pump?.cancel();
    _conductor?.stop();
    _transport?.stop();
    _audio.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _addMark(FeedbackMark mark) {
    final now = _audio.nowSeconds;
    _marks
      ..removeWhere(
        (old) => now - (old.bornAt ?? now) >= FeedbackMark.lifeSeconds,
      )
      ..add(mark..bornAt = now);
  }

  /// Low in the middle of the tap band, where a passed phrase sprays up from.
  Offset get _bandCentre => Offset(_stage.width / 2, _stage.height * .8);

  TapResult _tap(Limb limb) {
    final richBefore = _session!.richStepsCompleted;
    final result = _session!.tap(limb);
    // Heard, before any judgment: a stray tap gets this and nothing else.
    _pressedAt[limb] = _audio.nowSeconds;
    if (result.note != null) {
      final targetBeat = _transport!.beatAt(result.note!.atMs / 1000);
      final futureBeats = [
        for (final offset in _session!.activeOffsets)
          _session!.callStartBeat + _session!.chart.callBeats + offset,
      ].where((beat) => beat > targetBeat + .001);
      _scene.dance(
        limb,
        targetBeat: targetBeat,
        nextRequiredBeat: futureBeats.isEmpty ? null : futureBeats.first,
        partner: _session!.lastPairPartner,
      );
      _styleNote = result.note!.flourishTo == null ? null : result.note!.id;
      _lastTapLimb = limb;
      _lastTapBeat = targetBeat;
      _lastTapNote = result.note!.id;
      if (result.timing != null) {
        _addMark(
          FeedbackMark.tap(
            result.timing!,
            _anchor(limb, _stage, targetBeat, result.note!.id),
            deltaMs: result.deltaMs,
            combo: _session!.combo,
          ),
        );
      }
      // Both presses of a richer step: the sparks say it landed, as a move's do.
      if (_session!.richStepsCompleted != richBefore) {
        _addMark(
          FeedbackMark(
            MarkKind.flourish,
            _anchor(limb, _stage, targetBeat, result.note!.id),
          ),
        );
      }
    }
    return result;
  }

  /// The limb of the nearest ring with an open note whose area holds the point.
  Limb? _resolveTap(GardenSession session, Offset point, Size size) {
    session.advance();
    return resolveTap(
      x: point.dx,
      y: point.dy,
      radius: tapAreaRadius(size.width),
      candidates: openTapCandidates(
        cues: session.visibleCues,
        nowMs: (_audio.nowSeconds * 1000).round(),
        secondsAt: _transport!.secondsAt,
        landing: (cue) => _path(cue.limb, cue.beat, cue.id, size).landing,
      ),
    )?.limb;
  }

  /// A stray tap in the pad is heard, like a wrong-quadrant tap always was: the
  /// ring on its side dents, and it costs nothing.
  void _strayTap(Offset point, Size size) {
    final limb = thumbLimbAt(point.dx / size.width, point.dy / size.height);
    if (limb != null) _pressedAt[limb] = _audio.nowSeconds;
  }

  /// Where a note's feedback belongs: the spot its ring landed on.
  Offset _anchor(Limb limb, Size size, double beat, String id) {
    final landing = _path(limb, beat, id, size).landing;
    return Offset(landing.x, landing.y);
  }

  CuePath _path(Limb limb, double beat, String id, Size size) => cuePath(
    limb: limb,
    beat: beat,
    id: id,
    width: size.width,
    height: size.height,
    reducedMotion: _reducedMotion,
  );

  Offset _cuePosition(GardenCue cue, Size size) {
    final at = _path(cue.limb, cue.beat, cue.id, size).at(cue.progress);
    return Offset(at.x, at.y);
  }

  /// A move landed: the music answers, the trail flares, and Mācron does it.
  void _moveLanded(OptionalMove move) {
    _ornament(move.direction.name);
    _scene.flourishMove = move.kind;
    _scene.flourishLimb = move.limb;
  }

  void _ornament(String gesture) {
    final transport = _transport!;
    final data = (_scoreData!['adornments'] as List).firstWhere(
      (entry) => entry['gesture'] == gesture,
      orElse: () => (_scoreData!['adornments'] as List).first,
    ) as Map<String, dynamic>;
    final nextBeat = (transport.beatAt(_audio.nowSeconds + .06) * 4).ceil() / 4;
    for (final raw in data['events'] as List) {
      final note = ScoreNote.fromJson(raw as Map<String, dynamic>);
      final at = transport.secondsAt(nextBeat + note.beat);
      _audio.schedule(
        note,
        at,
        transport.secondsAt(nextBeat + note.beat + note.duration) - at,
      );
    }
    _styleNote = null;
    _scene.flourishBeat = _session!.positionBeats;
    final limb = _lastTapLimb;
    if (limb != null) {
      _addMark(
        FeedbackMark(
          MarkKind.flourish,
          _anchor(limb, _stage, _lastTapBeat, _lastTapNote),
          chain: _session!.styleCombo,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final active = (session?.running ?? false) && !_handoffPaused;
    final phase = _handoffPaused
        ? GardenPhase.paused
        : session?.phase ?? GardenPhase.ready;
    final paused = phase == GardenPhase.paused;
    final pauseVeil = paused ? 1.0 : _resumeFade.opacityAt(_audio.nowSeconds);
    return Scaffold(
      backgroundColor: _ink,
      body: KeyboardListener(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is! KeyDownEvent) return;
          if (event.logicalKey == LogicalKeyboardKey.escape && active) {
            _pause();
            return;
          }
          if (paused &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            _resumeFromPause();
            return;
          }
          if (!active) return;
          final direction = {
            LogicalKeyboardKey.arrowUp: FlourishDirection.up,
            LogicalKeyboardKey.arrowRight: FlourishDirection.right,
            LogicalKeyboardKey.arrowDown: FlourishDirection.down,
            LogicalKeyboardKey.arrowLeft: FlourishDirection.left,
          }[event.logicalKey];
          if (direction != null && _styleNote != null) {
            final move = session!.optionalMove(
              _styleNote!,
              direction == FlourishDirection.left ||
                      direction == FlourishDirection.right
                  ? GestureKind.spin
                  : GestureKind.flick,
              direction,
            );
            if (move != null) {
              _moveLanded(move);
              return;
            }
          }
          final limb = {
            LogicalKeyboardKey.keyQ: Limb.leftHand,
            LogicalKeyboardKey.keyW: Limb.rightHand,
            LogicalKeyboardKey.keyA: Limb.leftFoot,
            LogicalKeyboardKey.keyS: Limb.rightFoot,
          }[event.logicalKey];
          if (limb != null) _tap(limb);
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                _stage = size;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    GameWidget(
                      game: _scene,
                      errorBuilder: (context, error) => ColoredBox(
                        color: _ink,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Text(
                              _scene.artLoadError ?? 'The party scene could not load. Refresh to retry.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: _cream),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (active)
                      Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (event) {
                          final limb = _resolveTap(
                            session,
                            event.localPosition,
                            size,
                          );
                          if (limb == null) _strayTap(event.localPosition, size);
                          _touches.begin(
                            pointer: event.pointer,
                            x: event.localPosition.dx,
                            y: event.localPosition.dy,
                            acceptedNote: limb == null ? null : _tap(limb).note,
                          );
                        },
                        onPointerMove: (event) {
                          final done = _touches.move(
                            pointer: event.pointer,
                            x: event.localPosition.dx,
                            y: event.localPosition.dy,
                          );
                          if (done != null) _land(session, done);
                        },
                        onPointerUp: (event) {
                          final done = _touches.end(
                            pointer: event.pointer,
                            x: event.localPosition.dx,
                            y: event.localPosition.dy,
                          );
                          if (done != null) _land(session, done);
                        },
                        onPointerCancel: (event) =>
                            _touches.cancel(event.pointer),
                        child: Stack(
                          children: [
                            for (final limb in Limb.values)
                              if (!session!.visibleCues.any(
                                (cue) => cue.limb == limb,
                              ))
                                _target(limb, size),
                            for (final cue in session!.visibleCues)
                              _target(cue.limb, size, cue),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: CueLinkPainter(
                                    cueLinks(
                                      session.visibleCues,
                                      (cue) => _cuePosition(cue, size),
                                    ),
                                    demoColor: _gold,
                                    playColor: _mint,
                                  ),
                                ),
                              ),
                            ),
                            for (final cue in session.visibleCues)
                              _cue(cue, size),
                          ],
                        ),
                      ),
                    if (active)
                      IgnorePointer(child: _playSignals(session!, size)),
                    if (!active && !paused) _cover(phase, size),
                    if (pauseVeil > 0)
                      Positioned.fill(
                        child: VcrPauseOverlay(
                          showPlay: !paused || _starting,
                          opacity: pauseVeil,
                          reducedMotion: _calmPause,
                          onResume: paused ? _resumeFromPause : null,
                          message: paused ? _error : null,
                        ),
                      ),
                    _header(
                      active ||
                          _conductor?.isPlaying == true ||
                          (phase == GardenPhase.cleared && !_exitStarted),
                      paused: paused,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(bool active, {required bool paused}) => Positioned(
    top: MediaQuery.paddingOf(context).top + 14,
    left: 20,
    right: 14,
    child: Row(
      children: [
        // The wordmark belongs to the cover. In play the room has the screen.
        if (!active && !paused) ...[
          const Text(
            'K / K',
            style: TextStyle(
              color: _gold,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'KUMBIA KOLISEUM',
            style: TextStyle(
              color: _cream,
              fontSize: 9,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const Spacer(),
        if (active)
          IconButton(
            onPressed: _pauseFromButton,
            tooltip: 'Pause',
            color: _cream,
            icon: const Icon(Icons.pause_rounded),
          )
        else if (!paused)
          Text(
            _levels == null
                ? ''
                : '$_levelNumber / ${_levels!.displayTotal.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: _cream,
              fontFamily: 'Kumbia',
              fontSize: 11,
            ),
          ),
        _autoplayButton(),
      ],
    ),
  );

  /// A press is never ignored, even before the campaign has loaded: it's kept.
  Widget _autoplayButton() {
    final mode = _autoplay.mode;
    final describe = switch (mode) {
      AutoplayMode.off => 'AutoPlay off',
      AutoplayMode.withErrors => 'AutoPlay on, with mistakes',
      AutoplayMode.flawless => 'AutoPlay flawless',
    };
    final next = switch (_autoplay.nextMode) {
      AutoplayMode.off => 'turn it off',
      AutoplayMode.withErrors => 'watch it with mistakes',
      AutoplayMode.flawless => 'watch it flawless',
    };
    final color = switch (mode) {
      AutoplayMode.flawless => _gold,
      AutoplayMode.withErrors => _mint,
      // Faintly lit for the rest of a run it played in.
      AutoplayMode.off =>
        _usedAutoplay
            ? _mint.withValues(alpha: .55)
            : _cream.withValues(alpha: .65),
    };
    return Semantics(
      toggled: _autoplay.enabled,
      label: describe,
      child: IconButton(
        key: const ValueKey('autoplay'),
        onPressed: _cycleAutoplay,
        tooltip: '$describe. Tap to $next.',
        color: color,
        iconSize: 20,
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              mode == AutoplayMode.off
                  ? Icons.smart_toy_outlined
                  : Icons.smart_toy,
              color: color,
              size: 20,
            ),
            // Shape as well as colour says flawless: gold reads poorly for some.
            if (mode == AutoplayMode.flawless)
              const Positioned(
                right: -7,
                top: -7,
                child: Icon(Icons.star_rounded, color: _gold, size: 13),
              ),
          ],
        ),
      ),
    );
  }

  TurnLook _turnLook(GardenSession session) => TurnLook.of(
    session.phase,
    beat: _transport!.positionBeats,
    flow: session.combo,
    reducedMotion: _reducedMotion,
    sagging: _audio.nowSeconds < _sagUntil,
  );

  Widget _target(Limb limb, Size size, [GardenCue? cue]) {
    final at = cue == null
        ? cueHome(limb, width: size.width, height: size.height)
        : _path(limb, cue.beat, cue.id, size).landing;
    final look = _turnLook(_session!);
    // The ring dents the moment a thumb lands, whatever the judge says next.
    final pressed = _audio.nowSeconds - (_pressedAt[limb] ?? -1) < .09;
    return Positioned(
      left: at.x - cueRingRadius,
      top: at.y - cueRingRadius,
      child: IgnorePointer(
        child: Opacity(
          opacity: pressed ? .85 : look.ring,
          child: Transform.scale(
            scale: pressed && !_reducedMotion ? .92 : 1,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: pressed ? _cream : look.color,
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(14),
              child: _limbIcon(limb, pressed ? _cream : look.color),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cue(GardenCue cue, Size size) {
    final at = _cuePosition(cue, size);
    final extent = cueExtent(cue.progress);
    final color = cue.demo ? _gold : _mint;
    return Positioned(
      left: at.dx - extent / 2,
      top: at.dy - extent / 2,
      child: IgnorePointer(
        child: Opacity(
          opacity:
              cueFadeIn(cue.progress) *
              (cue.demo ? .45 + cue.progress * .25 : .6 + cue.progress * .4),
          child: SizedBox(
            width: extent,
            height: extent,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                SizedBox.expand(
                  child: cue.demo
                      ? Transform.rotate(
                          angle: math.pi / 4,
                          child: Container(
                            margin: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              border: Border.all(color: color, width: 1.5),
                            ),
                          ),
                        )
                      : CircularProgressIndicator(
                          value: cue.progress,
                          strokeWidth: 2,
                          color: color,
                          backgroundColor: color.withValues(alpha: .08),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(9),
                  child: _limbIcon(cue.limb, color),
                ),
                // A second ring: this spot wants two presses.
                if (cue.move == RichMove.doubleTap)
                  Semantics(
                    label: 'Press twice',
                    child: Transform.scale(
                      scale: 1.3,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                // The path itself, from where the thumb lands: press, then this.
                if (cue.offer != null)
                  Semantics(
                    label: 'Optional ${cue.offer!.name}',
                    child: SizedBox.expand(
                      child: CustomPaint(
                        painter: GestureGlyphPainter(
                          cue.offer!,
                          color: color,
                          flip: !limbIsLeft(cue.limb),
                          pose: GlyphPose.ofCue(
                            cue.progress,
                            reducedMotion: _calmPause,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _limbIcon(Limb limb, Color color) => SvgPicture.asset(
    'assets/ui/${switch (limb) {
      Limb.leftHand => 'left_hand',
      Limb.rightHand => 'right_hand',
      Limb.leftFoot => 'left_foot',
      Limb.rightFoot => 'right_foot',
    }}.svg',
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    semanticsLabel: limb.name,
  );

  /// Everything a label used to say in play. The words stay for screen readers.
  Widget _playSignals(GardenSession session, Size size) {
    final countingIn = _transport!.countingIn;
    final untilStart =
        _transport!.secondsAt(_transport!.positionBeats) - _audio.nowSeconds;
    final count =
        (untilStart / (60 / _transport!.score.tempos[_transport!.currentTier]))
            .ceil()
            .clamp(1, 4);
    final turn = countingIn
        ? 'Ready, $count'
        : switch (session.phase) {
            GardenPhase.intro => 'Feel the pulse',
            GardenPhase.call => 'Watch the call',
            _ => 'Your turn',
          };
    final finishing = session.progress.tier == 4;
    return Semantics(
      label: turn,
      value: finishing
          ? 'Full support, ${session.peakChallengesRemaining} finish phrases'
          : 'Level ${session.progress.tier + 1} of 5',
      liveRegion: true,
      child: ExcludeSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: FeedbackPainter(
                _marks,
                _audio.nowSeconds,
                reducedMotion: _reducedMotion,
              ),
            ),
            CustomPaint(
              painter: StrokeTrailPainter(
                _touches.strokes.toList(),
                now: _audio.nowSeconds,
                reducedMotion: _calmPause,
                flipOf: (stroke) => !limbIsLeft(stroke.limb),
              ),
            ),
            if (countingIn)
              Positioned(
                top: size.height * .29,
                left: 0,
                right: 0,
                child: _lamps(4, count, _gold, 12),
              ),
          ],
        ),
      ),
    );
  }

  /// [lit] of [total] small round lamps in a centred row.
  Widget _lamps(int total, int lit, Color color, double extent) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < total; i++)
        Container(
          width: extent,
          height: extent,
          margin: EdgeInsets.symmetric(horizontal: extent * .4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < lit ? color : color.withValues(alpha: .15),
            border: Border.all(color: _ink.withValues(alpha: .7)),
          ),
        ),
    ],
  );

  /// The level's two big words, the only text in a run. It lands with the hit.
  Widget _cinematicTitle(Size size) {
    final shot = _level.exitShot;
    final beat = _scene.exitBeat;
    final pose = shot == null || beat == null
        ? null
        : shot.titleAt(beat, reducedMotion: _reducedMotion);
    if (pose == null) return const SizedBox.shrink();
    final words = _level.copy.titleWords;
    final fontSize = math.min(size.width * .21, 104.0);
    TextStyle style(Color color) => TextStyle(
      color: color,
      height: 1,
      fontSize: fontSize,
      letterSpacing: -2,
      fontWeight: FontWeight.w900,
      shadows: const [
        Shadow(color: _ink, offset: Offset(3, 4)),
        Shadow(color: _ink, blurRadius: 12),
      ],
    );
    return Positioned(
      // Under the contact point, in the band the close-up keeps clear for this.
      top: size.height * .58,
      left: 16,
      right: 16,
      height: size.height * .3,
      child: IgnorePointer(
        child: Semantics(
          label: _level.copy.clearedShout,
          liveRegion: true,
          child: ExcludeSemantics(
            child: Opacity(
              opacity: pose.opacity,
              child: Transform.scale(
                scale: pose.scale,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(words.first, style: style(_cream)),
                      Text(words.last, style: style(_gold)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cover(GardenPhase phase, Size size) {
    final cleared = phase == GardenPhase.cleared;
    // The picture and the music carry a level's end. Only a failure to load the
    // next room, or the end of the campaign, brings the cover back.
    if (cleared && _conductor?.isPlaying == true) return _cinematicTitle(size);
    if (cleared && !_exitStarted && _error == null) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: ColoredBox(
        color: _ink.withValues(alpha: .38),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                SizedBox(height: math.max(58, size.height * .13)),
                Text(
                  cleared ? '' : 'A LITTLE ROBOT. A BIG NIGHT.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _mint,
                    fontSize: 9,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  cleared ? _level.copy.clearedTitle : 'KUMBIA\nKOMBAT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _cream,
                    height: .90,
                    fontSize: math.min(size.width * .15, 66),
                    letterSpacing: -3,
                    fontWeight: FontWeight.w900,
                    shadows: const [
                      Shadow(color: Color(0xFF665037), offset: Offset(3, 4)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  cleared
                      ? ''
                      : _levels == null
                      ? ''
                      : '$_levelNumber  /  ${_level.title}',
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                if (cleared)
                  Semantics(
                    label:
                        '${_bankedPerfects + _session!.perfects} perfect, '
                        '${_bankedPizazz + _session!.pizazz} pizazz',
                    child: const SizedBox.shrink(),
                  ),
                if (!cleared) ...[
                  Text(
                    _levels == null ? '' : _level.copy.invitation,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _cream, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  // A tap, then the four invitations, drawn just as a cue draws them.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 25,
                        child: _limbIcon(Limb.leftHand, _mint),
                      ),
                      for (final kind in const [
                        GestureKind.spin,
                        GestureKind.wave,
                        GestureKind.stomp,
                        GestureKind.circle,
                      ])
                        Padding(
                          padding: const EdgeInsets.only(left: 18),
                          child: SizedBox(
                            width: 25,
                            height: 25,
                            child: CustomPaint(
                              painter: GestureGlyphPainter(
                                kind,
                                color: _mint,
                                flip: false,
                                size: 22,
                                centred: true,
                                pose: const GlyphPose(1, null),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap near the matching ring.\nDrag along a drawn path for style.\nTaps alone keep the party going.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _cream.withValues(alpha: .6),
                      fontSize: 10,
                    ),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _gold, fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed:
                        _starting ||
                            _session == null ||
                            _conductor?.isPlaying == true
                        ? null
                        : _start,
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _ink,
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: Text(
                      _starting
                          ? 'WAKING THE MUSIC…'
                          : cleared
                          ? 'OTRA VUELTA  >'
                          : 'ENTRA AL RITMO  >',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  children: [
                    _option(
                      'CALM CAMERA',
                      _reducedMotion,
                      () => setState(() {
                        _reducedMotion = !_reducedMotion;
                        _scene.reducedMotion = _reducedMotion;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  cleared ? '' : 'A KUMBIA KOLISEUM NIGHT',
                  style: TextStyle(
                    color: _cream.withValues(alpha: .4),
                    fontSize: 8,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _option(String label, bool selected, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: selected ? _mint : _cream.withValues(alpha: .5),
    ),
    child: Text(
      '${selected ? '+' : '-'} $label',
      style: const TextStyle(fontSize: 8, letterSpacing: 1),
    ),
  );
}
