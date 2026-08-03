import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/api/komodo_api_capabilities.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/onboarding/onboarding_storage.dart';
import 'package:komodo_go/core/providers/connections_provider.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/core/providers/shared_preferences_provider.dart';
import 'package:komodo_go/core/providers/storage_provider.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';
import 'package:komodo_go/features/auth/data/models/auth_state.dart';
import 'package:komodo_go/features/auth/data/repositories/auth_repository.dart';
import 'package:komodo_go/features/auth/presentation/providers/auth_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

const _credentials = ApiCredentials(
  baseUrl: 'https://komodo.example',
  apiKey: 'key',
  apiSecret: 'secret',
);
final _coreVersion = KomodoCoreVersion.parse('2.3.0');

void main() {
  setUpAll(() {
    registerFallbackValue(_credentials);
  });

  late Map<String, String> secureValues;
  late bool throwOnSecureRead;
  late bool throwOnSecureWrite;
  late _MockAuthRepository authRepository;
  late ProviderContainer container;

  ProviderContainer createContainer() {
    final storage = _MockFlutterSecureStorage();
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      if (throwOnSecureWrite) {
        throw Exception('Secure storage write unavailable');
      }
      final key = invocation.namedArguments[#key] as String;
      final value = invocation.namedArguments[#value] as String?;
      if (value == null) {
        secureValues.remove(key);
      } else {
        secureValues[key] = value;
      }
    });
    when(() => storage.read(key: any(named: 'key'))).thenAnswer((invocation) {
      if (throwOnSecureRead) {
        throw Exception('Secure storage unavailable');
      }
      return Future<String?>.value(
        secureValues[invocation.namedArguments[#key] as String],
      );
    });
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer(
      (invocation) async {
        secureValues.remove(invocation.namedArguments[#key] as String);
      },
    );

    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith(
          (ref) => SharedPreferences.getInstance(),
        ),
        flutterSecureStorageProvider.overrideWith((ref) => storage),
        authRepositoryProvider.overrideWith((ref) => authRepository),
      ],
    );
  }

  setUp(() {
    secureValues = <String, String>{};
    throwOnSecureRead = false;
    throwOnSecureWrite = false;
    authRepository = _MockAuthRepository();
    SharedPreferences.setMockInitialValues({onboardingSeenKey: true});
    container = createContainer();
    addTearDown(() => container.dispose());
  });

  Future<String> seedConnection() async {
    final store = await container.read(connectionsStoreProvider.future);
    final profile = await store.addConnection(
      name: 'Homelab',
      credentials: _credentials,
    );
    await store.setActiveConnectionId(profile.id);
    return profile.id;
  }

  group('Auth', () {
    test('restores and validates stored credentials on startup', () async {
      when(
        () => authRepository.validateCredentials(any()),
      ).thenAnswer((_) async => Right(_coreVersion));
      final connectionId = await seedConnection();

      final state = await container.read(authProvider.future);

      expect(state.isAuthenticated, isTrue);
      expect(state.connection?.id, connectionId);
      expect(state.credentials?.apiKey, 'key');
      expect(container.read(komodoCoreVersionProvider)?.display, 'v2.3.0');
    });

    test(
      'failed validation surfaces an error state, not authenticated',
      () async {
        when(
          () => authRepository.validateCredentials(any()),
        ).thenAnswer((_) async => const Left(Failure.auth()));
        await seedConnection();

        final state = await container.read(authProvider.future);

        expect(state.isAuthenticated, isFalse);
        expect(state, isA<AuthStateError>());
        expect(
          (state as AuthStateError).failure.displayMessage,
          contains('Could not connect to "Homelab"'),
        );
      },
    );

    test('missing saved credentials surface recovery instructions', () async {
      final connectionId = await seedConnection();
      final store = await container.read(connectionsStoreProvider.future);
      await store.deleteCredentials(connectionId);

      final state = await container.read(authProvider.future);

      expect(state, isA<AuthStateError>());
      expect(
        (state as AuthStateError).failure.displayMessage,
        allOf(
          contains('saved credentials for "Homelab" are unavailable'),
          contains('choose Edit'),
          contains('API key and secret'),
        ),
      );
      verifyNever(() => authRepository.validateCredentials(any()));
    });

    test(
      'selecting a connection with missing credentials surfaces feedback',
      () async {
        when(
          () => authRepository.validateCredentials(any()),
        ).thenAnswer((_) async => Right(_coreVersion));
        await seedConnection();
        await container.read(authProvider.future);

        final store = await container.read(connectionsStoreProvider.future);
        final unavailable = await store.addConnection(
          name: 'Production VPS',
          credentials: _credentials,
        );
        await store.deleteCredentials(unavailable.id);
        await container.read(connectionsProvider.notifier).reload();
        await container.read(authProvider.future);
        clearInteractions(authRepository);

        await container
            .read(authProvider.notifier)
            .selectConnection(unavailable.id);
        await container.pump();

        final state = container.read(authProvider).value;
        expect(state, isA<AuthStateError>());
        expect(
          (state! as AuthStateError).failure.displayMessage,
          allOf(
            contains('saved credentials for "Production VPS" are unavailable'),
            contains('choose Edit'),
          ),
        );
        verifyNever(() => authRepository.validateCredentials(any()));
      },
    );

    test('secure storage errors surface recovery instructions', () async {
      await seedConnection();
      throwOnSecureRead = true;

      final state = await container.read(authProvider.future);

      expect(state, isA<AuthStateError>());
      expect(
        (state as AuthStateError).failure.displayMessage,
        allOf(
          contains('Could not read the saved credentials for "Homelab"'),
          contains('secure storage'),
          contains('choose Edit'),
        ),
      );
      verifyNever(() => authRepository.validateCredentials(any()));
    });

    test('login persists the connection and credentials', () async {
      when(
        () => authRepository.validateCredentials(any()),
      ).thenAnswer((_) async => Right(_coreVersion));
      when(
        () => authRepository.authenticate(
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          apiSecret: any(named: 'apiSecret'),
          proxyAuthEnabled: any(named: 'proxyAuthEnabled'),
          proxyAuthUsername: any(named: 'proxyAuthUsername'),
          proxyAuthPassword: any(named: 'proxyAuthPassword'),
          customHeaders: any(named: 'customHeaders'),
        ),
      ).thenAnswer((_) async => const Right(_credentials));

      // No stored connections yet: starts unauthenticated.
      SharedPreferences.setMockInitialValues({onboardingSeenKey: false});
      container.dispose();
      container = createContainer();

      expect(
        (await container.read(authProvider.future)).isAuthenticated,
        isFalse,
      );

      await container
          .read(authProvider.notifier)
          .login(
            baseUrl: 'https://komodo.example',
            apiKey: 'key',
            apiSecret: 'secret',
            name: 'Homelab',
          );

      final state = container.read(authProvider).value;
      expect(state?.isAuthenticated, isTrue);
      expect(state?.connection?.name, 'Homelab');

      final store = await container.read(connectionsStoreProvider.future);
      final stored = await store.getCredentials(state!.connection!.id);
      expect(stored?.apiKey, 'key');
      expect(stored?.apiSecret, 'secret');
    });

    test(
      'login reports secure storage failures without adding a profile',
      () async {
        when(
          () => authRepository.authenticate(
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            apiSecret: any(named: 'apiSecret'),
            proxyAuthEnabled: any(named: 'proxyAuthEnabled'),
            proxyAuthUsername: any(named: 'proxyAuthUsername'),
            proxyAuthPassword: any(named: 'proxyAuthPassword'),
            customHeaders: any(named: 'customHeaders'),
          ),
        ).thenAnswer((_) async => const Right(_credentials));

        SharedPreferences.setMockInitialValues({onboardingSeenKey: false});
        container.dispose();
        container = createContainer();
        expect(
          (await container.read(authProvider.future)).isAuthenticated,
          isFalse,
        );
        throwOnSecureWrite = true;

        await container
            .read(authProvider.notifier)
            .login(
              baseUrl: 'https://komodo.example',
              apiKey: 'key',
              apiSecret: 'secret',
              name: 'Homelab',
            );

        final state = container.read(authProvider).value;
        expect(state, isA<AuthStateError>());
        expect(
          (state! as AuthStateError).failure.displayMessage,
          contains('could not be saved securely'),
        );
        final store = await container.read(connectionsStoreProvider.future);
        expect(await store.listConnections(), isEmpty);
      },
    );

    test('logout clears the active connection and authentication', () async {
      when(
        () => authRepository.validateCredentials(any()),
      ).thenAnswer((_) async => Right(_coreVersion));
      await seedConnection();
      await container.read(authProvider.future);

      await container.read(authProvider.notifier).logout();
      await container.pump();

      expect(
        container.read(authProvider).value,
        const AuthState.unauthenticated(),
      );
      final store = await container.read(connectionsStoreProvider.future);
      expect(await store.getActiveConnectionId(), isNull);
    });

    test('selectConnection validates the credentials exactly once', () async {
      when(
        () => authRepository.validateCredentials(any()),
      ).thenAnswer((_) async => Right(_coreVersion));
      await seedConnection();
      await container.read(authProvider.future);

      final second = await container
          .read(connectionsProvider.notifier)
          .addConnection(name: 'Second', credentials: _credentials);
      await container.read(authProvider.future);
      await container.pump();
      clearInteractions(authRepository);

      await container.read(authProvider.notifier).selectConnection(second.id);
      await container.read(authProvider.future);
      await container.pump();

      final state = container.read(authProvider).value;
      expect(state?.isAuthenticated, isTrue);
      expect(state?.connection?.id, second.id);
      verify(() => authRepository.validateCredentials(any())).called(1);
    });
  });
}
