import 'package:komodo_go/core/connections/connection_profile.dart';
import 'package:komodo_go/core/connections/connections_store.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/core/providers/shared_preferences_provider.dart';
import 'package:komodo_go/core/providers/storage_provider.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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

  Future<void> updateConnectionDetails({
    required String connectionId,
    String? name,
    String? baseUrl,
    String? apiKey,
    String? apiSecret,
  }) async {
    final store = await ref.read(connectionsStoreProvider.future);

    final connections = await store.listConnections();
    final matches = connections.where((c) => c.id == connectionId).toList();
    if (matches.isEmpty) {
      return;
    }

    final currentProfile = matches.first;
    final currentCredentials = await store.getCredentials(connectionId);

    final nextNameTrimmed = name?.trim();
    final nextName = (nextNameTrimmed == null || nextNameTrimmed.isEmpty)
        ? currentProfile.name
        : nextNameTrimmed;

    final nextBaseUrlTrimmed = baseUrl?.trim();
    final nextBaseUrl = (nextBaseUrlTrimmed == null || nextBaseUrlTrimmed.isEmpty)
        ? currentProfile.baseUrl
        : nextBaseUrlTrimmed;

    final updatedProfile = currentProfile.copyWith(
      name: nextName,
      baseUrl: nextBaseUrl,
    );

    await store.updateConnection(updatedProfile);

    final nextApiKeyTrimmed = apiKey?.trim();
    final nextApiSecretTrimmed = apiSecret?.trim();
    final hasKey = nextApiKeyTrimmed != null && nextApiKeyTrimmed.isNotEmpty;
    final hasSecret =
        nextApiSecretTrimmed != null && nextApiSecretTrimmed.isNotEmpty;

    if (currentCredentials != null) {
      final updatedCredentials = ApiCredentials(
        baseUrl: nextBaseUrl,
        apiKey: hasKey ? nextApiKeyTrimmed : currentCredentials.apiKey,
        apiSecret: hasSecret ? nextApiSecretTrimmed : currentCredentials.apiSecret,
      );
      await store.saveCredentials(connectionId, updatedCredentials);

      final active = ref.read(activeConnectionProvider);
      if (active?.connectionId == connectionId) {
        ref.read(activeConnectionProvider.notifier).active = ActiveConnectionData(
          connectionId: connectionId,
          name: updatedProfile.name,
          credentials: updatedCredentials,
        );
      }
    } else if (hasKey && hasSecret) {
      await store.saveCredentials(
        connectionId,
        ApiCredentials(
          baseUrl: nextBaseUrl,
          apiKey: nextApiKeyTrimmed,
          apiSecret: nextApiSecretTrimmed,
        ),
      );
    }

    state = AsyncValue.data(
      ConnectionsState(
        connections: await store.listConnections(),
        activeConnectionId: state.asData?.value.activeConnectionId,
      ),
    );
  }
}
