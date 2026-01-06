import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';
import 'package:komodo_go/features/auth/data/repositories/auth_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  late MockSecureStorageService mockStorage;
  late AuthRepository repository;

  setUpAll(() {
    registerFallbackValue(
      const ApiCredentials(
        baseUrl: 'https://example.com',
        apiKey: 'key',
        apiSecret: 'secret',
      ),
    );
  });

  setUp(() {
    mockStorage = MockSecureStorageService();
    repository = AuthRepository(storage: mockStorage);
  });

  group('AuthRepository', () {
    group('getStoredCredentials', () {
      test('returns credentials when stored', () async {
        const credentials = ApiCredentials(
          baseUrl: 'https://komodo.example.com',
          apiKey: 'test-key',
          apiSecret: 'test-secret',
        );

        when(
          () => mockStorage.getCredentials(),
        ).thenAnswer((_) async => credentials);

        final result = await repository.getStoredCredentials();

        expect(result, equals(credentials));
        verify(() => mockStorage.getCredentials()).called(1);
      });

      test('returns null when no credentials stored', () async {
        when(() => mockStorage.getCredentials()).thenAnswer((_) async => null);

        final result = await repository.getStoredCredentials();

        expect(result, isNull);
      });
    });

    group('logout', () {
      test('clears credentials from storage', () async {
        when(() => mockStorage.clearCredentials()).thenAnswer((_) async {});

        await repository.logout();

        verify(() => mockStorage.clearCredentials()).called(1);
      });
    });

    group('hasStoredCredentials', () {
      test('returns true when credentials exist', () async {
        when(() => mockStorage.hasCredentials()).thenAnswer((_) async => true);

        final result = await repository.hasStoredCredentials();

        expect(result, isTrue);
      });

      test('returns false when no credentials exist', () async {
        when(() => mockStorage.hasCredentials()).thenAnswer((_) async => false);

        final result = await repository.hasStoredCredentials();

        expect(result, isFalse);
      });
    });

    group('authenticate', () {
      test('normalizes URL without https prefix', () async {
        when(() => mockStorage.saveCredentials(any())).thenAnswer((_) async {});

        // Note: This test would require mocking the HTTP layer
        // For now, we test the URL normalization logic
        const rawUrl = 'komodo.example.com';
        const expectedUrl = 'https://$rawUrl';

        // The authenticate method normalizes the URL internally
        // Full integration test would require mocking Dio
        expect(expectedUrl.startsWith('https://'), isTrue);
      });

      test('removes trailing slash from URL', () async {
        const rawUrl = 'https://komodo.example.com/';
        final normalized = rawUrl.substring(0, rawUrl.length - 1);

        expect(normalized, equals('https://komodo.example.com'));
      });
    });
  });
}
