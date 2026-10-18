import 'game_audio_contract.dart';
import 'score.dart';

GameAudio createPlatformGameAudio() => _UnsupportedGameAudio();

class _UnsupportedGameAudio implements GameAudio {
  @override
  String leadShape = 'triangle';
  @override
  double get nowSeconds => 0;
  @override
  bool get ready => false;
  @override
  Future<void> activate() async {
    throw UnsupportedError(
      'Live synth audio is available in the web app. Native audio is not implemented.',
    );
  }

  @override
  Future<void> dispose() async {}
  @override
  void silence() {}
  @override
  void schedule(ScoreNote note, double atSeconds, double durationSeconds) {
    throw UnsupportedError(
      'Cannot schedule music without a supported audio backend.',
    );
  }
}
