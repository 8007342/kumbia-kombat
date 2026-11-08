import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/crowd_interest.dart';
import 'package:kumbia_kombat/gameplay/dance_floor.dart';
import 'package:kumbia_kombat/gameplay/dance_line.dart';
import 'package:kumbia_kombat/gameplay/garden_scene.dart';
import 'package:kumbia_kombat/gameplay/garden_session.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/gameplay/party_autoplay.dart';
import 'package:kumbia_kombat/gameplay/party_up.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';
import 'package:kumbia_kombat/gameplay/room_layers.dart';
import 'package:kumbia_kombat/gameplay/thumb_layout.dart';
import 'package:kumbia_kombat/music/score.dart';
import 'package:kumbia_kombat/music/transport.dart';

/// Mansion act two: the levels of `plan/levels/mansion-act-two-2026-11-08.md`,
/// on real game code and their real files. What is wired, what stands in and
/// how it was checked: `plan/levels/act-two-wiring-2026-11-08.md`.
String _read(String id) => File('levels/$id.json').readAsStringSync();

LevelRegistry _registry() =>
    LevelRegistry.parse(File('levels/index.json').readAsStringSync(), _read);

class _Audio implements MusicAudioBackend {
  @override
  double nowSeconds = 0;
  @override
  bool ready = true;
  @override
  void silence() {}
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {}
}

Map<String, dynamic> _scoreJson(String id) =>
    jsonDecode(File('assets/music/scores/$id.json').readAsStringSync())
        as Map<String, dynamic>;

MusicScore _score(String id) => MusicScore.fromJson(_scoreJson(id));

List<double> _tierBpm(String id) => [
  for (final tier in _scoreJson(id)['tiers'] as List)
    ((tier as Map)['bpm'] as num).toDouble(),
];

Map<String, dynamic> _atlases() =>
    (jsonDecode(File('assets/art/ensemble/manifest.json').readAsStringSync())
            as Map<String, dynamic>)['atlases']
        as Map<String, dynamic>;

Set<String> _frames(String atlas) =>
    ((_atlases()[atlas] as Map)['frames'] as Map).keys.cast<String>().toSet();

/// What each level is, from the design note.
class _Spec {
  const _Spec(
    this.id, {
    required this.after,
    required this.title,
    required this.metric,
    required this.cleared,
    required this.combo,
    required this.style,
  });
  final String id, after, title, metric, cleared, combo;

  /// How its chart dances to its music, checked note by note below.
  final void Function(String id, ChartPattern pattern, int index) style;
}

bool _onBeat(double at) => at % 1 == 0;

/// Polka: the feet take the oom, every foot on a beat in the early tiers; the
/// hands take the pah, the "and", wherever a hand stands alone on one.
void _polka(String id, ChartPattern pattern, int index) {
  for (var i = 0; i < pattern.limbs.length; i++) {
    final at = pattern.offsets[i];
    if (index <= 2 && !limbIsUpper(pattern.limbs[i])) {
      expect(_onBeat(at), isTrue, reason: '$id pattern $index foot at $at');
    }
  }
  final hands = [
    for (var i = 0; i < pattern.limbs.length; i++)
      if (!!limbIsUpper(pattern.limbs[i])) pattern.offsets[i],
  ];
  final offBeat = hands.where((at) => !_onBeat(at)).length;
  expect(offBeat, greaterThanOrEqualTo(hands.length ~/ 2), reason: '$id $index');
}

/// Reel: the feet stamp the beats the take accents, both together on the one
/// from tier 1. Only the top tier's pickups (x.25) leave the beat, and the
/// rigid arms never outnumber the feet.
void _reel(String id, ChartPattern pattern, int index) {
  final peak = index >= 4;
  for (var i = 0; i < pattern.limbs.length; i++) {
    final at = pattern.offsets[i];
    expect(
      _onBeat(at) || (peak && at % 1 == .25),
      isTrue,
      reason: '$id pattern $index ${pattern.limbs[i]} at $at',
    );
  }
  final hands = pattern.limbs.where(limbIsUpper).length;
  expect(hands, lessThanOrEqualTo(pattern.limbs.length - hands));
  if (index > 0) {
    final onOne = [
      for (var i = 0; i < pattern.limbs.length; i++)
        if (pattern.offsets[i] == 0) pattern.limbs[i],
    ];
    expect(onOne, containsAll([Limb.leftFoot, Limb.rightFoot]));
  }
}

