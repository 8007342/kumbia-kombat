import 'dart:async';

import 'game_audio_contract.dart';
import 'rendered_music.dart';

/// Gets a level's music ready without a run ever depending on it. Compressed
/// files come first, needing no permission; decoding follows the first press.
/// Every failure lands in [failures], and the transport plays the synth instead.
class RenderedLibrary {
  RenderedLibrary(this.audio, this.manifest);
  final RenderedAudio audio;
  final RenderedManifest manifest;
  final failures = <String, Object>{};

  RenderedLevel? level(String id) => manifest.levels[id];

  Future<void> _guard(RenderedClip clip, Future<void> Function() work) async {
    if (failures.containsKey(clip.id)) return;
    try {
      await work();
    } catch (error) {
      failures[clip.id] = error;
    }
  }

  /// Compressed bytes only, cheap to hold. Safe before the player has pressed.
  Future<void> fetchLevel(String id) async {
    final music = level(id);
    if (music == null) return;
    for (final clip in music.clips) {
      await _guard(clip, () => audio.fetchClip(clip));
    }
  }

  Future<void> _decode(RenderedClip clip) =>
      _guard(clip, () => audio.decodeClip(clip));

  /// What a run needs at its first beat. Bounded: past [patience] the run starts
  /// on the synth, and the take joins at a phrase boundary once it arrives.
  Future<void> decodeStart(
    String id, {
    int tier = 0,
    Duration patience = const Duration(seconds: 6),
  }) async {
    final music = level(id);
    if (music == null) return;
    await _decode(
      music.takeForTier(tier),
    ).timeout(patience, onTimeout: () {});
  }

  /// One at a time, so a phone's memory and CPU see one decode at once.
  Future<void> decodeRest(String id) async {
    final music = level(id);
    if (music == null) return;
    for (final take in music.takes.values) {
      await _decode(take);
    }
    for (final join in music.transitions) {
      await _decode(join.clip);
    }
  }

  /// What the moment of contact and the next room need. This is the only part
  /// of the next level decoded early, which keeps two rooms' takes out of memory.
  Future<void> decodeExit(String id, {String? nextId}) async {
    final music = level(id);
    if (music == null) {
      if (nextId != null) await decodeStart(nextId);
      return;
    }
    final success = music.success;
    if (success != null) await _decode(success);
    if (nextId == null) return;
    final bridge = music.bridge;
    if (bridge != null && music.bridgeTo == nextId) await _decode(bridge);
    await decodeStart(nextId);
  }

  /// A room that has been left. [keep] survives even if the levels share a clip.
  void releaseLevel(String id, {String? keep}) {
    final music = level(id);
    if (music == null) return;
    final kept = {...?level(keep ?? '')?.clips.map((clip) => clip.id)};
    for (final clip in music.clips) {
      if (!kept.contains(clip.id)) audio.releaseClip(clip);
    }
  }
}
