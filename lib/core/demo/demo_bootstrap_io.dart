import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:komodo_go/core/connections/connection_profile.dart';
import 'package:komodo_go/core/connections/connections_store.dart';
import 'package:komodo_go/core/demo/demo_backend.dart';
import 'package:komodo_go/core/demo/demo_config.dart';
import 'package:komodo_go/core/demo/demo_preferences.dart';
import 'package:komodo_go/core/onboarding/onboarding_storage.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';

class DemoBootstrapImpl {
  static DemoBackend? _backend;

  static Future<void> ensureInitialized() async {
    if (!demoAvailable) return;

    final prefs = await SharedPreferences.getInstance();
    final secureStorage = SecureStorageService(const FlutterSecureStorage());
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
    final existing = connections
        .where(
          (c) =>
              c.name == demoConnectionName || c.baseUrl == credentials.baseUrl,
        )
        .toList();

    late final ConnectionProfile profile;
    if (existing.isEmpty) {
      profile = await store.addConnection(
        name: demoConnectionName,
        credentials: credentials,
      );
    } else {
      profile = existing.first.copyWith(
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

  static Future<void> _removeDemoConnection(ConnectionsStore store) async {
    final connections = await store.listConnections();
    final demoConnections =
        connections.where((c) => c.name == demoConnectionName).toList();
    final activeId = await store.getActiveConnectionId();
    for (final connection in demoConnections) {
      await store.deleteConnection(connection.id);
    }
    if (activeId != null && demoConnections.any((c) => c.id == activeId)) {
      await store.setActiveConnectionId(null);
    }
  }
}
