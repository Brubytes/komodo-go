import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:komodo_go/core/connections/connections_store.dart';
import 'package:komodo_go/core/demo/demo_backend.dart';
import 'package:komodo_go/core/demo/demo_config.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';

class DemoBootstrapImpl {
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (!demoModeEnabled || _initialized) return;

    final backend = DemoBackend(apiKey: demoApiKey, apiSecret: demoApiSecret);
    await backend.start();

    final prefs = await SharedPreferences.getInstance();
    final secureStorage = SecureStorageService(const FlutterSecureStorage());
    final store = ConnectionsStore(prefs: prefs, secureStorage: secureStorage);

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

    if (existing.isEmpty) {
      final profile = await store.addConnection(
        name: demoConnectionName,
        credentials: credentials,
      );
      await store.setActiveConnectionId(profile.id);
    } else {
      final profile = existing.first.copyWith(
        name: demoConnectionName,
        baseUrl: credentials.baseUrl,
        lastUsedAt: DateTime.now(),
      );
      await store.updateConnection(profile);
      await store.saveCredentials(profile.id, credentials);
      await store.setActiveConnectionId(profile.id);
    }

    _initialized = true;
  }
}
