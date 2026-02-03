import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/demo/demo_bootstrap.dart';
import 'package:komodo_go/core/demo/demo_config.dart';
import 'package:komodo_go/core/demo/demo_preferences.dart';
import 'package:komodo_go/core/providers/connections_provider.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/core/providers/shared_preferences_provider.dart';
import 'package:komodo_go/features/auth/presentation/providers/auth_provider.dart';

final demoModeProvider =
    AsyncNotifierProvider<DemoModeNotifier, bool>(DemoModeNotifier.new);

class DemoModeNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return prefs.getBool(demoEnabledKey) ?? true;
  }

  Future<void> setEnabled({required bool enabled}) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(demoEnabledKey, enabled);
    state = AsyncValue.data(enabled);

    final store = await ref.read(connectionsStoreProvider.future);
    final connections = await store.listConnections();
    final demoConnections = connections
        .where((c) => c.name == demoConnectionName)
        .toList();

    if (!enabled) {
      final activeId = await store.getActiveConnectionId();
      for (final connection in demoConnections) {
        await store.deleteConnection(connection.id);
      }
      if (activeId != null &&
          demoConnections.any((c) => c.id == activeId)) {
        await ref.read(authProvider.notifier).logout();
        ref.read(activeConnectionProvider.notifier).clear();
      }
      await ref.read(connectionsProvider.notifier).reload();
      return;
    }

    if (demoAvailable) {
      await DemoBootstrap.ensureInitialized();
      await ref.read(connectionsProvider.notifier).reload();
    }
  }
}
