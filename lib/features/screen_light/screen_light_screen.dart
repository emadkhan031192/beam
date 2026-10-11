import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/beam_icons.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';

/// The six screen-light colors.
const List<Color> screenLightColors = [
  Color(0xFFFFE9C2), // warm white
  Color(0xFFEAF3FF), // cool white
  Color(0xFFFFB547), // amber
  Color(0xFFD8321E), // night red
  Color(0xFF5BE38C), // green
  Color(0xFF5B8CFF), // blue
];

const List<String> screenLightColorNames = [
  'Warm white',
  'Cool white',
  'Amber',
  'Night red',
  'Green',
  'Blue',
];

/// Screen light tab: the whole screen becomes the light.
/// A tap hides/shows the near-black control sheet.
class ScreenLightScreen extends ConsumerStatefulWidget {
  const ScreenLightScreen({super.key, this.noFlash = false});

  /// When the phone has no flash, an explanation card is shown on top.
  final bool noFlash;

  @override
  ConsumerState<ScreenLightScreen> createState() => _ScreenLightScreenState();
}

class _ScreenLightScreenState extends ConsumerState<ScreenLightScreen> {
  bool _sheetVisible = true;
  double? _previousBrightness;

  @override
  void initState() {
    super.initState();
    _enter();
  }

  Future<void> _enter() async {
    final settings = ref.read(settingsProvider);
    try {
      _previousBrightness = await ScreenBrightness().application;
      await ScreenBrightness()
          .setApplicationScreenBrightness(settings.screenLightBrightness);
    } catch (_) {
      // Brightness control unavailable; the color still works as a light.
    }
    if (settings.keepAwake) {
      try {
        await WakelockPlus.enable();
      } catch (_) {}
    }
  }

  Future<void> _exit() async {
    final previous = _previousBrightness;
    if (previous != null) {
      try {
        await ScreenBrightness().setApplicationScreenBrightness(previous);
      } catch (_) {}
    }
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }

  @override
  void dispose() {
    _exit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final color = screenLightColors[settings.screenLightColor];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _sheetVisible = !_sheetVisible),
      child: Container(
        color: color,
        child: SafeArea(
          child: Stack(
            children: [
              if (widget.noFlash)
                Positioned(
                  top: 12,
                  left: 20,
                  right: 20,
                  child: _NoFlashCard(color: color),
                ),
              if (_sheetVisible)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    // Don't let taps on the sheet toggle it away.
                    onTap: () {},
                    child: _ControlSheet(
                      brightness: settings.screenLightBrightness,
                      onBrightness: (v) async {
                        await ref
                            .read(settingsProvider.notifier)
                            .setScreenLightBrightness(v);
                        try {
                          await ScreenBrightness()
                              .setApplicationScreenBrightness(v);
                        } catch (_) {}
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoFlashCard extends StatelessWidget {
  const _NoFlashCard({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = color.computeLuminance() > 0.5;
    final fg = dark ? BeamColors.onAmber : BeamColors.text;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BeamColors.sheet.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BeamIcon(BeamIconKind.info, size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This device has no camera flash, so only the screen light is available.',
              style: TextStyle(
                fontFamily: 'BricolageGrotesque',
                fontSize: 14,
                height: 1.4,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlSheet extends ConsumerWidget {
  const _ControlSheet({required this.brightness, required this.onBrightness});

  final double brightness;
  final ValueChanged<double> onBrightness;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Container(
      decoration: const BoxDecoration(
        color: BeamColors.sheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: BeamColors.line, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: BeamColors.lineStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionLabel('Color'),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(screenLightColors.length, (i) {
              final selected = settings.screenLightColor == i;
              return PressScale(
                semanticLabel: '${screenLightColorNames[i]} light',
                onTap: () => ref
                    .read(settingsProvider.notifier)
                    .setScreenLightColor(i),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: screenLightColors[i],
                    border: Border.all(
                      color: selected
                          ? BeamColors.amber
                          : BeamColors.lineStrong,
                      width: selected ? 3 : 1.5,
                    ),
                  ),
                  child: selected
                      ? Icon(Icons.check,
                          size: 20,
                          color: screenLightColors[i].computeLuminance() > 0.5
                              ? BeamColors.onAmber
                              : Colors.white)
                      : null,
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          const SectionLabel('Brightness'),
          Slider(
            value: brightness,
            min: 0.05,
            max: 1.0,
            onChanged: onBrightness,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Keep the screen awake',
                        style: BeamType.bodyStrong.copyWith(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      'The light stays on while this tab is open',
                      style: BeamType.body.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: settings.keepAwake,
                onChanged: (v) async {
                  await ref
                      .read(settingsProvider.notifier)
                      .setKeepAwake(v);
                  try {
                    if (v) {
                      await WakelockPlus.enable();
                    } else {
                      await WakelockPlus.disable();
                    }
                  } catch (_) {}
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
