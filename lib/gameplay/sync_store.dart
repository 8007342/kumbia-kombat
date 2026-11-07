import 'sync_store_stub.dart'
    if (dart.library.js_interop) 'sync_store_web.dart'
    as platform;

/// The calibration offset kept on this device, in milliseconds, or null. On
/// the web it lives in the browser's storage for this site; elsewhere, and in
/// a private window that refuses storage, only for this run.
int? loadSyncOffsetMs() => platform.loadSyncOffsetMs();

void saveSyncOffsetMs(int? offsetMs) => platform.saveSyncOffsetMs(offsetMs);
