import 'package:freezed_annotation/freezed_annotation.dart';

part 'server.freezed.dart';
part 'server.g.dart';

/// Represents a server managed by Komodo.
@freezed
sealed class Server with _$Server {
  const factory Server({
    @JsonKey(readValue: _readId) required String id,
    required String name,
    String? description,
    @Default([]) List<String> tags,
    @Default(false) bool template,
    ServerInfo? info,
    ServerConfig? config,
  }) = _Server;

  const Server._();

  factory Server.fromJson(Map<String, dynamic> json) => _$ServerFromJson(json);

  /// Gets the server address from either info or config.
  String get address => info?.address ?? config?.address ?? '';

  /// Gets the server state from info.
  ServerState get state => info?.state ?? ServerState.unknown;
}

/// Reads the id from either 'id' or '_id.$oid' format.
Object? _readId(Map<dynamic, dynamic> json, String key) {
  if (json.containsKey('id')) {
    return json['id'];
  }
  if (json.containsKey('_id')) {
    final id = json['_id'];
    if (id is Map && id.containsKey(r'$oid')) {
      return id[r'$oid'];
    }
    return id;
  }
  return null;
}

/// Server configuration (from detail endpoint).
@freezed
sealed class ServerConfig with _$ServerConfig {
  const factory ServerConfig({
    @Default('') String address,
    @JsonKey(name: 'external_address') @Default('') String externalAddress,
    @Default('') String region,
    @Default(true) bool enabled,
  }) = _ServerConfig;

  factory ServerConfig.fromJson(Map<String, dynamic> json) =>
      _$ServerConfigFromJson(json);
}

/// Server information from the API (from list endpoint).
@freezed
sealed class ServerInfo with _$ServerInfo {
  const factory ServerInfo({
    @JsonKey(fromJson: _serverStateFromJson, toJson: _serverStateToJson)
    @Default(ServerState.unknown)
    ServerState state,
    @Default('') String region,
    @Default('') String address,
    @JsonKey(name: 'external_address') @Default('') String externalAddress,
    @Default('') String version,
    @JsonKey(name: 'send_unreachable_alerts')
    @Default(true)
    bool sendUnreachableAlerts,
    @JsonKey(name: 'send_cpu_alerts') @Default(true) bool sendCpuAlerts,
    @JsonKey(name: 'send_mem_alerts') @Default(true) bool sendMemAlerts,
    @JsonKey(name: 'send_disk_alerts') @Default(true) bool sendDiskAlerts,
    @JsonKey(name: 'send_version_mismatch_alerts')
    @Default(true)
    bool sendVersionMismatchAlerts,
    @JsonKey(name: 'terminals_disabled') @Default(false) bool terminalsDisabled,
    @JsonKey(name: 'container_exec_disabled')
    @Default(false)
    bool containerExecDisabled,
  }) = _ServerInfo;

  factory ServerInfo.fromJson(Map<String, dynamic> json) =>
      _$ServerInfoFromJson(json);
}

/// The state of a server.
enum ServerState { ok, notOk, disabled, unknown }

ServerState _serverStateFromJson(Object? value) {
  if (value is! String) return ServerState.unknown;
  final normalized = value.trim().toLowerCase().replaceAll('_', '');
  return switch (normalized) {
    'ok' => ServerState.ok,
    'notok' => ServerState.notOk,
    'disabled' => ServerState.disabled,
    _ => ServerState.unknown,
  };
}

String _serverStateToJson(ServerState value) {
  return switch (value) {
    ServerState.ok => 'Ok',
    ServerState.notOk => 'NotOk',
    ServerState.disabled => 'Disabled',
    ServerState.unknown => 'Unknown',
  };
}
