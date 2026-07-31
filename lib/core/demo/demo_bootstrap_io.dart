import 'package:komodo_go/core/connections/connection_profile.dart';
import 'package:komodo_go/core/connections/connections_store.dart';
import 'package:komodo_go/core/demo/demo_backend.dart';
import 'package:komodo_go/core/demo/demo_config.dart';
import 'package:komodo_go/core/demo/demo_preferences.dart';
import 'package:komodo_go/core/onboarding/onboarding_storage.dart';
import 'package:komodo_go/core/providers/storage_provider.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DemoBootstrapImpl {
  static DemoBackend? _backend;

  static Future<void> ensureInitialized() async {
    if (!demoAvailable) return;

    final prefs = await SharedPreferences.getInstance();
    final secureStorage = SecureStorageService(appSecureStorage);
    final store = ConnectionsStore(prefs: prefs, secureStorage: secureStorage);
    final hasCompletedOnboarding =
      prefs.getBool(onboardingSeenKey) ?? false;
    final demoEnabled = prefs.getBool(demoEnabledKey) ?? true;

    if (!demoEnabled) {
      await _removeDemoConnection(store);
      return;
    }

    final backend = _backend ??
        DemoBackend(apiKey: demoApiKey, apiSecret: demoApiSecret);
    _backend = backend;
    await backend.start();

    final credentials = ApiCredentials(
      baseUrl: backend.baseUrl,
      apiKey: demoApiKey,
      apiSecret: demoApiSecret,
    );

    final connections = await store.listConnections();
    final existing = _findDemoConnection(connections, credentials.baseUrl);

    late final ConnectionProfile profile;
    if (existing == null) {
      profile = await store.addConnection(
        id: demoConnectionId,
        name: demoConnectionName,
        credentials: credentials,
      );
    } else if (!isDemoConnection(existing)) {
      // Legacy demo profile with a random id: migrate it to the reserved
      // id so all demo checks can rely on the id instead of the name.
      profile = await _migrateLegacyDemoConnection(
        store: store,
        legacy: existing,
        credentials: credentials,
      );
    } else {
      profile = existing.copyWith(
        name: demoConnectionName,
        baseUrl: credentials.baseUrl,
        lastUsedAt: DateTime.now(),
      );
      await store.updateConnection(profile);
      await store.saveCredentials(profile.id, credentials);
    }

    if (demoAutoConnect && hasCompletedOnboarding) {
      final activeId = await store.getActiveConnectionId();
      if (activeId == null) {
        await store.setActiveConnectionId(profile.id);
      }
    }

  }

  /// Finds the existing demo connection, preferring the reserved id and
  /// falling back to legacy (loopback-only) detection for profiles created
  /// by older app versions.
  static ConnectionProfile? _findDemoConnection(
    List<ConnectionProfile> connections,
    String demoBaseUrl,
  ) {
    for (final connection in connections) {
      if (isDemoConnection(connection)) {
        return connection;
      }
    }
    for (final connection in connections) {
      if (isLegacyDemoConnection(connection) ||
          connection.baseUrl == demoBaseUrl) {
        return connection;
      }
    }
    return null;
  }

  /// Re-creates a legacy demo profile under the reserved [demoConnectionId],
  /// preserving the active selection if the legacy profile was active.
  static Future<ConnectionProfile> _migrateLegacyDemoConnection({
    required ConnectionsStore store,
    required ConnectionProfile legacy,
    required ApiCredentials credentials,
  }) async {
    final activeId = await store.getActiveConnectionId();
    final wasActive = activeId == legacy.id;
    await store.deleteConnection(legacy.id);
    final profile = await store.addConnection(
      id: demoConnectionId,
      name: demoConnectionName,
      credentials: credentials,
    );
    if (wasActive) {
      await store.setActiveConnectionId(profile.id);
    }
    return profile;
  }

  static Future<void> _removeDemoConnection(ConnectionsStore store) async {
    final connections = await store.listConnections();
    final demoConnections = connections
        .where((c) => isDemoConnection(c) || isLegacyDemoConnection(c))
        .toList();
    final activeId = await store.getActiveConnectionId();
    for (final connection in demoConnections) {
      await store.deleteConnection(connection.id);
    }
    if (activeId != null && demoConnections.any((c) => c.id == activeId)) {
      await store.setActiveConnectionId(null);
    }
  }
}
