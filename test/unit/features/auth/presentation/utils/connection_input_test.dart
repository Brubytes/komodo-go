import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/auth/presentation/utils/connection_input.dart';

void main() {
  group('normalizeServerUrl', () {
    test('prepends https and strips trailing slash', () {
      expect(
        normalizeServerUrl(' komodo.example.com/ '),
        'https://komodo.example.com',
      );
    });

    test('keeps explicit scheme', () {
      expect(
        normalizeServerUrl('http://10.0.0.5:9120'),
        'http://10.0.0.5:9120',
      );
    });

    test('empty stays empty', () {
      expect(normalizeServerUrl('  '), '');
    });
  });

  group('splitKeySecret', () {
    test('splits on colon', () {
      final pair = splitKeySecret('K-abc:S-def');
      expect(pair?.key, 'K-abc');
      expect(pair?.secret, 'S-def');
    });

    test('splits on whitespace', () {
      final pair = splitKeySecret('K-abc S-def');
      expect(pair?.secret, 'S-def');
    });

    test('ignores a single token', () {
      expect(splitKeySecret('K-abc'), isNull);
    });
  });
}
