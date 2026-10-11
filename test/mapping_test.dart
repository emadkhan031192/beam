import 'package:beam/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapStepToNativeLevel', () {
    test('step 5 is always the device maximum', () {
      expect(mapStepToNativeLevel(5, 1), 1);
      expect(mapStepToNativeLevel(5, 10), 10);
      expect(mapStepToNativeLevel(5, 255), 255);
    });

    test('step 1 is always the minimum', () {
      expect(mapStepToNativeLevel(1, 10), 1);
      expect(mapStepToNativeLevel(1, 255), 1);
    });

    test('maps linearly across the range', () {
      // max 5 -> identity
      for (var s = 1; s <= 5; s++) {
        expect(mapStepToNativeLevel(s, 5), s);
      }
      // max 9 -> 1,3,5,7,9
      expect(mapStepToNativeLevel(2, 9), 3);
      expect(mapStepToNativeLevel(3, 9), 5);
      expect(mapStepToNativeLevel(4, 9), 7);
    });

    test('clamps out-of-range steps', () {
      expect(mapStepToNativeLevel(0, 10), 1);
      expect(mapStepToNativeLevel(99, 10), 10);
    });

    test('maxLevel 1 collapses to a single level', () {
      for (var s = 1; s <= 5; s++) {
        expect(mapStepToNativeLevel(s, 1), 1);
      }
    });
  });

  group('nativeLevelToStep', () {
    test('round-trips exactly when the range divides evenly', () {
      // (maxLevel - 1) divisible by 4 -> every step has a distinct level.
      for (final max in [5, 9, 13, 101]) {
        for (var s = 1; s <= 5; s++) {
          final native = mapStepToNativeLevel(s, max);
          expect(nativeLevelToStep(native, max), s,
              reason: 'step $s with max $max');
        }
      }
    });

    test('stays within one step on coarse hardware ranges', () {
      // Tiny ranges collapse steps; the inverse must still land nearby.
      // (maxLevel 2 is excluded: steps 2-4 all collapse onto 2 levels, so the
      // nearest-step inverse is ambiguous by design.)
      for (final max in [3, 4, 6, 10, 255]) {
        for (var s = 1; s <= 5; s++) {
          final native = mapStepToNativeLevel(s, max);
          expect(
              (nativeLevelToStep(native, max) - s).abs(), lessThanOrEqualTo(1),
              reason: 'step $s with max $max');
        }
      }
    });

    test('endpoints always map back to themselves', () {
      for (final max in [2, 3, 7, 64, 255]) {
        expect(nativeLevelToStep(1, max), 1);
        expect(nativeLevelToStep(max, max), 5);
      }
    });

    test('maxLevel 1 maps everything to step 5', () {
      expect(nativeLevelToStep(1, 1), 5);
    });
  });

  group('brightnessLabel', () {
    test('formats the label', () {
      expect(brightnessLabel(3), '3 / 5 · Medium');
      expect(brightnessLabel(1), '1 / 5 · Low');
      expect(brightnessLabel(5), '5 / 5 · Max');
    });
  });
}
