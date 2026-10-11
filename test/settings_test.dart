import 'package:beam/core/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('BeamSettings defaults', () {
    test('match the spec', () {
      final d = BeamSettings.defaults();
      expect(d.lightOnOpen, isFalse);
      expect(d.shakeEnabled, isFalse);
      expect(d.startBrightness, 5);
      expect(d.autoOffMinutes, 0);
      expect(d.lowBatteryWarning, isTrue);
      expect(d.strobeWarning, isTrue);
      expect(d.hapticOnPower, isTrue);
      expect(d.strobeSeenWarning, isFalse);
      expect(d.screenLightColor, 0);
      expect(d.screenLightBrightness, 1.0);
      expect(d.keepAwake, isFalse);
    });
  });

  group('BeamSettings.fromPrefs', () {
    test('reads stored values', () async {
      SharedPreferences.setMockInitialValues({
        BeamKeys.lightOnOpen: true,
        BeamKeys.startBrightness: 3,
        BeamKeys.autoOffMinutes: 15,
        BeamKeys.strobeWarning: false,
        BeamKeys.screenLightColor: 2,
        BeamKeys.screenLightBrightness: 0.5,
      });
      final prefs = await SharedPreferences.getInstance();
      final s = BeamSettings.fromPrefs(prefs);
      expect(s.lightOnOpen, isTrue);
      expect(s.startBrightness, 3);
      expect(s.autoOffMinutes, 15);
      expect(s.strobeWarning, isFalse);
      expect(s.screenLightColor, 2);
      expect(s.screenLightBrightness, 0.5);
      // Untouched keys keep their defaults.
      expect(s.shakeEnabled, isFalse);
      expect(s.lowBatteryWarning, isTrue);
    });

    test('clamps out-of-range values', () async {
      SharedPreferences.setMockInitialValues({
        BeamKeys.startBrightness: 99,
        BeamKeys.screenLightColor: -4,
        BeamKeys.screenLightBrightness: 7.5,
      });
      final prefs = await SharedPreferences.getInstance();
      final s = BeamSettings.fromPrefs(prefs);
      expect(s.startBrightness, 5);
      expect(s.screenLightColor, 0);
      expect(s.screenLightBrightness, 1.0);
    });

    test('copyWith preserves untouched fields', () {
      final d = BeamSettings.defaults();
      final updated = d.copyWith(startBrightness: 2, hapticOnPower: false);
      expect(updated.startBrightness, 2);
      expect(updated.hapticOnPower, isFalse);
      expect(updated.lightOnOpen, d.lightOnOpen);
      expect(updated.strobeWarning, d.strobeWarning);
    });
  });
}
