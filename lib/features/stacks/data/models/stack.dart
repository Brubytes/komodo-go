import 'package:freezed_annotation/freezed_annotation.dart';

part 'stack.freezed.dart';
part 'stack.g.dart';

/// Stack list item returned by `ListStacks` (`StackListItem` in `komodo_client`).
@freezed
sealed class StackListItem with _$StackListItem {
  const factory StackListItem({
    required String id,
    required String name,
    required StackListItemInfo info,
    @Default(false) bool template,
    @Default([]) List<String> tags,
  }) = _StackListItem;

  factory StackListItem.fromJson(Map<String, dynamic> json) =>
      _$StackListItemFromJson(json);
}

/// Stack info returned by `ListStacks` (`StackListItemInfo` in `komodo_client`).
@freezed
sealed class StackListItemInfo with _$StackListItemInfo {
  const factory StackListItemInfo({
    @JsonKey(name: 'server_id') @Default('') String serverId,
    @JsonKey(fromJson: _stackStateFromJson, toJson: _stackStateToJson)
    @Default(StackState.unknown)
    StackState state,
    String? status,
    @Default('') String repo,
    @Default('') String branch,
    @Default('') String linkedRepo,
    @JsonKey(name: 'project_missing') @Default(false) bool projectMissing,
  }) = _StackListItemInfo;

  factory StackListItemInfo.fromJson(Map<String, dynamic> json) =>
      _$StackListItemInfoFromJson(json);
}

/// Stack returned by `GetStack` (`Stack` in `komodo_client`).
@freezed
sealed class KomodoStack with _$KomodoStack {
  const factory KomodoStack({
    @JsonKey(readValue: _readId) required String id,
    required String name,
    required StackConfig config,
    required StackInfo info,
    @Default('') String description,
    @Default(false) bool template,
    @Default([]) List<String> tags,
  }) = _KomodoStack;

  factory KomodoStack.fromJson(Map<String, dynamic> json) =>
      _$KomodoStackFromJson(json);
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

/// Stack configuration (`StackConfig` in `komodo_client`).
@freezed
sealed class StackConfig with _$StackConfig {
  const factory StackConfig({
    @JsonKey(name: 'server_id') @Default('') String serverId,
    @Default([]) List<String> links,
    @JsonKey(name: 'project_name') @Default('') String projectName,
    @JsonKey(name: 'linked_repo') @Default('') String linkedRepo,
    @Default('') String repo,
    @Default('') String branch,
    @Default('') String commit,
    @JsonKey(name: 'clone_path') @Default('') String clonePath,
    @JsonKey(name: 'run_directory') @Default('') String runDirectory,
    @JsonKey(name: 'auto_pull') @Default(false) bool autoPull,
    @JsonKey(name: 'auto_update') @Default(false) bool autoUpdate,
    @JsonKey(name: 'poll_for_updates') @Default(false) bool pollForUpdates,
    @JsonKey(name: 'send_alerts') @Default(false) bool sendAlerts,
    @JsonKey(name: 'file_paths') @Default([]) List<String> filePaths,
    @JsonKey(name: 'env_file_path') @Default('') String envFilePath,
    @JsonKey(name: 'additional_env_files')
    @Default([])
    List<String> additionalEnvFiles,
    @JsonKey(name: 'ignore_services') @Default([]) List<String> ignoreServices,
    @JsonKey(name: 'file_contents') @Default('') String fileContents,
    @Default('') String environment,
  }) = _StackConfig;

  factory StackConfig.fromJson(Map<String, dynamic> json) =>
      _$StackConfigFromJson(json);
}

/// Stack info returned by `GetStack` (`StackInfo` in `komodo_client`).
@freezed
sealed class StackInfo with _$StackInfo {
  const factory StackInfo({
    @JsonKey(name: 'missing_files') @Default([]) List<String> missingFiles,
    @JsonKey(name: 'deployed_hash') String? deployedHash,
    @JsonKey(name: 'latest_hash') String? latestHash,
    @JsonKey(name: 'latest_message') String? latestMessage,
    @JsonKey(name: 'deployed_message') String? deployedMessage,
  }) = _StackInfo;

