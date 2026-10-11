import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/beam_icons.dart';
import '../../core/channels.dart';
import '../../core/models.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../torch/torch_controller.dart';

/// Which pattern the strobe tab is showing.
final strobeTabProvider = StateProvider<TorchMode>((ref) => TorchMode.strobe);

/// Selected strobe rate in Hz (1–20).
final strobeHzProvider = StateProvider<int>((ref) => 6);

const String strobeWarningText =
    'Rapid flashing can trigger seizures in people with photosensitive epilepsy.';

/// Strobe / SOS tab: rate controls, presets, SOS card, and the safety line
/// that is always visible at the bottom.
class StrobeScreen extends ConsumerStatefulWidget {
  const StrobeScreen({super.key});

  @override
  ConsumerState<StrobeScreen> createState() => _StrobeScreenState();
}

class _StrobeScreenState extends ConsumerState<StrobeScreen> {
  late final AppLifecycleListener _lifecycle;
  Timer? _previewTimer;
  bool _previewPhase = false;

  @override
  void initState() {
    super.initState();
    // Stop the strobe immediately when the app goes to the background.
    _lifecycle = AppLifecycleListener(
      onHide: _stopIfRunning,
      onPause: _stopIfRunning,
    );
    _restartPreviewTimer(ref.read(strobeHzProvider));
  }

  void _restartPreviewTimer(int hz) {
    _previewTimer?.cancel();
    final halfPeriod = (1000 / (hz * 2)).round().clamp(25, 1000);
    _previewTimer = Timer.periodic(
      Duration(milliseconds: halfPeriod),
      (_) => setState(() => _previewPhase = !_previewPhase),
    );
  }

  void _stopIfRunning() {
    final torch = ref.read(torchControllerProvider);
    if (torch.on &&
        (torch.mode == TorchMode.strobe || torch.mode == TorchMode.sos)) {
      ref.read(torchControllerProvider.notifier).stopAll();
    }
  }

  Future<bool?> _showWarningDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: BeamColors.surfaceAlt,
        title: const Text('Before you flash',
            style: TextStyle(
                fontFamily: 'BricolageGrotesque',
                fontWeight: FontWeight.w700,
                color: BeamColors.text)),
        content: Text(strobeWarningText,
            style: BeamType.body.copyWith(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: BeamColors.secondary)),
          ),
          PressScale(
            semanticLabel: 'I understand, start flashing',
            onTap: () => Navigator.of(context).pop(true),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: BeamColors.amber,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('I understand',
                  style: TextStyle(
                      fontFamily: 'BricolageGrotesque',
                      fontWeight: FontWeight.w700,
                      color: BeamColors.onAmber)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePattern() async {
    final torch = ref.read(torchControllerProvider);
    final controller = ref.read(torchControllerProvider.notifier);
    if (torch.on &&
        (torch.mode == TorchMode.strobe || torch.mode == TorchMode.sos)) {
      await controller.stopAll();
      return;
    }
    final settings = ref.read(settingsProvider);
    if (settings.strobeWarning && !settings.strobeSeenWarning) {
      final ok = await _showWarningDialog();
      if (ok != true || !mounted) return;
      await ref.read(settingsProvider.notifier).markStrobeWarningSeen();
    }
    final tab = ref.read(strobeTabProvider);
    if (tab == TorchMode.strobe) {
      await TorchApi.startStrobe(ref.read(strobeHzProvider));
    } else {
      await TorchApi.startSos();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _previewTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final torch = ref.watch(torchControllerProvider);
    final tab = ref.watch(strobeTabProvider);
    final hz = ref.watch(strobeHzProvider);
    final running = torch.on &&
        (torch.mode == TorchMode.strobe || torch.mode == TorchMode.sos);

    return PopScope(
      // Stop the strobe immediately on back.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _stopIfRunning();
      },
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Strobe & SOS', style: BeamType.screenTitle(context)),
                    const SizedBox(height: 18),
                    _SegmentedSwitch(
                      tab: tab,
                      onChanged: (m) =>
                          ref.read(strobeTabProvider.notifier).state = m,
                    ),
                    const SizedBox(height: 20),
                    if (tab == TorchMode.strobe) ...[
                      _PulsePreview(phase: _previewPhase),
                      const SizedBox(height: 16),
                      _SpeedReadout(hz: hz),
                      const SizedBox(height: 8),
                      Slider(
                        value: hz.toDouble(),
                        min: 1,
                        max: 20,
                        divisions: 19,
                        label: '$hz Hz',
                        onChanged: (v) {
                          final nv = v.round();
                          ref.read(strobeHzProvider.notifier).state = nv;
                          _restartPreviewTimer(nv);
                          if (torch.on && torch.mode == TorchMode.strobe) {
                            TorchApi.startStrobe(nv);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      _Presets(
                        hz: hz,
                        onPick: (v) {
                          ref.read(strobeHzProvider.notifier).state = v;
                          _restartPreviewTimer(v);
                          if (torch.on && torch.mode == TorchMode.strobe) {
                            TorchApi.startStrobe(v);
                          }
                        },
                      ),
                    ] else ...[
                      const _SosCard(),
                    ],
                    const SizedBox(height: 20),
                    _StartButton(
                      running: running,
                      tab: tab,
                      onTap: _togglePattern,
                    ),
                  ],
                ),
              ),
            ),
            // Safety line: always visible, never removed.
            const _WarningLine(),
          ],
        ),
      ),
    );
  }
}

