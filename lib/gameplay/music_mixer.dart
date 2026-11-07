import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../music/game_audio_contract.dart';
import '../music/rendered_library.dart';
import '../music/rendered_music.dart';
import '../music/transport.dart';

/// `?mixer=1` shows the owner's mixer. Without the flag nothing is built at all.
bool get musicMixerRequested => Uri.base.queryParameters['mixer'] == '1';

/// The settings in the manifest's own shape, to paste into its `mix` and each
/// take's `gainDb`. Holds only what a person changes: never bpm or loop points.
String mixerJson(RenderedMix mix, Map<String, RenderedLevel> levels) =>
    const JsonEncoder.withIndent('  ').convert({
      'mix': mix.toJson(),
      'levels': {
        for (final level in levels.values)
          level.id: {
            'takes': {
              for (final take in level.takes.entries)
                take.key: {'gainDb': take.value.gainDb},
            },
          },
      },
    });

/// Gain only: sliders reach the buses and clip trims, never the clock.
class MusicMixerPanel extends StatefulWidget {
  const MusicMixerPanel({
    super.key,
    required this.audio,
    required this.library,
    required this.levelId,
    required this.transport,
    required this.mix,
    required this.onMix,
  });
  final RenderedAudio audio;
  final RenderedLibrary library;
  final String levelId;
  final MusicTransport? Function() transport;
  final RenderedMix mix;
  final ValueChanged<RenderedMix> onMix;

  @override
  State<MusicMixerPanel> createState() => _MusicMixerPanelState();
}

class _MusicMixerPanelState extends State<MusicMixerPanel> {
  Timer? _tick;
  bool _open = true;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
      debugPrint('kk-mix ${_probe()}');
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// One line for the readout and the browser console, which a timing check reads.
  String _probe() {
    final transport = widget.transport();
    final clip = transport?.currentClip;
    final decoded = widget.audio.decodedBytes / (1024 * 1024);
    final held = widget.audio.compressedBytes / (1024 * 1024);
    return 'level=${widget.levelId} '
        't=${widget.audio is GameAudio ? (widget.audio as GameAudio).nowSeconds.toStringAsFixed(4) : '-'} '
        'beat=${transport?.positionBeats.toStringAsFixed(4) ?? '-'} '
        'tier=${transport?.currentTier ?? '-'} '
        'bpm=${transport?.currentBpm.toStringAsFixed(3) ?? '-'} '
        'clip=${clip?.id ?? 'synth'} '
        'clipStart=${transport?.clipStartedAtSeconds.toStringAsFixed(4) ?? '-'} '
        'clipOrigin=${transport?.clipOriginBeat.toStringAsFixed(3) ?? '-'} '
        'decodedMB=${decoded.toStringAsFixed(1)} '
        'heldMB=${held.toStringAsFixed(1)} '
        'failed=${widget.library.failures.length}';
  }

  Widget _slider(String label, double db, ValueChanged<double> changed) => Row(
    children: [
      SizedBox(width: 76, child: Text(label, style: _small)),
      Expanded(
        child: Slider(
          value: db.clamp(-30.0, 12.0),
          min: -30,
          max: 12,
          divisions: 84,
          onChanged: changed,
        ),
      ),
      SizedBox(
        width: 48,
        child: Text('${db.toStringAsFixed(1)} dB', style: _small),
      ),
    ],
  );

  static const _small = TextStyle(color: Colors.white, fontSize: 11);

  @override
  Widget build(BuildContext context) {
    final mix = widget.mix;
    final level = widget.library.level(widget.levelId);
    return Material(
      color: const Color(0xDD101F29),
      child: SizedBox(
        width: 300,
        child: _open
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _slider(
                      'Master',
                      mix.masterDb,
                      (v) => widget.onMix(mix.copyWith(masterDb: v)),
                    ),
                    _slider(
                      'Music',
                      mix.musicDb,
                      (v) => widget.onMix(mix.copyWith(musicDb: v)),
                    ),
                    _slider(
                      'Accents',
                      mix.accentsDb,
                      (v) => widget.onMix(mix.copyWith(accentsDb: v)),
                    ),
                    _slider(
                      'Rewards',
                      mix.rewardsDb,
                      (v) => widget.onMix(mix.copyWith(rewardsDb: v)),
                    ),
                    if (level != null)
                      for (final take in level.takes.entries)
                        _slider(
                          '${take.key} ${take.value.bpm.round()}',
                          take.value.gainDb,
                          (v) => setState(() {
                            take.value.gainDb = v;
                            widget.audio.clipGainChanged(take.value);
                          }),
                        ),
                    SelectableText(_probe(), style: _small),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Clipboard.setData(
                            ClipboardData(
                              text: mixerJson(
                                mix,
                                widget.library.manifest.levels,
                              ),
                            ),
                          ),
                          child: const Text('Copy JSON'),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _open = false),
                          child: const Text('Hide'),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : TextButton(
                onPressed: () => setState(() => _open = true),
                child: const Text('Mixer'),
              ),
      ),
    );
  }
}
