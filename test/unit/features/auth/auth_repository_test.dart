import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';
import 'package:komodo_go/features/auth/data/repositories/auth_repository.dart';

void main() {
  group('AuthRepository', () {
    group('normalizeCredentials', () {
      test('adds https:// when missing', () {
        final credentials = normalizeCredentials(
          baseUrl: 'komodo.example.com',
          apiKey: 'key',
          apiSecret: 'secret',
        );

        expect(credentials.baseUrl, equals('https://komodo.example.com'));
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
    });
  });
}