/// Samba: the feet take the beat and its "and", the hips and hands the
/// syncopated sixteenths; every hand stands off the beat.
void _samba(String id, ChartPattern pattern, int index) {
  for (var i = 0; i < pattern.limbs.length; i++) {
    final at = pattern.offsets[i];
    if (limbIsUpper(pattern.limbs[i])) {
      expect(_onBeat(at), isFalse, reason: '$id pattern $index hand at $at');
    } else {
      expect(at % .5, 0, reason: '$id pattern $index foot at $at');
    }
  }
  final sixteenths = pattern.offsets.where((at) => at % .5 != 0).length;
  expect(sixteenths, greaterThanOrEqualTo(3), reason: '$id $index');
}

const _specs = [
  _Spec(
    'comedor',
    after: 'billiards',
    title: 'EL GRAN COMEDOR',
    metric: 'Gusto',
    cleared: 'QUÉ BANQUETE',
    combo: 'LA TORRE DE CHAROLAS',
    style: _polka,
  ),
  _Spec(
    'galeria',
    after: 'salon',
    title: 'LA GALERÍA',
    metric: 'Drive',
    cleared: 'QUÉ ZAPATEO',
    combo: 'EL MURO DE TACONES',
    style: _reel,
  ),
  _Spec(
    'terraza',
    after: 'galeria',
    title: 'LA TERRAZA',
    metric: 'Joy',
    cleared: 'QUÉ CHISPA',
    combo: 'LA LLUVIA DE CONFETI',
    style: _samba,
  ),
];

Future<ui.Image> _still(GardenSceneGame scene, int w, int h) async {
  scene.onGameResize(Vector2(w.toDouble(), h.toDouble()));
  final recorder = ui.PictureRecorder();
  scene.render(ui.Canvas(recorder));
  return recorder.endRecording().toImage(w, h);
}