class _SegmentedSwitch extends StatelessWidget {
  const _SegmentedSwitch({required this.tab, required this.onChanged});

  final TorchMode tab;
  final ValueChanged<TorchMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: BeamColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BeamColors.line),
      ),
      child: Row(
        children: [
          Expanded(child: _segment(TorchMode.strobe, 'Strobe')),
          Expanded(child: _segment(TorchMode.sos, 'SOS')),
        ],
      ),
    );
  }

  Widget _segment(TorchMode mode, String label) {
    final selected = tab == mode;
    return PressScale(
      semanticLabel: 'Show $label controls',
      onTap: () => onChanged(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: selected ? BeamColors.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'BricolageGrotesque',
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: selected ? BeamColors.onAmber : BeamColors.secondary,
          ),
        ),
      ),
    );
  }
}

/// Row of bars that pulse at the selected rate (preview only).
class _PulsePreview extends StatelessWidget {
  const _PulsePreview({required this.phase});

  final bool phase;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: BeamColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BeamColors.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(14, (i) {
          final lit = (i % 2 == 0) == phase;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 60),
            width: 8,
            height: 20 + (i % 4) * 10.0,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: lit ? BeamColors.amber : BeamColors.lineStrong,
            ),
          );
        }),
      ),
    );
  }
}

class _SpeedReadout extends StatelessWidget {
  const _SpeedReadout({required this.hz});

  final int hz;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$hz',
          style: BeamType.mono.copyWith(
            fontSize: 56,
            fontWeight: FontWeight.w500,
            color: BeamColors.text,
          ),
        ),
        Text(
          'flashes / sec',
          style: BeamType.mono.copyWith(
            fontSize: 13,
            color: BeamColors.secondary,
          ),
        ),
      ],
    );
  }
}

class _Presets extends StatelessWidget {
  const _Presets({required this.hz, required this.onPick});

  final int hz;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    const presets = [
      ('Slow', 2),
      ('Party', 6),
      ('Alert', 10),
      ('Max', 20),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (label, value) in presets)
          PressScale(
            semanticLabel: 'Preset $label, $value hertz',
            onTap: () => onPick(value),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: hz == value ? BeamColors.amber : BeamColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hz == value ? BeamColors.amber : BeamColors.line,
                ),
              ),
              child: Text(
                '$label $value',
                style: BeamType.mono.copyWith(
                  fontSize: 13,
                  color:
                      hz == value ? BeamColors.onAmber : BeamColors.secondaryAlt,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SosCard extends StatelessWidget {
  const _SosCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BeamColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BeamColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('SOS pattern'),
          const SizedBox(height: 14),
          const Text(
            '··· −−− ···',
            style: TextStyle(
              fontFamily: 'MartianMono',
              fontWeight: FontWeight.w500,
              fontSize: 28,
              letterSpacing: 4,
              color: BeamColors.amber,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'International distress signal. Repeats until you stop it.',
            style: BeamType.body.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.running,
    required this.tab,
    required this.onTap,
  });

  final bool running;
  final TorchMode tab;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = running
        ? 'Stop'
        : (tab == TorchMode.strobe ? 'Start strobe' : 'Start SOS');
    return PressScale(
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: BeamColors.amber,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'BricolageGrotesque',
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: BeamColors.onAmber,
          ),
        ),
      ),
    );
  }
}

class _WarningLine extends StatelessWidget {
  const _WarningLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: BeamColors.line, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BeamIcon(BeamIconKind.warning,
              size: 18, color: BeamColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              strobeWarningText,
              style: BeamType.body.copyWith(fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
