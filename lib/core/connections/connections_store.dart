import 'dart:math';

import 'package:komodo_go/core/connections/connection_profile.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConnectionsStore {
  ConnectionsStore({
    required SharedPreferences prefs,
    required SecureStorageService secureStorage,
  }) : _prefs = prefs,
       _secureStorage = secureStorage;

  final SharedPreferences _prefs;
  final SecureStorageService _secureStorage;

  static const _connectionsKey = 'komodo_connections_v1';
  static const _activeConnectionIdKey = 'komodo_active_connection_id_v1';

  Future<List<ConnectionProfile>> listConnections() async {
    final raw = _prefs.getString(_connectionsKey);
    if (raw == null || raw.isEmpty) {
      return <ConnectionProfile>[];
    }
    try {
      return decodeConnectionProfiles(raw);
    } on Exception {
      return <ConnectionProfile>[];
    }
  }

  Future<void> saveConnections(List<ConnectionProfile> connections) async {
    await _prefs.setString(
      _connectionsKey,
      encodeConnectionProfiles(connections),
    );
  }

  Future<String?> getActiveConnectionId() async {
    return _prefs.getString(_activeConnectionIdKey);
  }

  Future<void> setActiveConnectionId(String? id) async {
    if (id == null) {
      await _prefs.remove(_activeConnectionIdKey);
      return;
    }
    await _prefs.setString(_activeConnectionIdKey, id);
  }

  Future<ApiCredentials?> getCredentials(String connectionId) {
    return _secureStorage.getCredentialsForConnection(connectionId);
  }

  Future<void> saveCredentials(
    String connectionId,
    ApiCredentials credentials,
  ) {
    return _secureStorage.saveCredentialsForConnection(
      connectionId: connectionId,
      credentials: credentials,
    );
  }

  Future<void> deleteCredentials(String connectionId) {
    return _secureStorage.deleteCredentialsForConnection(connectionId);
  }

  Future<ConnectionProfile> addConnection({
    required String name,
    required ApiCredentials credentials,
  }) async {
    final now = DateTime.now();
    final connectionId = _newConnectionId();

    final profile = ConnectionProfile(
      id: connectionId,
      name: name,
      baseUrl: credentials.baseUrl,
      createdAt: now,
      lastUsedAt: now,
    );

    final connections = await listConnections();
    await saveConnections([...connections, profile]);
    await saveCredentials(connectionId, credentials);

    return profile;
  }

  Future<void> updateConnection(ConnectionProfile updated) async {
    final connections = await listConnections();
    final next = [
      for (final c in connections)
        if (c.id == updated.id) updated else c,
    ];
    await saveConnections(next);
  }

  Future<void> deleteConnection(String connectionId) async {
    final connections = await listConnections();
    final next = connections.where((c) => c.id != connectionId).toList();
    await saveConnections(next);

    final activeId = await getActiveConnectionId();
    if (activeId == connectionId) {
      await setActiveConnectionId(null);
    }

    await deleteCredentials(connectionId);
  }

  Future<void> touchLastUsed(String connectionId) async {
    final connections = await listConnections();
    final now = DateTime.now();
    final next = [
      for (final c in connections)
        if (c.id == connectionId) c.copyWith(lastUsedAt: now) else c,
    ];
    await saveConnections(next);
  }

  String _newConnectionId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final random = Random().nextInt(1 << 32);
    return '$now-$random';
  }
}
