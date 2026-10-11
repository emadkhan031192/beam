import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences keys. Single source of truth for defaults.
class BeamKeys {
  static const lightOnOpen = 'lightOnOpen';
  static const shakeEnabled = 'shakeEnabled';
  static const startBrightness = 'startBrightness'; // app step 1..5
  static const autoOffMinutes = 'autoOffMinutes'; // 0 = never
  static const lowBatteryWarning = 'lowBatteryWarning';
  static const strobeWarning = 'strobeWarning';
  static const hapticOnPower = 'hapticOnPower';
  static const strobeSeenWarning = 'strobeSeenWarning';
  static const screenLightColor = 'screenLightColor'; // 0..5 index
  static const screenLightBrightness = 'screenLightBrightness'; // 0..1
  static const keepAwake = 'keepAwake';
}

/// Immutable snapshot of all user settings.
class BeamSettings {
  const BeamSettings({
    required this.lightOnOpen,
    required this.shakeEnabled,
    required this.startBrightness,
    required this.autoOffMinutes,
    required this.lowBatteryWarning,
    required this.strobeWarning,
    required this.hapticOnPower,
    required this.strobeSeenWarning,
    required this.screenLightColor,
    required this.screenLightBrightness,
    required this.keepAwake,
  });

  factory BeamSettings.defaults() => const BeamSettings(
        lightOnOpen: false,
        shakeEnabled: false,
        startBrightness: 5,
        autoOffMinutes: 0,
        lowBatteryWarning: true,
        strobeWarning: true,
        hapticOnPower: true,
        strobeSeenWarning: false,
        screenLightColor: 0,
        screenLightBrightness: 1.0,
        keepAwake: false,
      );

  factory BeamSettings.fromPrefs(SharedPreferences p) {
    final d = BeamSettings.defaults();
    return BeamSettings(
      lightOnOpen: p.getBool(BeamKeys.lightOnOpen) ?? d.lightOnOpen,
      shakeEnabled: p.getBool(BeamKeys.shakeEnabled) ?? d.shakeEnabled,
      startBrightness:
          (p.getInt(BeamKeys.startBrightness) ?? d.startBrightness).clamp(1, 5),
      autoOffMinutes: p.getInt(BeamKeys.autoOffMinutes) ?? d.autoOffMinutes,
      lowBatteryWarning:
          p.getBool(BeamKeys.lowBatteryWarning) ?? d.lowBatteryWarning,
      strobeWarning: p.getBool(BeamKeys.strobeWarning) ?? d.strobeWarning,
      hapticOnPower: p.getBool(BeamKeys.hapticOnPower) ?? d.hapticOnPower,
      strobeSeenWarning:
          p.getBool(BeamKeys.strobeSeenWarning) ?? d.strobeSeenWarning,
      screenLightColor:
          (p.getInt(BeamKeys.screenLightColor) ?? d.screenLightColor)
              .clamp(0, 5),
      screenLightBrightness:
          (p.getDouble(BeamKeys.screenLightBrightness) ??
                  d.screenLightBrightness)
              .clamp(0.0, 1.0),
      keepAwake: p.getBool(BeamKeys.keepAwake) ?? d.keepAwake,
    );
  }

  final bool lightOnOpen;
  final bool shakeEnabled;
  final int startBrightness;
  final int autoOffMinutes;
  final bool lowBatteryWarning;
  final bool strobeWarning;
  final bool hapticOnPower;
  final bool strobeSeenWarning;
  final int screenLightColor;
  final double screenLightBrightness;
  final bool keepAwake;

