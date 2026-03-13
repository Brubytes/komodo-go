import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/api/custom_header.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';
import 'package:komodo_go/features/auth/data/repositories/auth_repository.dart';

void main() {
  group('AuthRepository', () {
    group('normalizeCredentials', () {
      test('keeps URL as entered when protocol is omitted', () {
        final credentials = normalizeCredentials(
          baseUrl: 'komodo.example.com',
          apiKey: 'key',
          apiSecret: 'secret',
        );

        expect(credentials.baseUrl, equals('komodo.example.com'));
      });

      test('preserves explicit http URLs', () {
        final credentials = normalizeCredentials(
          baseUrl: 'http://100.64.0.5:9120',
          apiKey: 'key',
          apiSecret: 'secret',
        );

        expect(credentials.baseUrl, equals('http://100.64.0.5:9120'));
      });

      test('removes trailing slash', () {
        final credentials = normalizeCredentials(
          baseUrl: 'https://komodo.example.com/',
          apiKey: 'key',
          apiSecret: 'secret',
        );

        expect(credentials.baseUrl, equals('https://komodo.example.com'));
      });

      test('trims key and secret', () {
        final credentials = normalizeCredentials(
          baseUrl: 'https://komodo.example.com',
          apiKey: '  key  ',
          apiSecret: '  secret  ',
        );

        expect(credentials.apiKey, equals('key'));
        expect(credentials.apiSecret, equals('secret'));
      });

      test('returns ApiCredentials', () {
        final credentials = normalizeCredentials(
          baseUrl: 'https://komodo.example.com',
          apiKey: 'key',
          apiSecret: 'secret',
        );

        expect(credentials, isA<ApiCredentials>());
      });

      test('trims optional proxy header auth fields', () {
        final credentials = normalizeCredentials(
          baseUrl: 'https://komodo.example.com',
          apiKey: 'key',
          apiSecret: 'secret',
          proxyAuthEnabled: true,
          proxyAuthUsername: '  user  ',
          proxyAuthPassword: '  pass  ',
        );

        expect(credentials.proxyAuth, isNotNull);
        expect(credentials.proxyAuth?.shouldApply, isTrue);
        expect(credentials.proxyAuth?.username, equals('user'));
        expect(credentials.proxyAuth?.password, equals('pass'));
      });

      test('keeps proxy auth stored but inactive when disabled', () {
        final credentials = normalizeCredentials(
          baseUrl: 'https://komodo.example.com',
          apiKey: 'key',
          apiSecret: 'secret',
          proxyAuthEnabled: false,
          proxyAuthUsername: 'user',
          proxyAuthPassword: 'pass',
        );

        expect(credentials.proxyAuth, isNotNull);
        expect(credentials.proxyAuth?.enabled, isFalse);
        expect(credentials.proxyAuth?.shouldApply, isFalse);
      });

      test('normalizes blank optional proxy header auth fields to null', () {
        final credentials = normalizeCredentials(
          baseUrl: 'https://komodo.example.com',
          apiKey: 'key',
          apiSecret: 'secret',
          proxyAuthUsername: '   ',
          proxyAuthPassword: '',
        );

        expect(credentials.proxyAuth, isNull);
      });

      test('normalizes incomplete proxy auth pair to null', () {
        final credentials = normalizeCredentials(
          baseUrl: 'https://komodo.example.com',
          apiKey: 'key',
          apiSecret: 'secret',
          proxyAuthUsername: 'user',
          proxyAuthPassword: '   ',
        );

        expect(credentials.proxyAuth, isNull);
      });

      test('sanitizes custom headers and drops reserved keys', () {
        final credentials = normalizeCredentials(
          baseUrl: 'https://komodo.example.com',
          apiKey: 'key',
          apiSecret: 'secret',
          customHeaders: const [
            CustomHeader(key: ' X-Test ', value: ' one '),
            CustomHeader(key: 'Authorization', value: 'blocked'),
            CustomHeader(key: 'x-test', value: 'two'),
            CustomHeader(key: ' ', value: 'ignored'),
          ],
        );

        expect(credentials.customHeaders, hasLength(1));
        expect(credentials.customHeaders.single.key, equals('x-test'));
        expect(credentials.customHeaders.single.value, equals('two'));
      });
    });
  });
}
