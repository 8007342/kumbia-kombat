import 'dart:js_interop';

@JS('window.localStorage')
external _Storage? get _storage;

extension type _Storage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

const _key = 'kumbia.syncOffsetMs';
int? _memory;

int? loadSyncOffsetMs() {
  try {
    final raw = _storage?.getItem(_key);
    if (raw != null) return int.tryParse(raw);
  } catch (_) {
    // Storage can be refused, as in a private window.
  }
  return _memory;
}

void saveSyncOffsetMs(int? offsetMs) {
  _memory = offsetMs;
  try {
    if (offsetMs == null) {
      _storage?.removeItem(_key);
    } else {
      _storage?.setItem(_key, '$offsetMs');
    }
  } catch (_) {
    // Kept for this run only.
  }
}