  BeamSettings copyWith({
    bool? lightOnOpen,
    bool? shakeEnabled,
    int? startBrightness,
    int? autoOffMinutes,
    bool? lowBatteryWarning,
    bool? strobeWarning,
    bool? hapticOnPower,
    bool? strobeSeenWarning,
    int? screenLightColor,
    double? screenLightBrightness,
    bool? keepAwake,
  }) =>
      BeamSettings(
        lightOnOpen: lightOnOpen ?? this.lightOnOpen,
        shakeEnabled: shakeEnabled ?? this.shakeEnabled,
        startBrightness: startBrightness ?? this.startBrightness,
        autoOffMinutes: autoOffMinutes ?? this.autoOffMinutes,
        lowBatteryWarning: lowBatteryWarning ?? this.lowBatteryWarning,
        strobeWarning: strobeWarning ?? this.strobeWarning,
        hapticOnPower: hapticOnPower ?? this.hapticOnPower,
        strobeSeenWarning: strobeSeenWarning ?? this.strobeSeenWarning,
        screenLightColor: screenLightColor ?? this.screenLightColor,
        keepAwake: keepAwake ?? this.keepAwake,
        screenLightBrightness:
            screenLightBrightness ?? this.screenLightBrightness,
      );
}

/// Thin persistence layer over SharedPreferences.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);
  Future<void> setDouble(String key, double value) =>
      _prefs.setDouble(key, value);

  BeamSettings load() => BeamSettings.fromPrefs(_prefs);
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Overridden in main() with the instance fetched before runApp.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('sharedPrefsProvider not overridden'),
);

final settingsRepoProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPrefsProvider)),
);

/// Holds the live settings; loaded once after the first frame.
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, BeamSettings>(
  (ref) => SettingsNotifier(ref.watch(settingsRepoProvider)),
);

class SettingsNotifier extends StateNotifier<BeamSettings> {
  SettingsNotifier(this._repo) : super(BeamSettings.defaults()) {
    // Synchronous initial read; prefs are already in memory.
    state = _repo.load();
  }

  final SettingsRepository _repo;

  Future<void> _saveBool(String key, bool value,
      BeamSettings Function(BeamSettings) apply) async {
    state = apply(state);
    await _repo.setBool(key, value);
  }

  Future<void> setLightOnOpen(bool v) =>
      _saveBool(BeamKeys.lightOnOpen, v, (s) => s.copyWith(lightOnOpen: v));

  Future<void> setShakeEnabled(bool v) =>
      _saveBool(BeamKeys.shakeEnabled, v, (s) => s.copyWith(shakeEnabled: v));

  Future<void> setLowBatteryWarning(bool v) => _saveBool(
      BeamKeys.lowBatteryWarning, v, (s) => s.copyWith(lowBatteryWarning: v));

  Future<void> setStrobeWarning(bool v) => _saveBool(
      BeamKeys.strobeWarning, v, (s) => s.copyWith(strobeWarning: v));

  Future<void> setHapticOnPower(bool v) => _saveBool(
      BeamKeys.hapticOnPower, v, (s) => s.copyWith(hapticOnPower: v));

  Future<void> setKeepAwake(bool v) =>
      _saveBool(BeamKeys.keepAwake, v, (s) => s.copyWith(keepAwake: v));

  Future<void> markStrobeWarningSeen() => _saveBool(BeamKeys.strobeSeenWarning,
      true, (s) => s.copyWith(strobeSeenWarning: true));

  Future<void> setStartBrightness(int v) async {
    state = state.copyWith(startBrightness: v.clamp(1, 5));
    await _repo.setInt(BeamKeys.startBrightness, state.startBrightness);
  }

  Future<void> setAutoOffMinutes(int v) async {
    state = state.copyWith(autoOffMinutes: v);
    await _repo.setInt(BeamKeys.autoOffMinutes, v);
  }

  Future<void> setScreenLightColor(int v) async {
    state = state.copyWith(screenLightColor: v.clamp(0, 5));
    await _repo.setInt(BeamKeys.screenLightColor, state.screenLightColor);
  }

  Future<void> setScreenLightBrightness(double v) async {
    state = state.copyWith(screenLightBrightness: v.clamp(0.0, 1.0));
    await _repo.setDouble(
        BeamKeys.screenLightBrightness, state.screenLightBrightness);
  }
}
