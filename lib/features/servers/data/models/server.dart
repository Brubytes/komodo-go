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
    @JsonKey(name: 'timeout_seconds') @Default(0) int timeoutSeconds,

    /// Server passkey (sensitive) - do not display in UI.
    @Default('') String passkey,
    @JsonKey(name: 'ignore_mounts') @Default([]) List<String> ignoreMounts,
    @JsonKey(name: 'stats_monitoring') @Default(true) bool statsMonitoring,
    @JsonKey(name: 'auto_prune') @Default(false) bool autoPrune,
    @Default([]) List<String> links,
    @JsonKey(name: 'send_unreachable_alerts')
    @Default(true)
    bool sendUnreachableAlerts,
    @JsonKey(name: 'send_cpu_alerts') @Default(true) bool sendCpuAlerts,
    @JsonKey(name: 'send_mem_alerts') @Default(true) bool sendMemAlerts,
    @JsonKey(name: 'send_disk_alerts') @Default(true) bool sendDiskAlerts,
    @JsonKey(name: 'send_version_mismatch_alerts')
    @Default(true)
    bool sendVersionMismatchAlerts,
    @JsonKey(name: 'cpu_warning') @Default(0) double cpuWarning,
    @JsonKey(name: 'cpu_critical') @Default(0) double cpuCritical,
    @JsonKey(name: 'mem_warning') @Default(0) double memWarning,
    @JsonKey(name: 'mem_critical') @Default(0) double memCritical,
    @JsonKey(name: 'disk_warning') @Default(0) double diskWarning,
    @JsonKey(name: 'disk_critical') @Default(0) double diskCritical,
    @JsonKey(name: 'maintenance_windows')
    @Default([])
    List<MaintenanceWindow> maintenanceWindows,
  }) = _ServerConfig;

  factory ServerConfig.fromJson(Map<String, dynamic> json) =>
      _$ServerConfigFromJson(json);
}

@freezed
sealed class MaintenanceWindow with _$MaintenanceWindow {
  const factory MaintenanceWindow({
    @Default('') String name,
    @Default('') String description,
    @JsonKey(
      name: 'schedule_type',
      fromJson: _maintenanceScheduleTypeFromJson,
      toJson: _maintenanceScheduleTypeToJson,
    )
    @Default(MaintenanceScheduleType.daily)
    MaintenanceScheduleType scheduleType,
    @JsonKey(name: 'day_of_week') @Default('') String dayOfWeek,
    @Default('') String date,
    @Default(0) int hour,
    @Default(0) int minute,
    @JsonKey(name: 'duration_minutes') @Default(0) int durationMinutes,
    @Default('') String timezone,
    @Default(false) bool enabled,
  }) = _MaintenanceWindow;

  factory MaintenanceWindow.fromJson(Map<String, dynamic> json) =>
      _$MaintenanceWindowFromJson(json);
}

enum MaintenanceScheduleType { daily, weekly, oneTime }

MaintenanceScheduleType _maintenanceScheduleTypeFromJson(Object? value) {
  if (value is! String) return MaintenanceScheduleType.daily;
  final normalized = value.trim().toLowerCase().replaceAll('_', '');
  return switch (normalized) {
    'daily' => MaintenanceScheduleType.daily,
    'weekly' => MaintenanceScheduleType.weekly,
    'onetime' => MaintenanceScheduleType.oneTime,
    _ => MaintenanceScheduleType.daily,
  };
}

String _maintenanceScheduleTypeToJson(MaintenanceScheduleType value) {
  return switch (value) {
    MaintenanceScheduleType.daily => 'Daily',
    MaintenanceScheduleType.weekly => 'Weekly',
    MaintenanceScheduleType.oneTime => 'OneTime',
  };
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
