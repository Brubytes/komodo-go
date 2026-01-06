import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../connections/connection_profile.dart';
import '../connections/connections_store.dart';
import '../storage/secure_storage_service.dart';
import 'shared_preferences_provider.dart';
import 'storage_provider.dart';

part 'connections_provider.g.dart';

class ConnectionsState {
  const ConnectionsState({
    required this.connections,
    required this.activeConnectionId,
  });

  final List<ConnectionProfile> connections;
  final String? activeConnectionId;

  ConnectionProfile? get activeConnection {
    final id = activeConnectionId;
    if (id == null) {
      return null;
    }
    for (final c in connections) {
      if (c.id == id) {
        return c;
      }
    }
    return null;
  }
}

@riverpod
Future<ConnectionsStore> connectionsStore(Ref ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return ConnectionsStore(
    prefs: prefs,
    secureStorage: ref.watch(secureStorageProvider),
  );
}

@Riverpod(keepAlive: true)
class Connections extends _$Connections {
  @override
  Future<ConnectionsState> build() async {
    final store = await ref.watch(connectionsStoreProvider.future);

    final connections = await store.listConnections();
    var activeId = await store.getActiveConnectionId();

    if (activeId == null && connections.length == 1) {
      activeId = connections.first.id;
      await store.setActiveConnectionId(activeId);
    }

    return ConnectionsState(
      connections: connections,
      activeConnectionId: activeId,
    );
  }

  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> setActiveConnection(String? connectionId) async {
    final store = await ref.read(connectionsStoreProvider.future);
    await store.setActiveConnectionId(connectionId);
    state = AsyncValue.data(
      ConnectionsState(
        connections:
            state.asData?.value.connections ?? await store.listConnections(),
        activeConnectionId: connectionId,
      ),
    );
  }

  Future<ConnectionProfile> addConnection({
    required String name,
    required ApiCredentials credentials,
  }) async {
    final store = await ref.read(connectionsStoreProvider.future);
    final profile = await store.addConnection(
      name: name,
      credentials: credentials,
    );
    await store.setActiveConnectionId(profile.id);
    final connections = await store.listConnections();
    state = AsyncValue.data(
      ConnectionsState(
        connections: connections,
        activeConnectionId: profile.id,
      ),
    );
    return profile;
  }

  Future<void> renameConnection({
    required String connectionId,
    required String name,
  }) async {
    final store = await ref.read(connectionsStoreProvider.future);
    final connections = await store.listConnections();
    final current = connections.where((c) => c.id == connectionId).toList();
    if (current.isEmpty) {
      return;
    }
    await store.updateConnection(current.first.copyWith(name: name));
    state = AsyncValue.data(
      ConnectionsState(
        connections: await store.listConnections(),
        activeConnectionId: state.asData?.value.activeConnectionId,
      ),
    );
  }

  Future<void> deleteConnection(String connectionId) async {
    final store = await ref.read(connectionsStoreProvider.future);
    await store.deleteConnection(connectionId);
    state = AsyncValue.data(
      ConnectionsState(
        connections: await store.listConnections(),
        activeConnectionId: await store.getActiveConnectionId(),
      ),
    );
  }
}