  factory StackInfo.fromJson(Map<String, dynamic> json) =>
      _$StackInfoFromJson(json);
}

/// Container summary nested inside `StackService` (`ContainerListItem` in `komodo_client`).
@freezed
sealed class StackContainerListItem with _$StackContainerListItem {
  const factory StackContainerListItem({
    required String name,
    @Default('') String state,
    String? status,
    String? image,
    String? id,
  }) = _StackContainerListItem;

  factory StackContainerListItem.fromJson(Map<String, dynamic> json) =>
      _$StackContainerListItemFromJson(json);
}

/// Service info returned by `ListStackServices` (`StackService` in `komodo_client`).
@freezed
sealed class StackService with _$StackService {
  const factory StackService({
    required String service,
    @Default('') String image,
    @JsonKey(name: 'update_available') @Default(false) bool updateAvailable,
    StackContainerListItem? container,
  }) = _StackService;

  factory StackService.fromJson(Map<String, dynamic> json) =>
      _$StackServiceFromJson(json);
}

/// Log entry returned by `GetStackLog` (`Log` in `komodo_client`).
@freezed
sealed class StackLog with _$StackLog {
  const factory StackLog({
    @Default('') String stage,
    @Default('') String command,
    @Default('') String stdout,
    @Default('') String stderr,
    @Default(false) bool success,
    @JsonKey(name: 'start_ts') @Default(0) int startTs,
    @JsonKey(name: 'end_ts') @Default(0) int endTs,
  }) = _StackLog;

  factory StackLog.fromJson(Map<String, dynamic> json) =>
      _$StackLogFromJson(json);
}

/// The state of a stack.
enum StackState {
  deploying,
  running,
  paused,
  stopped,
  created,
  restarting,
  dead,
  removing,
  unhealthy,
  down,
  unknown,
}

StackState _stackStateFromJson(Object? value) {
  if (value is! String) return StackState.unknown;
  final normalized = value.trim().toLowerCase().replaceAll('_', '');
  return switch (normalized) {
    'deploying' => StackState.deploying,
    'running' => StackState.running,
    'paused' => StackState.paused,
    'stopped' => StackState.stopped,
    'created' => StackState.created,
    'restarting' => StackState.restarting,
    'dead' => StackState.dead,
    'removing' => StackState.removing,
    'unhealthy' => StackState.unhealthy,
    'down' => StackState.down,
    _ => StackState.unknown,
  };
}

String _stackStateToJson(StackState value) {
  return switch (value) {
    StackState.deploying => 'Deploying',
    StackState.running => 'Running',
    StackState.paused => 'Paused',
    StackState.stopped => 'Stopped',
    StackState.created => 'Created',
    StackState.restarting => 'Restarting',
    StackState.dead => 'Dead',
    StackState.removing => 'Removing',
    StackState.unhealthy => 'Unhealthy',
    StackState.down => 'Down',
    StackState.unknown => 'Unknown',
  };
}

extension StackStateX on StackState {
  bool get isRunning => this == StackState.running;
  bool get isStopped =>
      this == StackState.stopped ||
      this == StackState.created ||
      this == StackState.down ||
      this == StackState.dead;

  String get displayName {
    return switch (this) {
      StackState.deploying => 'Deploying',
      StackState.running => 'Running',
      StackState.paused => 'Paused',
      StackState.stopped => 'Stopped',
      StackState.created => 'Created',
      StackState.restarting => 'Restarting',
      StackState.dead => 'Dead',
      StackState.removing => 'Removing',
      StackState.unhealthy => 'Unhealthy',
      StackState.down => 'Down',
      StackState.unknown => 'Unknown',
    };
  }
}
