import 'dart:convert';

import 'browser.dart';

/// One note per console item, keyed by the item's stable reference, kept in the
/// browser's local storage. "Copy all" gives them back as plain text with their
/// references and sources, for pasting into a message.
class ConsoleNotes {
  ConsoleNotes(this._browser) {
    final raw = _browser.read(storageKey);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return;
      for (final entry in data.entries) {
        final value = entry.value;
        if (value is Map && value['note'] is String) {
          _notes['${entry.key}'] = (
            note: value['note'] as String,
            source: '${value['source'] ?? ''}',
          );
        }
      }
    } catch (_) {
      // A damaged store starts empty rather than hiding the console.
    }
  }

  static const storageKey = 'kumbia-kombat.console.notes.v1';
  final ConsoleBrowser _browser;
  final _notes = <String, ({String note, String source})>{};

  String noteFor(String ref) => _notes[ref]?.note ?? '';
  bool has(String ref) => _notes.containsKey(ref);
  int get count => _notes.length;

  void set(String ref, String note, {required String source}) {
    if (note.trim().isEmpty) {
      _notes.remove(ref);
    } else {
      _notes[ref] = (note: note, source: source);
    }
    _browser.write(
      storageKey,
      jsonEncode({
        for (final e in _notes.entries)
          e.key: {'note': e.value.note, 'source': e.value.source},
      }),
    );
  }

  void clear() {
    _notes.clear();
    _browser.write(storageKey, '{}');
  }

  /// Every note, in reference order, ready to paste.
  String asText({String? heading}) {
    final refs = _notes.keys.toList()..sort();
    final out = StringBuffer(heading ?? 'Kumbia Kombat console notes');
    out.writeln();
    for (final ref in refs) {
      final entry = _notes[ref]!;
      out.writeln();
      out.writeln('## $ref');
      if (entry.source.isNotEmpty) out.writeln('(${entry.source})');
      out.writeln(entry.note.trim());
    }
    return out.toString();
  }
}
