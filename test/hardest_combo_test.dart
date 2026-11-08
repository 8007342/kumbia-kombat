import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kumbia_kombat/gameplay/dance_grammar.dart';
import 'package:kumbia_kombat/gameplay/gesture_shapes.dart';
import 'package:kumbia_kombat/gameplay/level_definition.dart';
import 'package:kumbia_kombat/gameplay/rhythm.dart';

String _file(String id) => File('levels/$id.json').readAsStringSync();
Map<String, Object?> _json(String id) =>
    jsonDecode(_file(id)) as Map<String, Object?>;

LevelRegistry _registry() =>
    LevelRegistry.parse(File('levels/index.json').readAsStringSync(), _file);

/// Garden with its combo edited.
Map<String, Object?> _gardenWith(void Function(Map<String, Object?>) edit) {
  final json = _json('garden');
  edit(json['hardestCombo']! as Map<String, Object?>);
  return json;
}

Matcher _refused(String part) => throwsA(
  isA<LevelDataError>().having((e) => e.toString(), 'message', contains(part)),
);

void main() {
  final grammar = DanceGrammar.fromJson(
    jsonDecode(
          File('assets/art/ensemble/choreography.json').readAsStringSync(),
        )
        as Map<String, dynamic>,
  );

  group('the shipped combos', () {
    test('every opponent has a named combo, and all are proposals', () {
      final registry = _registry();
      final names = {
        for (final level in registry.levels) level.id: level.hardestCombo!.name,
      };
      expect(names, {
        'garden': 'The Velvet Rope',
        'pool-garden': 'Round Robin',
        'bar': 'Last Call',
        'cool-crowd': 'All That Glitters',
        'billiards': 'Tres Bandas',
        'comedor': 'LA TORRE DE CHAROLAS',
        'salon': 'EL GIRO DE TERCIOPELO',
        'galeria': 'EL MURO DE TACONES',
        'terraza': 'LA LLUVIA DE CONFETI',
      });
      expect(registry.upcomingOpponents, isEmpty);
      for (final combo in registry.levels.map((l) => l.hardestCombo!)) {
        expect(combo.status, HardestComboStatus.proposal, reason: combo.name);
      }
    });

    test('every move is a clip that dancer has today, in whole loops', () {
      for (final level in _registry().levels) {
        for (final move in level.hardestCombo!.moves) {
          expect(
            () => grammar.requireClips(move.dancer, [move.clip]),
            returnsNormally,
            reason: '${level.id} ${move.dancer} ${move.clip}',
          );
          final length = grammar.clipBeats(move.dancer, move.clip);
          final loops = move.beats / length;
          expect(
            loops,
            closeTo(loops.roundToDouble(), 1e-9),
            reason: '${level.id} ${move.clip} runs $length, given ${move.beats}',
          );
        }
      }
    });

    test('every call is danced from start to finish, by every dancer', () {
      final registry = _registry();
      for (final combo in registry.levels.map((l) => l.hardestCombo!)) {
        for (final dancer in combo.moves.map((m) => m.dancer).toSet()) {
          var at = 0.0;
          for (final move in combo.moves.where((m) => m.dancer == dancer)) {
            expect(move.at, at, reason: '${combo.name} $dancer');
            at += move.beats;
          }
          expect(at, combo.callBeats, reason: '${combo.name} $dancer');
        }
      }
    });

    test('The Girls both dance theirs', () {
      final combo = _registry().byId('pool-garden').hardestCombo!;
      expect(combo.moves.map((m) => m.dancer).toSet(), {'swing-a', 'swing-b'});
    });

    test('the BlinBlin dancer uses only clips every dancer shares', () {
      final combo = _registry().byId('cool-crowd').hardestCombo!;
      for (final move in combo.moves) {
        expect(
          () => grammar.requireClips('gatekeeper', [move.clip]),
          returnsNormally,
        );
        expect(move.clip, isNot(anyOf('spin_flare', 'flare')));
      }
    });

    test('each asks more than a level does, within what can be hit', () {
      final registry = _registry();
      for (final level in registry.levels) {
        final combo = level.hardestCombo!;
        expect(combo.chart.offsets.length, greaterThan(8), reason: level.id);
        final score =
            jsonDecode(
                  File(
                    'assets/music/scores/${level.music.score}.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        // The fastest tier, wherever the ladder puts it.
        final top = (score['tiers'] as List)
            .map((tier) => ((tier as Map)['bpm'] as num).toDouble())
            .reduce(math.max);
        final offsets = combo.chart.offsets;
        for (var i = 1; i < offsets.length; i++) {
          final gapMs = (offsets[i] - offsets[i - 1]) * 60000 / top;
          expect(
            gapMs,
            greaterThanOrEqualTo(RhythmJudge.goodWindowMs),
            reason: '${level.id} note $i',
          );
        }
      }
    });

    test('each final move is the one its last limb can do', () {
      final registry = _registry();
      for (final combo in registry.levels.map((l) => l.hardestCombo!)) {
        final foot =
            combo.chart.limbs.last == Limb.leftFoot ||
            combo.chart.limbs.last == Limb.rightFoot;
        expect(
          combo.lastNoteMove,
          foot ? GestureKind.stomp : GestureKind.circle,
          reason: combo.name,
        );
      }
    });
  });

  group('the loader refuses', () {
    test('a level with no combo', () {
      final json = _json('garden')..remove('hardestCombo');
      expect(() => LevelDefinition.fromJson(json), _refused('hardestCombo'));
    });

    test('a misspelt field', () {
      expect(
        () => LevelDefinition.fromJson(_gardenWith((c) => c['nmae'] = 'x')),
        _refused('nmae'),
      );
    });

    test('an unknown status', () {
      expect(
        () => LevelDefinition.fromJson(_gardenWith((c) => c['status'] = 'maybe')),
        _refused('status'),
      );
    });

    test('a move that runs past the call', () {
      expect(
        () => LevelDefinition.fromJson(
          _gardenWith((c) => (c['moves'] as List).last['beats'] = 3),
        ),
        _refused('runs past the call'),
      );
    });

    test('two moves at once for one dancer', () {
      expect(
        () => LevelDefinition.fromJson(
          _gardenWith((c) => (c['moves'] as List)[1]['at'] = 1),
        ),
        _refused('free'),
      );
    });

    test('a pair move that names nobody, or a stranger', () {
      final unnamed = _json('pool-garden');
      ((unnamed['hardestCombo'] as Map)['moves'] as List).first.remove('dancer');
      expect(() => LevelDefinition.fromJson(unnamed), _refused('name its dancer'));
      final stranger = _json('pool-garden');
      ((stranger['hardestCombo'] as Map)['moves'] as List).first['dancer'] = 'x';
      expect(() => LevelDefinition.fromJson(stranger), _refused('no such dancer'));
    });

    test('a pair with one dancer sitting it out', () {
      final json = _json('pool-garden');
      final combo = json['hardestCombo'] as Map;
      combo['moves'] = [
        for (final move in combo['moves'] as List)
          if (move['dancer'] == 'swing-a') move,
      ];
      expect(() => LevelDefinition.fromJson(json), _refused('swing-b has no moves'));
    });

    test('notes out of order, or past the call', () {
      expect(
        () => LevelDefinition.fromJson(
          _gardenWith((c) => (c['notes'] as List)[1]['at'] = 0),
        ),
        _refused('notes'),
      );
      expect(
        () => LevelDefinition.fromJson(
          _gardenWith((c) => (c['notes'] as List).last['at'] = 8),
        ),
        _refused('notes'),
      );
    });

    test('a longer move anywhere but the last note', () {
      expect(
        () => LevelDefinition.fromJson(
          _gardenWith((c) => (c['notes'] as List).first['move'] = 'circle'),
        ),
        _refused('last note'),
      );
    });

    String indexWith(Map<String, Object?> entry) {
      final index =
          jsonDecode(File('levels/index.json').readAsStringSync())
              as Map<String, Object?>;
      index['upcomingOpponents'] = [entry];
      return jsonEncode(index);
    }

    test('an upcoming opponent with neither a combo nor a placeholder', () {
      expect(
        () => LevelRegistry.parse(
          indexWith({'id': 'x', 'name': 'X', 'level': 'y'}),
          _file,
        ),
        _refused('placeholder'),
      );
    });

    test('an upcoming opponent claiming to be both', () {
      final combo = _json('garden')['hardestCombo'];
      expect(
        () => LevelRegistry.parse(
          indexWith({
            'id': 'x',
            'name': 'X',
            'level': 'y',
            'placeholder': true,
            'hardestCombo': combo,
          }),
          _file,
        ),
        _refused('placeholder'),
      );
    });
  });
}
