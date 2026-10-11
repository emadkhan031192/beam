import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/beam_icons.dart';
import '../../core/channels.dart';
import '../../core/models.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import 'torch_controller.dart';

/// The main Torch tab: wordmark, battery pill, status, stage, brightness,
/// and mode buttons.
class TorchScreen extends ConsumerStatefulWidget {
  const TorchScreen({super.key, required this.onGoToStrobe});

  /// Called when the user taps the Strobe/SOS mode buttons.
  final void Function(TorchMode mode) onGoToStrobe;

  @override
  ConsumerState<TorchScreen> createState() => _TorchScreenState();
}

class _TorchScreenState extends ConsumerState<TorchScreen> {
  StreamSubscription<int>? _batterySub;
  Timer? _heatTimer;
  DateTime? _maxOnSince;
  bool _heatWarned = false;
  bool _lowBatteryHandled = false;
  int _lastBattery = 100;

  @override
  void initState() {
    super.initState();
    _batterySub = TorchApi.battery.listen(_onBattery);
    _heatTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkHeat());
  }

  void _onBattery(int percent) {
    _lastBattery = percent;
    final settings = ref.read(settingsProvider);
    final torch = ref.read(torchControllerProvider);
    if (settings.lowBatteryWarning &&
        percent <= 10 &&
        torch.on &&
        torch.level > 2 &&
        !_lowBatteryHandled) {
      _lowBatteryHandled = true;
      ref.read(torchControllerProvider.notifier).setLevel(2);
      ref
          .read(torchControllerProvider.notifier)
          .showNotice('Battery at 10% — dimmed to step 2');
    }
    if (percent > 15) _lowBatteryHandled = false;
    if (mounted) setState(() {});
  }

  void _checkHeat() {
    final torch = ref.read(torchControllerProvider);
    final hot = torch.on && torch.mode == TorchMode.steady && torch.level == 5;
    if (hot) {
      _maxOnSince ??= DateTime.now();
      if (!_heatWarned &&
          DateTime.now().difference(_maxOnSince!) >=
              const Duration(minutes: 10)) {
        _heatWarned = true;
        ref
            .read(torchControllerProvider.notifier)
            .showNotice('The flash can get hot. Give it a rest.',
                duration: const Duration(seconds: 8));
      }
    } else {
      _maxOnSince = null;
      _heatWarned = false;
    }
  }

  @override
  void dispose() {
    _batterySub?.cancel();
    _heatTimer?.cancel();
    super.dispose();
  }

  Future<void> _onPowerTap() async {
    if (ref.read(settingsProvider).hapticOnPower) {
      HapticFeedback.lightImpact();
    }
    await ref.read(torchControllerProvider.notifier).toggle();
  }

  @override
  Widget build(BuildContext context) {
    final torch = ref.watch(torchControllerProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(battery: _lastBattery, hasBattery: _lastBattery > 0),
            const SizedBox(height: 18),
            _StatusLine(state: torch),
            if (torch.notice != null) ...[
              const SizedBox(height: 8),
              _Notice(text: torch.notice!),
            ],
            const SizedBox(height: 8),
            _Stage(
              on: torch.on,
              level: torch.level,
              brightnessSupported: torch.brightnessSupported,
              onPowerTap: _onPowerTap,
            ),
            const SizedBox(height: 20),
            _BrightnessControl(
              level: torch.level,
              supported: torch.brightnessSupported,
              enabled: true,
              onChanged: (l) =>
                  ref.read(torchControllerProvider.notifier).setLevel(l),
            ),
            const SizedBox(height: 20),
            _ModeButtons(
              onTorch: () async {
                final c = ref.read(torchControllerProvider.notifier);
                if (torch.on && torch.mode != TorchMode.steady) {
                  await c.stopAll();
                }
                if (!ref.read(torchControllerProvider).on) {
                  await _onPowerTap();
                }
              },
              onStrobe: () => widget.onGoToStrobe(TorchMode.strobe),
              onSos: () => widget.onGoToStrobe(TorchMode.sos),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.battery, required this.hasBattery});

  final int battery;
  final bool hasBattery;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Beam', style: BeamType.wordmark),
        const SizedBox(width: 6),
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: BeamColors.amber,
            shape: BoxShape.circle,
          ),
        ),
        const Spacer(),
        Semantics(
          label: 'Battery ${hasBattery ? '$battery percent' : 'unknown'}',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: BeamColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: BeamColors.line),
            ),
            child: Text(
              hasBattery ? '$battery%' : '--%',
              style: BeamType.mono.copyWith(fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state});

  final TorchUiState state;

  @override
  Widget build(BuildContext context) {
    final String title;
    final String? sub;
    if (!state.on) {
      title = 'Tap to light';
      sub = null;
    } else {
      switch (state.mode) {
        case TorchMode.steady:
          title = 'Torch on';
          sub = 'LED · steady';
        case TorchMode.strobe:
          title = 'Strobe on';
          sub = 'LED · flashing';
        case TorchMode.sos:
          title = 'SOS on';
          sub = 'LED · signalling';
      }
    }
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'BricolageGrotesque',
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: BeamColors.text,
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: BeamType.mono.copyWith(
              fontSize: 12,
              color: BeamColors.secondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: BeamColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BeamColors.lineStrong),
      ),
      child: Text(text,
          textAlign: TextAlign.center, style: BeamType.body.copyWith(fontSize: 13)),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.on,
    required this.level,
    required this.brightnessSupported,
    required this.onPowerTap,
  });

  final bool on;
  final int level;
  final bool brightnessSupported;
  final VoidCallback onPowerTap;

  @override
  Widget build(BuildContext context) {
    // Glow grows with the level and fades in/out over ~250ms.
    final glowSize = on ? 190.0 + level * 26.0 : 120.0;
    return SizedBox(
      height: 340,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: glowSize,
            height: glowSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  BeamColors.amber.withValues(alpha: on ? 0.28 : 0.0),
                  BeamColors.amber.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
          CustomPaint(
            size: const Size(280, 280),
            painter: _TickRingPainter(
              on: on,
              litTicks: on ? (level / 5 * 60).round() : 0,
            ),
          ),
          PressScale(
            semanticLabel: on ? 'Turn the flashlight off' : 'Turn the flashlight on',
            onTap: onPowerTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 156,
              height: 156,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? BeamColors.amber : BeamColors.surfaceAlt,
                border: Border.all(
                  color: on ? BeamColors.amberHot : BeamColors.lineStrong,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: BeamIcon(
                  BeamIconKind.power,
                  size: 56,
                  color: on ? BeamColors.onAmber : BeamColors.secondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 60 ticks; lights up in amber proportionally to the brightness level.
class _TickRingPainter extends CustomPainter {
  _TickRingPainter({required this.on, required this.litTicks});

  final bool on;
  final int litTicks;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;
    final lit = Paint()
      ..color = const Color(0xFFFFB547)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final dim = Paint()
      ..color = const Color(0xFF23252B)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final a = (i / 60) * 2 * math.pi - math.pi / 2;
      final inner = Offset(
        center.dx + (radius - 8) * math.cos(a),
        center.dy + (radius - 8) * math.sin(a),
      );
      final outer = Offset(
        center.dx + radius * math.cos(a),
        center.dy + radius * math.sin(a),
      );
      canvas.drawLine(inner, outer, (on && i < litTicks) ? lit : dim);
    }
  }

  @override
  bool shouldRepaint(covariant _TickRingPainter old) =>
      old.on != on || old.litTicks != litTicks;
}

class _BrightnessControl extends StatelessWidget {
  const _BrightnessControl({
    required this.level,
    required this.supported,
    required this.enabled,
    required this.onChanged,
  });

  final int level;
  final bool supported;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Brightness'),
        const SizedBox(height: 14),
        if (!supported)
          Text(
            "Brightness steps aren't supported on this phone",
            style: BeamType.body.copyWith(fontSize: 13),
          )
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(5, (i) {
              final step = i + 1;
              final active = step <= level;
              return PressScale(
                semanticLabel: 'Brightness step $step of 5',
                onTap: enabled ? () => onChanged(step) : null,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.bottomCenter,
                  padding: const EdgeInsets.only(bottom: 6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 26,
                    height: 10.0 + i * 8.0,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: active ? BeamColors.amber : BeamColors.lineStrong,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              brightnessLabel(level),
              style: BeamType.mono.copyWith(
                fontSize: 13,
                color: BeamColors.secondaryAlt,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ModeButtons extends StatelessWidget {
  const _ModeButtons({
    required this.onTorch,
    required this.onStrobe,
    required this.onSos,
  });

  final VoidCallback onTorch;
  final VoidCallback onStrobe;
  final VoidCallback onSos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Mode'),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ModeButton(
                label: 'Torch',
                icon: BeamIconKind.bolt,
                onTap: onTorch,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ModeButton(
                label: 'Strobe',
                icon: BeamIconKind.strobe,
                onTap: onStrobe,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ModeButton(
                label: 'SOS',
                icon: BeamIconKind.sos,
                onTap: onSos,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final BeamIconKind icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      semanticLabel: '$label mode',
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: BeamColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BeamColors.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BeamIcon(icon, size: 20, color: BeamColors.secondaryAlt),
            const SizedBox(width: 8),
            Text(label, style: BeamType.bodyStrong.copyWith(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
