/// Pure domain model + unit-testable helpers for Beam.
/// No Flutter imports here so this file is trivially testable.

/// The three light modes.
enum TorchMode { steady, strobe, sos }

/// Snapshot of the real torch state, as reported by native code.
class TorchState {
  const TorchState({
    required this.on,
    required this.mode,
    required this.level,
    required this.brightnessSupported,
    required this.maxStrength,
    this.conflict = false,
  });

  factory TorchState.off() => const TorchState(
        on: false,
        mode: TorchMode.steady,
        level: 5,
        brightnessSupported: true,
        maxStrength: 1,
      );

  factory TorchState.fromMap(Map<dynamic, dynamic> map) {
    TorchMode mode;
    switch (map['mode'] as String?) {
      case 'strobe':
        mode = TorchMode.strobe;
        break;
      case 'sos':
        mode = TorchMode.sos;
        break;
      default:
        mode = TorchMode.steady;
    }
    return TorchState(
      on: map['on'] == true,
      mode: mode,
      level: (map['level'] as num?)?.toInt() ?? 5,
      brightnessSupported: map['brightnessSupported'] != false,
      maxStrength: (map['maxStrength'] as num?)?.toInt() ?? 1,
      conflict: map['conflict'] == true,
    );
  }

  final bool on;
  final TorchMode mode;
  final int level; // app-level step, 1..5
  final bool brightnessSupported;
  final int maxStrength; // native FLASH_INFO_STRENGTH_MAXIMUM_LEVEL
  final bool conflict; // true when another app grabbed the camera
}

/// Maps an app brightness step (1..5) onto the device native strength
/// range (1..maxLevel). Step 5 is always the device maximum.
int mapStepToNativeLevel(int step, int maxLevel) {
  final s = step.clamp(1, 5);
  if (maxLevel <= 1) return 1;
  final native = ((s - 1) * (maxLevel - 1) / 4).round() + 1;
  return native.clamp(1, maxLevel);
}

/// Inverse of [mapStepToNativeLevel]: nearest app step for a native level.
int nativeLevelToStep(int native, int maxLevel) {
  if (maxLevel <= 1) return 5;
  final n = native.clamp(1, maxLevel);
  final step = ((n - 1) * 4 / (maxLevel - 1)).round() + 1;
  return step.clamp(1, 5);
}

// ---------------------------------------------------------------------------
// SOS (Morse ··· −−− ···) timing, standard ITU timing.
// ---------------------------------------------------------------------------

/// Base time unit for the SOS pattern, in milliseconds.
const int sosUnitMs = 150;

/// Builds the SOS blink pattern as a flat list of [onMs, offMs, ...]
/// durations. Standard timing: dot = 1 unit, dash = 3 units,
/// intra-letter gap = 1 unit, letter gap = 3 units, and a 7-unit word gap
/// at the end so the pattern repeats cleanly.
List<int> buildSosPattern() {
  const dot = sosUnitMs;
  const dash = sosUnitMs * 3;
  const intra = sosUnitMs; // gap between dots/dashes within a letter
  const letterGap = sosUnitMs * 3; // gap between letters
  const wordGap = sosUnitMs * 7; // gap before the pattern repeats

  final pattern = <int>[];

  void addLetter(List<int> elements) {
    for (var i = 0; i < elements.length; i++) {
      pattern.add(elements[i]); // on
      pattern.add(i == elements.length - 1 ? letterGap : intra); // off
    }
  }

  addLetter([dot, dot, dot]); // S
  addLetter([dash, dash, dash]); // O
  addLetter([dot, dot, dot]); // S

  // Replace the trailing letter gap with the word gap so it loops cleanly.
  pattern[pattern.length - 1] = wordGap;
  return pattern;
}

/// Total duration of one SOS cycle in milliseconds.
int sosCycleMs() => buildSosPattern().fold(0, (a, b) => a + b);

/// Human-readable label for a brightness step, e.g. "3 / 5 · Medium".
String brightnessLabel(int step) {
  const names = ['', 'Low', 'Soft', 'Medium', 'High', 'Max'];
  return '$step / 5 · ${names[step.clamp(1, 5)]}';
}
