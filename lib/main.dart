import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/beam_icons.dart';
import 'core/channels.dart';
import 'core/settings.dart';
import 'core/theme.dart';
import 'features/screen_light/screen_light_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/strobe/strobe_screen.dart';
import 'features/torch/torch_screen.dart';

/// Cold start: initialise only the torch channel before the first frame,
/// read the single `lightOnOpen` flag, and light the torch BEFORE runApp
/// when asked. Everything else (settings UI state, battery stream, auto-off
/// sync, shake service) is deferred until after the first frame.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TorchApi.init();

  final prefs = await SharedPreferences.getInstance();
  final lightOnOpen = prefs.getBool(BeamKeys.lightOnOpen) ?? false;
  // The native side already lit the torch for the shortcut fast-path;
  // this just consumes the flag so we don't light it twice.
  final fromShortcut = await TorchApi.consumeShortcutLightOn();
  if (lightOnOpen && !fromShortcut) {
    final start = (prefs.getInt(BeamKeys.startBrightness) ?? 5).clamp(1, 5);
    await TorchApi.turnOn(start);
  }

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const BeamApp(),
    ),
  );
}

/// Whether the device has a camera flash. Null until checked after first frame.
final torchSupportedProvider = StateProvider<bool?>((ref) => null);

/// Bottom-nav tab index.
final tabIndexProvider = StateProvider<int>((ref) => 0);

class BeamApp extends ConsumerStatefulWidget {
  const BeamApp({super.key});

  @override
  ConsumerState<BeamApp> createState() => _BeamAppState();
}

class _BeamAppState extends ConsumerState<BeamApp> {
  @override
  void initState() {
    super.initState();
    // Deferred work: everything that isn't needed for the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _deferredInit());
  }

  Future<void> _deferredInit() async {
    final supported = await TorchApi.isSupported();
    ref.read(torchSupportedProvider.notifier).state = supported;

    final settings = ref.read(settingsProvider);
    // Keep the native auto-off timer in sync with the saved setting.
    await TorchApi.setAutoOffMinutes(settings.autoOffMinutes);
    // Restart the shake service if the user had it enabled.
    if (settings.shakeEnabled) {
      await TorchApi.setShakeEnabled(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beam Flash Light',
      debugShowCheckedModeBanner: false,
      theme: beamTheme(),
      home: const _Shell(),
    );
  }
}

class _Shell extends ConsumerWidget {
  const _Shell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supported = ref.watch(torchSupportedProvider);
    final tab = ref.watch(tabIndexProvider);

    if (supported == null) {
      // First frame: torch channel only. Show a blank dark stage.
      return const Scaffold(backgroundColor: BeamColors.bg);
    }

    if (!supported) {
      // No flash hardware: Screen light tab only, with an explanation.
      final items = ['Screen', 'Settings'];
      final index = tab.clamp(0, 1);
      return Scaffold(
        backgroundColor: BeamColors.bg,
        body: IndexedStack(
          index: index,
          children: const [
            ScreenLightScreen(noFlash: true),
            SettingsScreen(),
          ],
        ),
        bottomNavigationBar: _BottomNav(
          labels: items,
          icons: const [BeamIconKind.screen, BeamIconKind.gear],
          index: index,
          onTap: (i) => ref.read(tabIndexProvider.notifier).state = i,
        ),
      );
    }

    // Pages: 0 Torch, 1 Strobe/SOS, 2 Screen, 3 Settings.
    // The bottom bar shows Torch / Screen / Settings; Strobe is reached
    // from the Torch mode buttons and highlights the Torch tab.
    final page = tab.clamp(0, 3);
    final navIndex = page == 1 ? 0 : (page == 2 ? 1 : (page == 3 ? 2 : 0));
    return Scaffold(
      backgroundColor: BeamColors.bg,
      body: IndexedStack(
        // IndexedStack keeps the strobe screen alive across tabs on purpose;
        // the pattern stops only on back, background, or the power button.
        index: page,
        children: [
          TorchScreen(
            onGoToStrobe: (mode) {
              ref.read(strobeTabProvider.notifier).state = mode;
              ref.read(tabIndexProvider.notifier).state = 1;
            },
          ),
          const StrobeScreen(),
          const ScreenLightScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        labels: const ['Torch', 'Screen', 'Settings'],
        icons: const [
          BeamIconKind.power,
          BeamIconKind.screen,
          BeamIconKind.gear
        ],
        index: navIndex,
        onTap: (i) => ref.read(tabIndexProvider.notifier).state =
            i == 0 ? 0 : (i == 1 ? 2 : 3),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.labels,
    required this.icons,
    required this.index,
    required this.onTap,
  });

  final List<String> labels;
  final List<BeamIconKind> icons;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: BeamColors.surface,
        border: Border(top: BorderSide(color: BeamColors.line, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(labels.length, (i) {
            final selected = i == index;
            return Expanded(
              child: PressScale(
                semanticLabel: '${labels[i]} tab',
                onTap: () => onTap(i),
                child: Container(
                  height: 64,
                  color: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      BeamIcon(
                        icons[i],
                        size: 22,
                        color: selected
                            ? BeamColors.amber
                            : BeamColors.secondary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontFamily: 'BricolageGrotesque',
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                          color: selected
                              ? BeamColors.amber
                              : BeamColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 16,
                        height: 2,
                        decoration: BoxDecoration(
                          color: selected
                              ? BeamColors.amber
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
