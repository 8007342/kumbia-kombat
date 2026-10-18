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
import 'progression.dart';
import 'rhythm.dart';
import 'rooms.dart';
import 'thumb_layout.dart';

const _cream = Color(0xFFFFF0D1);
const _gold = Color(0xFFFFC35F);
const _mint = Color(0xFF7CE2C4);
const _ink = Color(0xFF101F29);

class GardenPage extends StatefulWidget {
  const GardenPage({super.key, this.audioFactory});

  final GameAudio Function()? audioFactory;

  @override
  State<GardenPage> createState() => _GardenPageState();
}

class _GardenPageState extends State<GardenPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _scene = GardenSceneGame();
  final _focus = FocusNode();
  final _touches = <int, ({Offset start, String? note})>{};
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
  PartyRoom get _room => partyRooms[_roomIndex];
  final _exitScores = <String, MusicScore>{};
  TransitionConductor? _conductor;
  MusicHandoff? _handoff;
  bool _exitReady = false;
  bool _exitStarted = false;
  bool _handoffPaused = false;
  bool _adoptingRoom = false;
  bool _starting = false;
  bool _foreground = true;
  int _activationEpoch = 0;
  bool _reducedMotion = false;
  String? _error;
  String? _feedback;
  Limb? _styleDestination;
  double _styleUntil = 0;
  double _feedbackUntil = 0;
  Color _feedbackColor = _cream;
  String _resultSignature = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audio = (widget.audioFactory ?? createGameAudio)();
    _loadScore();
    _ticker = createTicker((_) {
      if (mounted &&
          (_session?.running == true || _conductor?.isPlaying == true)) {
        setState(() {});
      }
    })..start();
    _pump = Timer.periodic(const Duration(milliseconds: 20), (_) {
      final session = _session;
      if (session == null) return;
      if (_conductor != null) {
        _conductor!.pump();
        if (_conductor!.isPaused && !_handoffPaused) {
          _handoffPaused = true;
          if (mounted) setState(() {});
        }
        final next = _handoff?.nextTransport;
        if (_handoff != null && !_handoffPaused) {
          final from = _handoff!.bridgeAtSeconds;
          final to = _handoff!.nextAtSeconds;
          _scene.exitTravel = ((_audio.nowSeconds - from) / (to - from)).clamp(
            0.0,
            1.0,
          );
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
      if (!session.running) return;
      session.advance();
      final signature =
          '${session.progress.tier}:${session.progress.consecutiveFailures}:'
          '${session.progress.entranceResets}:${session.passedPhrases}';
      if (signature != _resultSignature) {
        _resultSignature = signature;
        if (session.lastOutcome == ChallengeOutcome.entranceReset) {
          _scene.resetEntrance();
          _showFeedback('BACK TO THE GATE', _gold);
        } else if (session.lastOutcome == ChallengeOutcome.retry) {
          _showFeedback('FIND THE GROOVE', _cream);
        } else if (session.lastOutcome != null) {
          _showFeedback('${_room.metric} +', _mint);
        }
      }
      if (session.phase == GardenPhase.paused ||
          session.phase == GardenPhase.cleared) {
        _touches.clear();
        if (mounted) setState(() {});
      }
    });
  }

  Future<void> _loadScore() async {
    try {
      for (final room in partyRooms) {
        final json = await rootBundle.loadString(
          'assets/music/scores/${room.score}.json',
        );
        _roomScores[room.score] = jsonDecode(json) as Map<String, dynamic>;
      }
      final data = _roomScores[_room.score]!;
      if (!mounted) return;
      _scoreData = data;
      _newSession();
      setState(() {});
      await _prepareExits();
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'The garden could not load. Please refresh.');
      }
    }
  }

  void _newSession() {
    _transport?.stop();
    _transport = MusicTransport(
      MusicScore.fromJson(_scoreData!),
      _audio,
      loop: true,
      lookaheadSeconds: .3,
    );
    _audio.leadShape = _room.leadShape;
    _session = GardenSession(
      _transport!,
      _audio,
      definition: fights[_roomIndex],
      chart: _roomIndex == 0 ? FightChart.garden : FightChart.bar,
    );
    _scene.session = _session;
    _feedback = null;
    _resultSignature = '';
    _exitStarted = false;
  }

  Future<void> _prepareExits() async {
    try {
      for (final id in [
        'garden_mojo_success',
        'bar_swag_success',
        'garden_to_bar',
      ]) {
        final data =
            jsonDecode(
                  await rootBundle.loadString('assets/music/scores/$id.json'),
                )
                as Map<String, dynamic>;
        _exitScores[id] = MusicScore.fromJson(data);
      }
      await _scene.loaded;
      await Future.wait([
        _scene.images.load(partyRooms[1].background),
        _scene.images.load(partyRooms[1].challenger),
      ]);
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
    _conductor = TransitionConductor(_audio, lookaheadSeconds: .3);
    if (_roomIndex + 1 < partyRooms.length) {
      _handoff = _conductor!.handoff(
        source: _transport!,
        success: _exitScores['${_room.score}_success']!,
        bridge: _exitScores['garden_to_bar']!,
        nextScore: MusicScore.fromJson(
          _roomScores[partyRooms[_roomIndex + 1].score]!,
        ),
      );
    } else {
      _conductor!.finish(
        source: _transport!,
        success: _exitScores['${_room.score}_success']!,
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> _adoptNextRoom() async {
    _adoptingRoom = true;
    final nextIndex = _roomIndex + 1;
    final next = _handoff!.nextTransport;
    try {
      await _scene.showRoom(
        partyRooms[nextIndex].background,
        partyRooms[nextIndex].challenger,
      );
      if (!mounted || !_foreground || _conductor?.isPaused == true) return;
      _bankedPizazz += _session!.pizazz;
      _bankedPerfects += _session!.perfects;
      _roomIndex = nextIndex;
      _scoreData = _roomScores[_room.score];
      _transport = next;
      _audio.leadShape = _room.leadShape;
      _session = GardenSession(
        next,
        _audio,
        definition: fights[_roomIndex],
        chart: FightChart.bar,
      )..start(startTransport: false);
      _scene.session = _session;
      // Old decks have scheduled their own releases; never stop/silence them here.
      _handoff = null;
      _conductor = null;
      _exitStarted = false;
      _feedback = null;
      _styleDestination = null;
      _resultSignature = '';
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
        _roomIndex = 0;
        _bankedPizazz = 0;
        _bankedPerfects = 0;
        _scoreData = _roomScores[_room.score];
        await _scene.showRoom(_room.background, _room.challenger);
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
              'Sound needs your permission. Tap again to start the music.',
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _pause() {
    if (_conductor?.isPlaying == true) {
      _conductor!.pause();
      _handoffPaused = true;
    } else {
      _session?.pause();
    }
    _touches.clear();
    setState(() {});
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
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _activationEpoch++;
    if (state != AppLifecycleState.resumed &&
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

  void _showFeedback(String text, Color color) {
    _feedback = text;
    _feedbackColor = color;
    _feedbackUntil = _audio.nowSeconds + .65;
  }

  TapResult _tap(Limb limb) {
    final result = _session!.tap(limb);
    if (result.note != null) {
      _scene.dance(limb);
      _styleDestination = result.note!.flourishTo;
      _styleUntil = _audio.nowSeconds + .3;
      _showFeedback(
        result.grade == TapGrade.perfect ? 'PERFECT' : 'NICE',
        result.grade == TapGrade.perfect ? _gold : _mint,
      );
    }
    return result;
  }

  Limb? _limbAt(Offset point, Size size) =>
      thumbLimbAt(point.dx / size.width, point.dy / size.height);

  Offset _anchor(Limb limb, Size size, [double hitBeat = 0]) {
    final point = thumbAnchor(limb, hitBeat);
    return Offset(point.x * size.width, point.y * size.height);
  }

  Offset _cuePosition(GardenCue cue, Size size) {
    final path = tornadoPosition(
      cue.limb,
      cue.progress,
      reducedMotion: _reducedMotion,
    );
    final target = _anchor(cue.limb, size, cue.beat);
    final left = cue.limb == Limb.leftHand || cue.limb == Limb.leftFoot;
    final upper = cue.limb == Limb.leftHand || cue.limb == Limb.rightHand;
    final tx = ((path.x - .5) / (left ? -.41 : .41)).clamp(0.0, 1.0);
    final ty = ((path.y - .5) / (upper ? -.40 : .40)).clamp(0.0, 1.0);
    final origin = Offset(size.width * .5, size.height * .47);
    return Offset(
      origin.dx + (target.dx - origin.dx) * tx,
      origin.dy + (target.dy - origin.dy) * ty,
    );
  }

  void _ornament(String gesture) {
    final transport = _transport!;
    final data =
        (_scoreData!['adornments'] as List).firstWhere(
              (entry) => entry['gesture'] == gesture,
              orElse: () => (_scoreData!['adornments'] as List).first,
            )
            as Map<String, dynamic>;
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
    _scene.flourishBeat = _session!.positionBeats;
    _showFeedback('¡PIZAZZ!', _mint);
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
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    GameWidget(game: _scene),
                    if (active)
                      Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (event) {
                          final limb = _limbAt(event.localPosition, size);
                          if (limb == null) return;
                          final result = _tap(limb);
                          _touches[event.pointer] = (
                            start: event.localPosition,
                            note: result.note?.id,
                          );
                        },
                        onPointerUp: (event) {
                          final touch = _touches.remove(event.pointer);
                          if (touch == null ||
                              touch.note == null ||
                              (event.localPosition - touch.start).distance <
                                  36) {
                            return;
                          }
                          final destination = _limbAt(
                            event.localPosition,
                            size,
                          );
                          if (destination != null &&
                              session.flourish(touch.note!, destination)) {
                            final delta = event.localPosition - touch.start;
                            final gesture = delta.dx.abs() > delta.dy.abs()
                                ? (delta.dx > 0 ? 'right' : 'left')
                                : (delta.dy > 0 ? 'down' : 'up');
                            _ornament(gesture);
                          }
                        },
                        onPointerCancel: (event) =>
                            _touches.remove(event.pointer),
                        child: Stack(
                          children: [
                            for (final limb in Limb.values)
                              if (!session!.visibleCues.any(
                                (cue) => cue.limb == limb,
                              ))
                                _target(limb, size),
                            for (final cue in session!.visibleCues)
                              _target(cue.limb, size, cue.beat),
                            for (final cue in session.visibleCues)
                              _cue(cue, size),
                            if (_styleDestination != null &&
                                _audio.nowSeconds < _styleUntil)
                              _styleHint(_styleDestination!, size),
                          ],
                        ),
                      ),
                    if (active)
                      IgnorePointer(child: _fightLabels(session!, size)),
                    if (!active) _cover(phase, size),
                    _header(active || _conductor?.isPlaying == true),
                    if (active)
                      Positioned(
                        top: MediaQuery.paddingOf(context).top + 68,
                        left: 20,
                        right: 20,
                        child: _respect(session!),
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
            '${(_roomIndex + 1).toString().padLeft(2, '0')} / 05',
            style: const TextStyle(
              color: _cream,
              fontFamily: 'Kumbia',
              fontSize: 11,
            ),
          ),
      ],
    ),
  );

  Widget _respect(GardenSession session) => Column(
    children: [
      Row(
        children: [
          Text(
            _room.metric,
            style: const TextStyle(
              color: _gold,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              fontSize: 11,
            ),
          ),
          const Spacer(),
          Text(
            '${_bankedPizazz + session.pizazz} PIZAZZ',
            style: const TextStyle(
              color: _mint,
              fontFamily: 'Kumbia',
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: List.generate(
          5,
          (i) => Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              color: i <= session.progress.tier
                  ? _gold
                  : _cream.withValues(alpha: .18),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _target(Limb limb, Size size, [double hitBeat = 0]) {
    final at = _anchor(limb, size, hitBeat);
    return Positioned(
      left: at.dx - 29,
      top: at.dy - 29,
      child: IgnorePointer(
        child: Opacity(
          opacity: .30,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _cream, width: 1),
            ),
            padding: const EdgeInsets.all(14),
            child: _limbIcon(limb, _cream),
          ),
        ),
      ),
    );
  }

  Widget _cue(GardenCue cue, Size size) {
    final at = _cuePosition(cue, size);
    final extent = 25 + cue.progress * 21;
    final color = cue.demo ? _gold : _mint;
    return Positioned(
      left: at.dx - extent / 2,
      top: at.dy - extent / 2,
      child: IgnorePointer(
        child: Opacity(
          opacity: cue.demo ? .45 + cue.progress * .25 : .6 + cue.progress * .4,
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
                    child: Icon(Icons.south_east, color: _cream, size: 12),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _styleHint(Limb limb, Size size) {
    final at = _anchor(limb, size);
    return Positioned(
      left: at.dx - 36,
      top: at.dy - 36,
      child: IgnorePointer(
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _mint.withValues(alpha: .1),
                border: Border.all(color: _mint.withValues(alpha: .7)),
              ),
              padding: const EdgeInsets.all(23),
              child: _limbIcon(limb, _mint),
            ),
            Text(
              'SWIPE ${const ['LH', 'RH', 'LF', 'RF'][limb.index]}',
              style: const TextStyle(
                color: _mint,
                fontSize: 8,
                letterSpacing: 1,
              ),
            ),
          ],
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

  Widget _fightLabels(GardenSession session, Size size) {
    final untilStart =
        _transport!.secondsAt(_transport!.positionBeats) - _audio.nowSeconds;
    final count =
        (untilStart / (60 / _transport!.score.tempos[_transport!.currentTier]))
            .ceil()
            .clamp(1, 4);
    final label = _transport!.countingIn
        ? 'READY  $count'
        : switch (session.phase) {
            GardenPhase.intro => 'FEEL THE PULSE',
            GardenPhase.call => 'WATCH THE CALL',
            _ => 'YOUR TURN',
          };
    return Stack(
      children: [
        Positioned(
          top: size.height * .29,
          left: 20,
          right: 20,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: _ink.withValues(alpha: .80),
              child: Text(
                label,
                style: TextStyle(
                  color: session.phase == GardenPhase.call ? _gold : _mint,
                  fontSize: 10,
                  letterSpacing: 2.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        if (_feedback != null && _audio.nowSeconds < _feedbackUntil)
          Positioned(
            top: size.height * .57,
            left: 20,
            right: 20,
            child: Center(
              child: Text(
                _feedback!,
                style: TextStyle(
                  color: _feedbackColor,
                  letterSpacing: 3,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  shadows: const [Shadow(blurRadius: 8, color: _ink)],
                ),
              ),
            ),
          ),
        Positioned(
          bottom: MediaQuery.paddingOf(context).bottom + 18,
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                session.phase == GardenPhase.call
                    ? 'LOOK. LISTEN. REPEAT.'
                    : 'TAP WHEN THE ICON LANDS.',
                style: TextStyle(
                  color: _cream.withValues(alpha: .6),
                  letterSpacing: 1.6,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cover(GardenPhase phase, Size size) {
    final paused = phase == GardenPhase.paused;
    final cleared = phase == GardenPhase.cleared;
    if (cleared && _conductor?.isPlaying == true) {
      return Positioned.fill(
        child: IgnorePointer(
          child: Stack(
            children: [
              Positioned(
                top: size.height * .18,
                left: 24,
                right: 24,
                child: Column(
                  children: [
                    Text(
                      _roomIndex == 0 ? 'MUCHO MOJO.' : 'PURO SWAG.',
                      style: const TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                        letterSpacing: -1,
                        shadows: [Shadow(color: _ink, blurRadius: 12)],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'OK, YOU COOL.',
                      style: TextStyle(
                        color: _mint,
                        fontSize: 10,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: size.height * .12,
                left: 24,
                right: 24,
                child: Text(
                  _roomIndex == 0
                      ? 'FOLLOW THE GROOVE TO THE BAR'
                      : 'THE CROWD IS NEXT',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _cream,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
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
                      ? 'RESPECT EARNED'
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
                      ? (_roomIndex == 0 ? 'MUCHO\nMOJO.' : 'PURO\nSWAG.')
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
                      ? (_roomIndex == 0
                            ? 'THE GATE IS YOURS.'
                            : 'THE BAR IS YOURS.')
                      : paused
                      ? 'Your groove will wait for you.'
                      : '${(_roomIndex + 1).toString().padLeft(2, '0')}  /  ${_room.title}',
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                if (cleared)
                  Text(
                    '${_bankedPerfects + _session!.perfects} PERFECT  ·  ${_bankedPizazz + _session!.pizazz} PIZAZZ',
                    style: const TextStyle(
                      color: _cream,
                      fontFamily: 'Kumbia',
                      fontSize: 11,
                    ),
                  ),
                if (!cleared && !paused) ...[
                  Text(
                    _room.invitation,
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
                    'Four zones. One thumb. A little Pizazz.',
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
                          : _conductor?.isPlaying == true
                          ? 'FOLLOW THE GROOVE'
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
                  cleared
                      ? (_roomIndex == 0
                            ? 'NEXT: SWAG AT THE BAR'
                            : 'NEXT: FLOW IN THE CROWD')
                      : 'A KUMBIA KOLISEUM NIGHT',
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
