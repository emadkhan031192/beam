import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/beam_icons.dart';
import '../../core/channels.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';

/// Settings tab: torch, safety, feel, and the footer.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Settings', style: BeamType.screenTitle(context)),
            const SizedBox(height: 20),
            const SectionLabel('Torch'),
            const SizedBox(height: 6),
            _SwitchRow(
              icon: BeamIconKind.bolt,
              title: 'Light on when Beam opens',
              subtitle: 'Ready the moment you launch it',
              value: settings.lightOnOpen,
              onChanged: notifier.setLightOnOpen,
            ),
            _ShakeRow(settings: settings),
            _StartBrightnessRow(
              value: settings.startBrightness,
              onChanged: notifier.setStartBrightness,
            ),
            _AutoOffRow(
              value: settings.autoOffMinutes,
              onChanged: (v) async {
                await notifier.setAutoOffMinutes(v);
                await TorchApi.setAutoOffMinutes(v);
              },
            ),
            const SizedBox(height: 20),
            const SectionLabel('Safety'),
            const SizedBox(height: 6),
            _SwitchRow(
              icon: BeamIconKind.bell,
              title: 'Low battery warning',
              subtitle: 'Dim the light and warn at 10%',
              value: settings.lowBatteryWarning,
              onChanged: notifier.setLowBatteryWarning,
            ),
            _SwitchRow(
              icon: BeamIconKind.warning,
              title: 'Strobe warning',
              subtitle: 'Show a notice before flashing starts',
              value: settings.strobeWarning,
              onChanged: notifier.setStrobeWarning,
            ),
            const SizedBox(height: 20),
            const SectionLabel('Feel'),
            const SizedBox(height: 6),
            _SwitchRow(
              icon: BeamIconKind.handTap,
              title: 'Haptic tap on power',
              subtitle: 'A short buzz when the light switches',
              value: settings.hapticOnPower,
              onChanged: notifier.setHapticOnPower,
            ),
            const SizedBox(height: 28),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final BeamIconKind icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: BeamColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BeamColors.line),
            ),
            child: Center(
                child:
                    BeamIcon(icon, size: 22, color: BeamColors.secondaryAlt)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: BeamType.bodyStrong.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: BeamType.body.copyWith(fontSize: 13)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ShakeRow extends ConsumerWidget {
  const _ShakeRow({required this.settings});

  final BeamSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: BeamColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BeamColors.line),
                ),
                child: const Center(
                    child: BeamIcon(BeamIconKind.shake,
                        size: 22, color: BeamColors.secondaryAlt)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Shake to toggle',
                        style: BeamType.bodyStrong.copyWith(fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('Two quick shakes, even from the lock screen',
                        style: BeamType.body.copyWith(fontSize: 13)),
                  ],
                ),
              ),
              Switch(
                value: settings.shakeEnabled,
                onChanged: (v) async {
                  if (v) {
                    // POST_NOTIFICATIONS is requested only when enabling.
                    await TorchApi.requestNotificationPermission();
                    await TorchApi.setShakeEnabled(true);
                  } else {
                    await TorchApi.setShakeEnabled(false);
                  }
                  await ref
                      .read(settingsProvider.notifier)
                      .setShakeEnabled(v);
                },
              ),
            ],
          ),
        ),
        if (settings.shakeEnabled)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BeamColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BeamColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Some phones stop sensors when the screen is off, so shake may not work from a locked screen on every phone.',
                  style: BeamType.body.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 10),
                PressScale(
                  semanticLabel: 'Open battery optimisation settings',
                  onTap: TorchApi.openBatterySettings,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BeamIcon(BeamIconKind.external,
                          size: 16, color: BeamColors.amber),
                      const SizedBox(width: 8),
                      Text(
                        'Battery optimisation',
                        style: BeamType.bodyStrong.copyWith(
                            fontSize: 14, color: BeamColors.amber),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StartBrightnessRow extends StatelessWidget {
  const _StartBrightnessRow({required this.value, required this.onChanged});

  final int value; // app step 1..5
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = [('Low', 1), ('Medium', 3), ('High', 4), ('Max', 5)];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: BeamColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BeamColors.line),
                ),
                child: const Center(
                    child: BeamIcon(BeamIconKind.sun,
                        size: 22, color: BeamColors.secondaryAlt)),
              ),
              const SizedBox(width: 14),
              Text('Start brightness',
                  style: BeamType.bodyStrong.copyWith(fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (label, step) in options) ...[
                Expanded(
                  child: _ChoiceChip(
                    label: label,
                    selected: value == step,
                    onTap: () => onChanged(step),
                  ),
                ),
                if (label != 'Max') const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AutoOffRow extends StatelessWidget {
  const _AutoOffRow({required this.value, required this.onChanged});

  final int value; // minutes, 0 = never
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = [0, 5, 15, 30, 60];
    String label(int m) => m == 0 ? 'Never' : '$m min';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: BeamColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BeamColors.line),
                ),
                child: const Center(
                    child: BeamIcon(BeamIconKind.timer,
                        size: 22, color: BeamColors.secondaryAlt)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Auto-off timer',
                        style: BeamType.bodyStrong.copyWith(fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('A quiet notification lets you turn it off',
                        style: BeamType.body.copyWith(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in options)
                _ChoiceChip(
                  label: label(m),
                  selected: value == m,
                  mono: true,
                  onTap: () => onChanged(m),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.mono = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? BeamColors.amber : BeamColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? BeamColors.amber : BeamColors.line),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: (mono ? BeamType.mono : BeamType.bodyStrong).copyWith(
            fontSize: 13,
            color: selected ? BeamColors.onAmber : BeamColors.secondaryAlt,
            fontWeight: mono ? FontWeight.w500 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: TorchApi.getApkSizeMb(),
      builder: (context, snap) {
        final size =
            snap.hasData ? '${snap.data!.toStringAsFixed(1)} MB' : '—';
        return Center(
          child: Text(
            'Beam 1.0 · $size · no ads, no account',
            style: BeamType.mono.copyWith(
              fontSize: 11,
              color: BeamColors.secondary,
            ),
          ),
        );
      },
    );
  }
}
