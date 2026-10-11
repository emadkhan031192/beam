import 'package:beam/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildSosPattern', () {
    test('encodes ··· −−− ··· with standard timing', () {
      final p = buildSosPattern();
      // 9 elements, each [on, off] -> 18 entries.
      expect(p.length, 18);

      const u = sosUnitMs; // 150
      // S: dot, intra, dot, intra, dot, letter-gap
      expect(p.sublist(0, 6), [u, u, u, u, u, 3 * u]);
      // O: dash, intra, dash, intra, dash, letter-gap
      expect(p.sublist(6, 12), [3 * u, u, 3 * u, u, 3 * u, 3 * u]);
      // S again, ending with the 7-unit word gap so it loops cleanly.
      expect(p.sublist(12, 18), [u, u, u, u, u, 7 * u]);
    });

    test('one full cycle lasts 5.1 seconds', () {
      expect(sosCycleMs(), 5100);
    });

    test('all durations are positive', () {
      expect(buildSosPattern().every((d) => d > 0), isTrue);
    });
  });
}
