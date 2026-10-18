import 'game_audio_contract.dart';
import 'web_audio_backend.dart';

GameAudio createPlatformGameAudio() => WebAudioMusicBackend();