Future<void> _sheet(List<ui.Image> images, String path) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  for (final (i, image) in images.indexed) {
    canvas.drawImage(image, ui.Offset(i * 396.0, 0), ui.Paint());
  }
  final sheet = await recorder.endRecording().toImage(396 * images.length, 844);
  final png = await sheet.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final spec in _specs) {
    group(spec.id, () {
      final registry = _registry();
      final at = registry.campaign.indexWhere((s) => s.level.id == spec.id);
      final step = registry.campaign[at];
      final level = step.level;
      final chart = level.chart;
      final bpm = _tierBpm(level.music.score);

      test('its place, title, metric, words and combo', () {
        expect(at, greaterThan(0));
        expect(registry.campaign[at - 1].level.id, spec.after);
        expect(registry.campaign[at - 1].next, same(level));
        expect(level.title, spec.title);
        expect(level.rules.metric, spec.metric);
        expect(level.copy.clearedShout, spec.cleared);
        expect(level.hardestCombo!.name, spec.combo);
        // FEEL's rules, 2026-11-07: six of eight steps before the peak, three
        // passes at it.
        expect(level.rules.earlyHitRatio, .75);
        expect(level.rules.finalChallenges, 3);
        expect(level.rules.requiredHits(8, atPeak: false), 6);
      });

      test('fair at every tempo it plays, synth and rendered', () {
        // The synth ladder plays one tempo a tier; the rendered takes play the
        // low, mid and high ones. Each tier is held to the faster of the two.
        for (var tier = 0; tier < 5; tier++) {
          for (var peak = 0; peak < (tier == 4 ? 3 : 1); peak++) {
            final index = chart.patternIndex(tier, peak);
            expect(
              chart.fairnessProblems(index, bpm[tier]),
              isEmpty,
              reason: 'tier $tier at ${bpm[tier]}',
            );
          }
        }
      });

      test('the same limb never comes back inside a beat and a half', () {
        for (var i = 0; i <= chart.variants.length; i++) {
          final played = chart.pattern(i);
          for (var a = 0; a < played.limbs.length; a++) {
            for (var b = a + 1; b < played.limbs.length; b++) {
              if (played.limbs[a] != played.limbs[b]) continue;
              if (played.stepOf[a] == played.stepOf[b]) continue;
              expect(
                played.offsets[b] - played.offsets[a],
                greaterThanOrEqualTo(1.5),
                reason: 'pattern $i',
              );
            }
          }
        }
      });

      test('it dances its music', () {
        for (var i = 0; i <= chart.variants.length; i++) {
          spec.style(spec.id, chart.pattern(i), i);
        }
      });

      test('richer as it climbs, and the peak asks the most', () {
        var previous = -1;
        for (var tier = 0; tier < 5; tier++) {
          final played = chart.pattern(chart.patternIndex(tier, 0));
          expect(played.richSteps, greaterThanOrEqualTo(previous));
          previous = played.richSteps;
        }
        expect(chart.pattern(0).richSteps, 0, reason: 'tier 0 teaches it');
      });

      test('the hardest combo can be hit at the top tempo', () {
        final notes = level.hardestCombo!.chart.offsets;
        final top = bpm.reduce(math.max);
        for (var i = 1; i < notes.length; i++) {
          expect(
            (notes[i] - notes[i - 1]) * 60000 / top,
            greaterThanOrEqualTo(RhythmJudge.goodWindowMs),
          );
        }
      });

      test('a flawless autoplay run clears it', () {
        final audio = _Audio();
        final music = MusicTransport(
          _score(level.music.score),
          audio,
          loop: true,
          lookaheadSeconds: .3,
        );
        final session = level.newSession(music, audio)..start();
        final demo = PartyAutoplay(flawless: true)..enabled = true;
        while (session.phase != GardenPhase.cleared && audio.nowSeconds < 600) {
          audio.nowSeconds += .02;
          music.pump();
          session.advance();
          demo.pump(session);
        }
        expect(session.phase, GardenPhase.cleared);
      });

      test('every guest has every drawing their clips name', () {
        for (final slot in level.layout.guests) {
          final clips = level.guestClips[slot.clips];
          if (clips == null) continue;
          expect(
            _frames(slot.atlas!),
            containsAll(clips.frames.toSet()),
            reason: '${slot.id} ${slot.atlas}',
          );
          for (final clip in CrowdClip.values) {
            expect(clips.clips[clip], isNotNull, reason: '$clip');
          }
        }
      });

      test('room life waits for the top tiers', () {
        final life = level.layers.where((p) => p.kind == PartyLifeKind.artwork);
        for (final prop in life) {
          expect(prop.minTier, greaterThanOrEqualTo(3), reason: prop.id);
          // Below its tier, even full swing leaves it at rest.
          expect(prop.frameAt(beat: 3, swing: 0), prop.restFrame);
        }
      });

      test('its win fits the music, and every drawing ships', () {
        final shot = level.exitShot!;
        for (final image in shot.images) {
          expect(File('assets/art/$image').existsSync(), isTrue, reason: image);
        }
        final his = _frames(level.stage.challengers.single.atlas);
        for (final clip in shot.opponent) {
          expect(his, containsAll(clip.frames.toSet()), reason: clip.frames.first);
        }
        final success = _score(level.music.successScore).lengthBeats;
        final end = success +
            (step.bridgeToNext == null
                ? 0
                : _score(step.bridgeToNext!).lengthBeats);
        expect(shot.closeupTo, lessThanOrEqualTo(step.next == null ? end : end - 4));
        expect(shot.contactBeat % 1, 0, reason: 'contact on a beat');
        final walk = shot.walkOut;
        if (walk != null) {
          expect(walk.from, greaterThanOrEqualTo(shot.closeupTo));
          expect(walk.to, lessThanOrEqualTo(end));
        }
      });

      test('stills of the room and its win through the real scene', () async {
        final scene = GardenSceneGame(firstLevel: () async => level);
        scene.onGameResize(Vector2(390, 844));
        await scene.onLoad();
        await scene.showLevel(level);
        Directory('build/stills').createSync(recursive: true);
        final audio = _Audio();
        final music = MusicTransport(
          _score(level.music.score),
          audio,
          loop: true,
          lookaheadSeconds: .3,
        );
        final session = level.newSession(music, audio);
        scene.session = session;
        session.start();
        final demo = PartyAutoplay(flawless: true)..enabled = true;
        final opening = <ui.Image>[];
        final seen = <double>[];
        void advance(double target) {
          while (audio.nowSeconds < target - 1e-6 &&
              session.phase != GardenPhase.cleared) {
            audio.nowSeconds = math.min(target, audio.nowSeconds + .02);
            music.pump();
            session.advance();
            demo.pump(session);
            scene.update(.02);
          }
        }

        await _still(scene, 390, 844);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        for (final beat in [3.0, chart.introBeats + 2]) {
          advance(music.secondsAt(beat));
          opening.add(await _still(scene, 390, 844));
          seen.add(beat);
        }
        // The top tier, where room life wakes.
        while (session.phase != GardenPhase.cleared &&
            music.tierAt(session.positionBeats) < 4 &&
            audio.nowSeconds < 600) {
          advance(audio.nowSeconds + .5);
        }
        advance(audio.nowSeconds + 20);
        opening.add(await _still(scene, 390, 844));
        await _sheet(opening, 'build/stills/${level.id}-opening.png');
        advance(900);
        expect(session.phase, GardenPhase.cleared);
        final win = <ui.Image>[];
        for (final beat in [1.0, 3.0, 5.0, 6.25, 8.0, 10.5, 12.5, 15.0, 18.0]) {
          scene.exitBeat = beat;
          win.add(await _still(scene, 390, 844));
        }
        await _sheet(win, 'build/stills/${level.id}-win.png');
      });
    });
  }

  group('the galería line, five as one', () {
    final level = _registry().byId('galeria');
    final lead = level.stage.challengers.single;
    final line = lead.line!;

    test('five dancers, each at most half a beat behind the lead', () {
      expect(line.dancers, hasLength(4));
      for (final dancer in line.dancers) {
        expect(dancer.lagBeats, inInclusiveRange(0, DanceLine.maxLagBeats));
      }
      // The ripple runs out from the centre: the ends are the latest.
      expect(line.dancers.first.lagBeats, line.dancers.last.lagBeats);
    });

    test('the arch is drawn, and he walks out between its two sides', () {
      final arch = line.arch!;
      expect(_frames(lead.atlas), containsAll(arch.frames));
      final shot = level.exitShot!;
      expect(arch.from + arch.beats, lessThanOrEqualTo(shot.closeupFrom));
      final meet = lead.meetMark!;
      final sides = [
        for (final d in line.dancers) meet.x + d.archOffset!.x,
      ];
      final door = level.heroExitFloor(level.route.sample(1));
      expect(sides.where((x) => x < door.x), hasLength(2));
      expect(sides.where((x) => x > door.x), hasLength(2));
      // Facing each other across the arch.
      for (final d in line.dancers) {
        expect(d.archMirrored, meet.x + d.archOffset!.x > door.x);
      }
    });

    test('the loader refuses a dancer too late, or off the floor', () {
      Map<String, dynamic> json() =>
          jsonDecode(_read('galeria')) as Map<String, dynamic>;
      Map<String, dynamic> first(Map<String, dynamic> j) =>
          ((((j['stage'] as Map)['challengers'] as List).single as Map)['line']
                  as Map)['dancers'][0]
              as Map<String, dynamic>;
      final late = json();
      first(late)['lagBeats'] = 1;
      expect(() => LevelDefinition.fromJson(late), throwsA(isA<LevelDataError>()));
      final off = json();
      first(off)['offset'] = [0, .3];
      expect(() => LevelDefinition.fromJson(off), throwsA(isA<LevelDataError>()));
    });

    test('a late dancer holds the arch\'s drawing once it forms', () {
      const arch = LineArch(from: 1, beats: 2, frames: ['up_a', 'up_b']);
      expect(arch.frameAt(1.5), isNull);
      expect(arch.frameAt(2), 'up_a');
      expect(arch.frameAt(3), 'up_b');
      expect(arch.frameAt(9), 'up_b', reason: 'held, not looped');
      expect(arch.frameAt(2, reducedMotion: true), 'up_b');
      const still = DanceLine(dancers: [], arch: LineArch(from: 1, beats: 2));
      expect(still.archAt(1), 0);
      expect(still.archAt(3), 1);
      expect(still.archAt(2), closeTo(.5, 1e-9));
      expect(still.archAt(1.9, reducedMotion: true), 0);
    });
  });

  test('the web build bundles every folder a level or a rendered take names', () {
    // Asset folders aren't recursive: a folder missing from pubspec.yaml loads
    // in these tests, which read files, and fails in the browser.
    final listed = {
      for (final line in File('pubspec.yaml').readAsLinesSync())
        if (line.trim().startsWith('- assets/')) line.trim().substring(2),
    };
    String folder(String path) => '${path.substring(0, path.lastIndexOf('/'))}/';
    final registry = _registry();
    for (final level in registry.levels) {
      final paths = [
        level.background,
        for (final prop in level.layers) prop.atlas,
        ...?level.exitShot?.images,
      ];
      for (final path in paths) {
        expect(listed, contains(folder('assets/art/$path')), reason: '${level.id} $path');
      }
    }
    final rendered =
        (jsonDecode(File('assets/music/rendered/manifest.json').readAsStringSync())
                as Map<String, dynamic>)['levels']
            as Map<String, dynamic>;
    for (final id in rendered.keys) {
      expect(listed, contains('assets/music/rendered/$id/'), reason: id);
    }
  });

  group('the general pieces, refused when wrong', () {
    Map<String, dynamic> comedor() =>
        jsonDecode(_read('comedor')) as Map<String, dynamic>;
    Matcher refused(String text) => throwsA(
      isA<LevelDataError>().having((e) => e.toString(), 'error', contains(text)),
    );

    test('a layer waiting for a tier past the top', () {
      final json = comedor();
      ((json['layers'] as Map)['props'] as List).first['minTier'] = 5;
      expect(() => LevelDefinition.fromJson(json), refused('minTier'));
    });

    test('a clip set missing a step of the meter', () {
      final json = comedor();
      (((json['crowd'] as Map)['clipSets'] as Map)['diner'] as Map)
          .remove('cheer');
      expect(() => LevelDefinition.fromJson(json), refused('cheer'));
    });

    test('a guest naming no clip set, or clips with no atlas', () {
      final json = comedor();
      ((json['crowd'] as Map)['guests'] as List).first['clips'] = 'nobody';
      expect(() => LevelDefinition.fromJson(json), refused('no such clip set'));
      final bare = comedor();
      ((bare['crowd'] as Map)['guests'] as List).first.remove('atlas');
      expect(() => LevelDefinition.fromJson(bare), refused('atlas'));
    });

    test('a misspelt clip field', () {
      final json = comedor();
      ((((json['crowd'] as Map)['clipSets'] as Map)['diner'] as Map)['clap']
              as Map)['beatPerFrame'] =
          1;
      expect(() => LevelDefinition.fromJson(json), refused('beatPerFrame'));
    });
  });

  group('drawings by the meter', () {
    const set = GuestClipSet(
      reference: 'toast_a',
      clips: {
        CrowdClip.seatedIdle: GuestClip(['eat_a', 'eat_b']),
        CrowdClip.standUp: GuestClip(['rise_a', 'toast_a'], once: true),
      },
      applause: GuestClip(['rise_a', 'toast_a', 'toast_b']),
    );
    CrowdGuestSnapshot guest(CrowdClip clip, double clipBeat, double phase) =>
        CrowdGuestSnapshot(
          interest: 0,
          state: CrowdGuestState.occupied,
          styleEnergy: 0,
          reactionBeat: 0,
          clip: clip,
          clipBeat: clipBeat,
          clipDurationBeats: 2,
          transitioning: clip == CrowdClip.standUp,
          standing: false,
          archetypeIndex: 0,
          paletteIndex: 0,
          phaseOffset: phase,
        );

    test('loops change on the beat, a whole drawing apart', () {
      expect(set.frame(guest(CrowdClip.seatedIdle, 0, 0), 4.0), 'eat_a');
      expect(set.frame(guest(CrowdClip.seatedIdle, 0, 0), 4.99), 'eat_a');
      expect(set.frame(guest(CrowdClip.seatedIdle, 0, 0), 5.0), 'eat_b');
      expect(set.frame(guest(CrowdClip.seatedIdle, 0, .9), 4.0), 'eat_b');
      expect(
        set.frame(guest(CrowdClip.seatedIdle, 0, 0), 5, reducedMotion: true),
        'eat_a',
      );
    });

    test('rising runs once and holds', () {
      expect(set.frame(guest(CrowdClip.standUp, 0, 0), 9), 'rise_a');
      expect(set.frame(guest(CrowdClip.standUp, 1.5, 0), 9), 'toast_a');
      expect(set.frame(guest(CrowdClip.standUp, 30, 0), 9), 'toast_a');
    });

    test('the toast: rise once, then raise the glass on the beat', () {
      expect(set.applauseFrame(0), 'rise_a');
      expect(set.applauseFrame(1), 'toast_a');
      expect(set.applauseFrame(2), 'toast_b');
      expect(set.applauseFrame(3), 'toast_a');
      expect(set.applauseFrame(0, reducedMotion: true), 'toast_b');
    });

    test('a snap on 2 and 4: the phase moves the peak a beat', () {
      const snap = RoomLayerProp(
        id: 'snap',
        atlas: 'x.png',
        atlasY: 0,
        left: 0,
        top: 0,
        width: 10,
        height: 10,
        frames: 2,
        motion: RoomLayerMotion.pulse,
        periodBeats: 2,
        instance: 0,
        kind: PartyLifeKind.artwork,
        minTier: 4,
        phaseBeats: 1,
      );
      expect(snap.frameAt(beat: 1, swing: 0, life: 1), 1);
      expect(snap.frameAt(beat: 2, swing: 0, life: 1), 0);
      expect(snap.frameAt(beat: 3, swing: 0, life: 1), 1);
      expect(snap.frameAt(beat: 3, swing: 0, life: 0), 0);
    });
  });
}
