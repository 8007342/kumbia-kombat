import 'game_audio_contract.dart';
import 'game_audio_stub.dart'
    if (dart.library.js_interop) 'game_audio_web.dart'
    as platform;
export 'game_audio_contract.dart';

/// Safe to import in Flutter widget tests and native builds. Native synthesis is
/// not implemented yet: that backend reports unsupported activation explicitly.
GameAudio createGameAudio() => platform.createPlatformGameAudio();
