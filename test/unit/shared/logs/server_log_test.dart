import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/shared/logs/server_log.dart';

void main() {
  group('ServerLogSnapshot.capped', () {
    test('retains only the selected number of matching lines', () {
      final source = List.generate(
        1000,
        (index) => 'TASK $index ${List.filled(240, '*').join()}',
      ).join('\n');

      final capped = ServerLogSnapshot(stdout: source).capped(tail: 200);

      expect(capped.truncated, isTrue);
      expect(capped.combined, startsWith('[Output truncated'));
      expect(capped.stdout, isNot(contains('TASK 799 ')));
      expect(capped.stdout, contains('TASK 800 '));
      expect(capped.stdout, contains('TASK 999 '));
      expect(capped.stdout.split('\n'), hasLength(200));
    });

    test('caps a pathological single line by character count', () {
      final capped = ServerLogSnapshot(
        stdout: List.filled(300000, 'x').join(),
      ).capped(tail: 200);

      expect(capped.truncated, isTrue);
      expect(capped.stdout.length, 250000);
    });

    test('leaves small output unchanged', () {
      const source = ServerLogSnapshot(stdout: 'PLAY one\nTASK two');

      final capped = source.capped(tail: 200);

      expect(capped.truncated, isFalse);
      expect(capped.combined, 'PLAY one\nTASK two');
    });
  });
}
