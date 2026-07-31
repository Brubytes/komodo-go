import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/connections/connection_profile.dart';
import 'package:komodo_go/core/demo/demo_config.dart';
import 'package:komodo_go/core/demo/demo_preferences.dart';
import 'package:komodo_go/core/onboarding/onboarding_storage.dart';
import 'package:komodo_go/core/providers/connections_provider.dart';
import 'package:komodo_go/core/providers/demo_mode_provider.dart';
import 'package:komodo_go/core/providers/shared_preferences_provider.dart';
import 'package:komodo_go/core/providers/storage_provider.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

const _realCredentials = ApiCredentials(
  baseUrl: 'https://my-komodo.example.com',
  apiKey: 'real-key',
  apiSecret: 'real-secret',
);

const _demoCredentials = ApiCredentials(
  baseUrl: 'http://127.0.0.1:52341',
  apiKey: 'demo-key',
  apiSecret: 'demo-secret',
);

ConnectionProfile _profile({
  required String id,
  required String name,
  required String baseUrl,
}) {
  return ConnectionProfile(
    id: id,
    name: name,
    baseUrl: baseUrl,
    createdAt: DateTime(2026),
    lastUsedAt: DateTime(2026),
  );
}

void main() {
  late Map<String, String> secureValues;
  late ProviderContainer container;

  ProviderContainer createContainer() {
    final storage = _MockFlutterSecureStorage();
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      final key = invocation.namedArguments[#key] as String;
      final value = invocation.namedArguments[#value] as String?;
      if (value == null) {
        secureValues.remove(key);
      } else {
        secureValues[key] = value;
      }
    });
    when(() => storage.read(key: any(named: 'key'))).thenAnswer(
      (invocation) async =>
          secureValues[invocation.namedArguments[#key] as String],
    );
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
      ],
    );
  }

  setUp(() {
    secureValues = <String, String>{};
    SharedPreferences.setMockInitialValues({
      demoEnabledKey: true,
      onboardingSeenKey: true,
    });
    container = createContainer();
    addTearDown(() => container.dispose());
  });

  group('DemoModeNotifier.setEnabled(false)', () {
    test(
      'does not delete a real connection merely named "Komodo Demo"',
      () async {
        final store = await container.read(connectionsStoreProvider.future);
        final profile = await store.addConnection(
          name: 'Komodo Demo',
          credentials: _realCredentials,
        );

        await container.read(demoModeProvider.future);
        await container
            .read(demoModeProvider.notifier)
            .setEnabled(enabled: false);

        final remaining = await store.listConnections();
        expect(
          remaining.map((c) => c.id),
          contains(profile.id),
          reason: 'A user connection that happens to share the demo display '
              'name must never be deleted when demo mode is disabled.',
        );
        expect(
          await store.getCredentials(profile.id),
          isNotNull,
          reason: 'Stored credentials of the real connection must survive.',
        );
      },
    );

    test('deletes the actual demo connection (reserved id)', () async {
      final store = await container.read(connectionsStoreProvider.future);
      final demo = await store.addConnection(
        id: demoConnectionId,
        name: demoConnectionName,
        credentials: _demoCredentials,
      );
      final real = await store.addConnection(
        name: 'Homelab',
        credentials: _realCredentials,
      );

      await container.read(demoModeProvider.future);
      await container
          .read(demoModeProvider.notifier)
          .setEnabled(enabled: false);

      final remainingIds =
          (await store.listConnections()).map((c) => c.id).toList();
      expect(remainingIds, isNot(contains(demo.id)));
      expect(remainingIds, contains(real.id));
      expect(await store.getCredentials(demo.id), isNull);
    });
  });

  group('demo connection identification', () {
    test('isDemoConnection matches only the reserved id', () {
      expect(
        isDemoConnection(
          _profile(
            id: demoConnectionId,
            name: 'Renamed by user',
            baseUrl: 'http://127.0.0.1:52341',
          ),
        ),
        isTrue,
      );
      expect(
        isDemoConnection(
          _profile(
            id: 'random-id',
            name: demoConnectionName,
            baseUrl: 'http://127.0.0.1:52341',
          ),
        ),
        isFalse,
      );
    });

    test(
      'isLegacyDemoConnection requires the demo name and a loopback URL',
      () {
        expect(
          isLegacyDemoConnection(
            _profile(
              id: 'random-id',
              name: demoConnectionName,
              baseUrl: 'http://127.0.0.1:52341',
            ),
          ),
          isTrue,
        );
        expect(
          isLegacyDemoConnection(
            _profile(
              id: 'random-id',
              name: demoConnectionName,
              baseUrl: 'http://localhost:9120',
            ),
          ),
          isTrue,
        );
        // A real remote connection sharing the demo name is never matched.
        expect(
          isLegacyDemoConnection(
            _profile(
              id: 'random-id',
              name: demoConnectionName,
              baseUrl: 'https://my-komodo.example.com',
            ),
          ),
          isFalse,
        );
        // A loopback connection with a different name is never matched.
        expect(
          isLegacyDemoConnection(
            _profile(
              id: 'random-id',
              name: 'Local Komodo',
              baseUrl: 'http://127.0.0.1:9120',
            ),
          ),
          isFalse,
        );
      },
    );
  });
}
