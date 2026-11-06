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
import 'level_definition.dart';
import 'party_autoplay.dart';
import 'progression.dart';
import 'rhythm.dart';
import 'cue_path.dart';
import 'tap_feedback.dart';
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
  final _touches = DanceTouchGestures();
  final _autoplay = PartyAutoplay();
  bool _usedAutoplay = false;
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
  Limb? _styleDestination;
  String? _styleNote;
  double _styleBeat = 0;
  double _styleUntil = 0;
  String _resultSignature = '';
  final _marks = <FeedbackMark>[];
  final _pressedAt = <Limb, double>{};
  double _sagUntil = 0;
  Size _stage = Size.zero;
  Limb? _lastTapLimb;
  double _lastTapBeat = 0;
  String _lastTapNote = '';

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
        onFlourish: (direction) => _ornament(direction.name),
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
    if (session.phase == GardenPhase.paused ||
        session.phase == GardenPhase.cleared) {
      if (session.phase == GardenPhase.paused) {
        _scene.presentationPaused = true;
      }
      _touches.clear();
      _styleDestination = null;
      _styleNote = null;
      if (mounted) setState(() {});
    }
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
        bridge: shot?.mixCue(bridgeScore, successScore.lengthBeats) ?? bridgeScore,
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
      await _scene.showLevel(_step.next!);
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
      _styleDestination = null;
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
        _playCountIn(
          _transport!.secondsAt(_transport!.positionBeats) - _audio.nowSeconds,
        );
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
    _styleDestination = null;
    _styleNote = null;
    setState(() {});
  }

  void _toggleAutoplay() {
    setState(() {
      _autoplay.enabled = !_autoplay.enabled;
      if (_autoplay.enabled) _usedAutoplay = true;
      _touches.clear();
      _styleDestination = null;
      _styleNote = null;
    });
    if (_autoplay.enabled &&
        _session?.phase == GardenPhase.ready &&
        !_starting) {
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
    _scene.presentationPaused = !_foreground;
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
      );
      _styleDestination = result.note!.flourishTo == null ? null : limb;
      _styleNote = result.note!.flourishTo == null ? null : result.note!.id;
      _styleBeat = _transport!.beatAt(result.note!.atMs / 1000);
      _styleUntil = _audio.nowSeconds + RhythmJudge.flourishWindowMs / 1000;
      _lastTapLimb = limb;
      _lastTapBeat = _styleBeat;
      _lastTapNote = result.note!.id;
      if (result.timing != null) {
        _addMark(
          FeedbackMark.tap(
            result.timing!,
            _anchor(limb, _stage, _styleBeat, result.note!.id),
            deltaMs: result.deltaMs,
            combo: _session!.combo,
          ),
        );
      }
    }
    return result;
  }

  Limb? _limbAt(Offset point, Size size) =>
      thumbLimbAt(point.dx / size.width, point.dy / size.height);

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
    _styleDestination = null;
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
          if (!active) return;
          final direction = {
            LogicalKeyboardKey.arrowUp: FlourishDirection.up,
            LogicalKeyboardKey.arrowRight: FlourishDirection.right,
            LogicalKeyboardKey.arrowDown: FlourishDirection.down,
            LogicalKeyboardKey.arrowLeft: FlourishDirection.left,
          }[event.logicalKey];
          if (direction != null &&
              _styleNote != null &&
              _audio.nowSeconds <= _styleUntil &&
              session!.flourishGesture(_styleNote!, direction)) {
            _ornament(direction.name);
            return;
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
                          final limb = _limbAt(event.localPosition, size);
                          if (limb == null) return;
                          final result = _tap(limb);
                          _touches.begin(
                            pointer: event.pointer,
                            x: event.localPosition.dx,
                            y: event.localPosition.dy,
                            at: event.timeStamp,
                            acceptedNote: result.note,
                          );
                        },
                        onPointerUp: (event) {
                          final flick = _touches.end(
                            pointer: event.pointer,
                            x: event.localPosition.dx,
                            y: event.localPosition.dy,
                            at: event.timeStamp,
                          );
                          if (flick != null &&
                              session.flourishGesture(
                                flick.noteId,
                                flick.direction,
                              )) {
                            _ornament(flick.direction.name);
                          }
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
                            for (final cue in session.visibleCues)
                              _cue(cue, size),
                            if (_styleDestination != null &&
                                _audio.nowSeconds < _styleUntil)
                              _styleHint(_styleDestination!, size),
                          ],
                        ),
                      ),
                    if (active)
                      IgnorePointer(child: _playSignals(session!, size)),
                    if (!active) _cover(phase, size),
                    _header(
                      active ||
                          _conductor?.isPlaying == true ||
                          (phase == GardenPhase.cleared && !_exitStarted),
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

  Widget _header(bool active) => Positioned(
    top: MediaQuery.paddingOf(context).top + 14,
    left: 20,
    right: 14,
    child: Row(
      children: [
        // The wordmark belongs to the cover. In play the room has the screen.
        if (!active) ...[
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
            onPressed: _pause,
            tooltip: 'Pause',
            color: _cream,
            icon: const Icon(Icons.pause_rounded),
          )
        else
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
        Semantics(
          toggled: _autoplay.enabled,
          label: 'AutoPlay',
          child: IconButton(
            onPressed: _session == null ? null : _toggleAutoplay,
            tooltip: _autoplay.enabled
                ? 'Turn off AutoPlay'
                : 'AutoPlay · watch the party',
            // Lit while on, and faintly lit for the rest of a run it played in.
            color: _autoplay.enabled
                ? _mint
                : _usedAutoplay
                ? _mint.withValues(alpha: .55)
                : _cream.withValues(alpha: .65),
            iconSize: 20,
            icon: Icon(
              _autoplay.enabled ? Icons.smart_toy : Icons.smart_toy_outlined,
            ),
          ),
        ),
      ],
    ),
  );

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
                if (cue.flourishTo != null)
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: Icon(Icons.open_with, color: _mint, size: 16),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _styleHint(Limb limb, Size size) {
    final at = _path(limb, _styleBeat, _styleNote ?? '', size).landing;
    return Positioned(
      left: at.x - 36,
      top: at.y - 36,
      child: IgnorePointer(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _mint.withValues(alpha: .1),
            border: Border.all(color: _mint.withValues(alpha: .7)),
          ),
          padding: const EdgeInsets.all(23),
          child: const Icon(Icons.open_with, color: _mint, size: 26),
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
    final look = _turnLook(session);
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
            Positioned(
              left: 0,
              right: 0,
              top: size.height * .62,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      look.color.withValues(alpha: 0),
                      look.color.withValues(alpha: look.glow),
                    ],
                  ),
                ),
              ),
            ),
            CustomPaint(
              painter: FeedbackPainter(
                _marks,
                _audio.nowSeconds,
                reducedMotion: _reducedMotion,
              ),
            ),
            if (countingIn)
              Positioned(
                top: size.height * .29,
                left: 0,
                right: 0,
                child: _lamps(4, count, _gold, 12),
              ),
            // At full support the room is at its peak, so only the finish phrases
            // left can say how close the level is. The cheap fix the research kept.
            if (finishing)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 68,
                left: 0,
                right: 0,
                child: _lamps(
                  session.peakChallengesRemaining,
                  session.peakChallengesRemaining,
                  _mint,
                  8,
                ),
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
    final paused = phase == GardenPhase.paused;
    final cleared = phase == GardenPhase.cleared;
    // The picture and the music carry a level's end. Only a failure to load the
    // next room, or the end of the campaign, brings the cover back.
    if (cleared && _conductor?.isPlaying == true) return _cinematicTitle(size);
    if (cleared && !_exitStarted && _error == null) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: ColoredBox(
        color: _ink.withValues(alpha: paused ? .82 : .38),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                SizedBox(height: math.max(58, size.height * .13)),
                Text(
                  cleared
                      ? ''
                      : paused
                      ? 'TAKE A BREATH'
                      : 'A LITTLE ROBOT. A BIG NIGHT.',
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
                  cleared
                      ? _level.copy.clearedTitle
                      : paused
                      ? 'STILL\nGROOVIN’.'
                      : 'KUMBIA\nKOMBAT',
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
                      : paused
                      ? 'Your groove will wait for you.'
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
                if (!cleared && !paused) ...[
                  Text(
                    _levels == null ? '' : _level.copy.invitation,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _cream, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final limb in [
                        Limb.leftHand,
                        Limb.rightHand,
                        Limb.leftHand,
                        Limb.leftHand,
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: SizedBox(
                            width: 20,
                            height: 25,
                            child: _limbIcon(limb, _mint),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap anywhere in the matching zone.\nFour-arrow cues invite a short flick for style.\nTaps alone keep the party going.',
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
                          : paused
                          ? 'SEGUIMOS  >'
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
                if (!paused)
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
