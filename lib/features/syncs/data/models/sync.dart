import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync.freezed.dart';
part 'sync.g.dart';

/// Resource sync list item returned by `ListResourceSyncs` (`ResourceSyncListItem` in `komodo_client`).
@freezed
sealed class ResourceSyncListItem with _$ResourceSyncListItem {
  const factory ResourceSyncListItem({
    required String id,
    required String name,
    required ResourceSyncListItemInfo info,
    @Default(false) bool template,
    @Default([]) List<String> tags,
  }) = _ResourceSyncListItem;

  factory ResourceSyncListItem.fromJson(Map<String, dynamic> json) =>
      _$ResourceSyncListItemFromJson(json);
}

/// Resource sync info returned by `ListResourceSyncs` (`ResourceSyncListItemInfo` in `komodo_client`).
@freezed
sealed class ResourceSyncListItemInfo with _$ResourceSyncListItemInfo {
  const factory ResourceSyncListItemInfo({
    @JsonKey(name: 'last_sync_ts') @Default(0) int lastSyncTs,
    @JsonKey(name: 'files_on_host') @Default(false) bool filesOnHost,
    @JsonKey(name: 'file_contents') @Default(false) bool fileContents,
    @Default(false) bool managed,
    @JsonKey(name: 'resource_path') @Default([]) List<String> resourcePath,
    @JsonKey(name: 'linked_repo') @Default('') String linkedRepo,
    @JsonKey(name: 'git_provider') @Default('') String gitProvider,
    @Default('') String repo,
    @Default('') String branch,
    @JsonKey(name: 'repo_link') @Default('') String repoLink,
    @JsonKey(name: 'last_sync_hash') String? lastSyncHash,
    @JsonKey(name: 'last_sync_message') String? lastSyncMessage,
    @JsonKey(
      fromJson: _resourceSyncStateFromJson,
      toJson: _resourceSyncStateToJson,
    )
    @Default(ResourceSyncState.unknown)
    ResourceSyncState state,
  }) = _ResourceSyncListItemInfo;

  factory ResourceSyncListItemInfo.fromJson(Map<String, dynamic> json) =>
      _$ResourceSyncListItemInfoFromJson(json);
}

/// Resource sync returned by `GetResourceSync` (`ResourceSync` in `komodo_client`).
@freezed
sealed class KomodoResourceSync with _$KomodoResourceSync {
  const factory KomodoResourceSync({
    @JsonKey(readValue: _readId) required String id,
    required String name,
    required ResourceSyncConfig config,
    required ResourceSyncInfo info,
    @Default('') String description,
    @Default(false) bool template,
    @Default([]) List<String> tags,
  }) = _KomodoResourceSync;

  factory KomodoResourceSync.fromJson(Map<String, dynamic> json) =>
      _$KomodoResourceSyncFromJson(json);
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

/// Resource sync configuration (`ResourceSyncConfig` in `komodo_client`).
@freezed
sealed class ResourceSyncConfig with _$ResourceSyncConfig {
  const factory ResourceSyncConfig({
    @JsonKey(name: 'linked_repo') @Default('') String linkedRepo,
    @JsonKey(name: 'git_provider') @Default('') String gitProvider,
    @JsonKey(name: 'git_https') @Default(false) bool gitHttps,
    @Default('') String repo,
    @Default('') String branch,
    @Default('') String commit,
    @JsonKey(name: 'git_account') @Default('') String gitAccount,
    @JsonKey(name: 'webhook_enabled') @Default(false) bool webhookEnabled,
    @JsonKey(name: 'webhook_secret') @Default('') String webhookSecret,
    @JsonKey(name: 'files_on_host') @Default(false) bool filesOnHost,
    @JsonKey(name: 'resource_path') @Default([]) List<String> resourcePath,
    @Default(false) bool managed,
    @Default(false) bool delete,
    @JsonKey(name: 'include_resources') @Default(false) bool includeResources,
    @JsonKey(name: 'match_tags') @Default([]) List<String> matchTags,
    @JsonKey(name: 'include_variables') @Default(false) bool includeVariables,
    @JsonKey(name: 'include_user_groups')
    @Default(false)
    bool includeUserGroups,
    @JsonKey(name: 'pending_alert') @Default(false) bool pendingAlert,
    @JsonKey(name: 'file_contents') @Default('') String fileContents,
  }) = _ResourceSyncConfig;

  factory ResourceSyncConfig.fromJson(Map<String, dynamic> json) =>
      _$ResourceSyncConfigFromJson(json);
}

/// Resource sync info returned by `GetResourceSync` (`ResourceSyncInfo` in `komodo_client`).
@freezed
sealed class ResourceSyncInfo with _$ResourceSyncInfo {
  const factory ResourceSyncInfo({
    @JsonKey(name: 'last_sync_ts') @Default(0) int lastSyncTs,
    @JsonKey(name: 'last_sync_hash') String? lastSyncHash,
    @JsonKey(name: 'last_sync_message') String? lastSyncMessage,
    @JsonKey(name: 'pending_error') String? pendingError,
    @JsonKey(name: 'pending_hash') String? pendingHash,
    @JsonKey(name: 'pending_message') String? pendingMessage,
    @JsonKey(
      name: 'resource_updates',
      fromJson: _resourceDiffsFromJson,
      toJson: _resourceDiffsToJson,
    )
    @Default([])
    List<ResourceSyncDiff> resourceUpdates,
    @JsonKey(
      name: 'variable_updates',
      fromJson: _diffDataListFromJson,
      toJson: _diffDataListToJson,
    )
    @Default([])
    List<SyncDiffData> variableUpdates,
    @JsonKey(
      name: 'user_group_updates',
      fromJson: _diffDataListFromJson,
      toJson: _diffDataListToJson,
    )
    @Default([])
    List<SyncDiffData> userGroupUpdates,
    @JsonKey(name: 'pending_deploy_error') String? pendingDeployError,
    @JsonKey(
      name: 'pending_deploys',
      fromJson: _pendingDeploysFromJson,
      toJson: _pendingDeploysToJson,
    )
    @Default([])
    List<SyncPendingDeploy> pendingDeploys,
    @JsonKey(
      name: 'remote_contents',
      fromJson: _syncFilesFromJson,
      toJson: _syncFilesToJson,
    )
    @Default([])
    List<SyncFileContents> remoteContents,
    @JsonKey(
      name: 'remote_errors',
      fromJson: _syncFilesFromJson,
      toJson: _syncFilesToJson,
    )
    @Default([])
    List<SyncFileContents> remoteErrors,
  }) = _ResourceSyncInfo;

  factory ResourceSyncInfo.fromJson(Map<String, dynamic> json) =>
      _$ResourceSyncInfoFromJson(json);
}

class SyncResourceTarget {
  const SyncResourceTarget({required this.type, required this.id});

  factory SyncResourceTarget.fromJson(Object? json) {
    if (json is! Map) {
      return const SyncResourceTarget(type: 'Resource', id: '');
    }
    if (json['type'] is String) {
      return SyncResourceTarget(
        type: json['type'] as String,
        id: json['id']?.toString() ?? '',
      );
    }
    if (json.length == 1) {
      final entry = json.entries.first;
      return SyncResourceTarget(
        type: entry.key.toString(),
        id: entry.value?.toString() ?? '',
      );
    }
    return const SyncResourceTarget(type: 'Resource', id: '');
  }

  final String type;
  final String id;

  Map<String, dynamic> toJson() => <String, dynamic>{'type': type, 'id': id};
}

enum SyncDiffOperation { create, update, delete, unknown }

class SyncDiffData {
  const SyncDiffData({
    required this.operation,
    this.name = '',
    this.proposed = '',
    this.current = '',
  });

  factory SyncDiffData.fromJson(Object? json) {
    if (json is! Map) {
      return const SyncDiffData(operation: SyncDiffOperation.unknown);
    }
    final type = json['type']?.toString().toLowerCase();
    final rawData = json['data'];
    final data = rawData is Map ? rawData : json;
    return SyncDiffData(
      operation: switch (type) {
        'create' => SyncDiffOperation.create,
        'update' => SyncDiffOperation.update,
        'delete' => SyncDiffOperation.delete,
        _ => SyncDiffOperation.unknown,
      },
      name: data['name']?.toString() ?? '',
      proposed: data['proposed']?.toString() ?? '',
      current: data['current']?.toString() ?? '',
    );
  }

  final SyncDiffOperation operation;
  final String name;
  final String proposed;
  final String current;

  String get label => switch (operation) {
    SyncDiffOperation.create => 'Create',
    SyncDiffOperation.update => 'Update',
    SyncDiffOperation.delete => 'Delete',
    SyncDiffOperation.unknown => 'Change',
  };

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': label,
    'data': <String, dynamic>{
      if (name.isNotEmpty) 'name': name,
      if (proposed.isNotEmpty) 'proposed': proposed,
      if (current.isNotEmpty) 'current': current,
    },
  };
}

class ResourceSyncDiff {
  const ResourceSyncDiff({required this.target, required this.data});

  factory ResourceSyncDiff.fromJson(Object? json) {
    final map = json is Map ? json : const <String, dynamic>{};
    return ResourceSyncDiff(
      target: SyncResourceTarget.fromJson(map['target']),
      data: SyncDiffData.fromJson(map['data']),
    );
  }

  final SyncResourceTarget target;
  final SyncDiffData data;

  String get name => data.name.isNotEmpty ? data.name : target.id;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'target': target.toJson(),
    'data': data.toJson(),
  };
}

class SyncPendingDeploy {
  const SyncPendingDeploy({
    required this.target,
    required this.reason,
    this.after = const [],
  });

  factory SyncPendingDeploy.fromJson(Object? json) {
    final map = json is Map ? json : const <String, dynamic>{};
    final rawAfter = map['after'];
    return SyncPendingDeploy(
      target: SyncResourceTarget.fromJson(map['target']),
      reason: map['reason']?.toString() ?? '',
      after: rawAfter is List
          ? rawAfter.map(SyncResourceTarget.fromJson).toList()
          : const [],
    );
  }

  final SyncResourceTarget target;
  final String reason;
  final List<SyncResourceTarget> after;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'target': target.toJson(),
    'reason': reason,
    'after': after.map((item) => item.toJson()).toList(),
  };
}

class SyncFileContents {
  const SyncFileContents({
    required this.resourcePath,
    required this.path,
    required this.contents,
  });

  factory SyncFileContents.fromJson(Object? json) {
    final map = json is Map ? json : const <String, dynamic>{};
    return SyncFileContents(
      resourcePath: map['resource_path']?.toString() ?? '',
      path: map['path']?.toString() ?? '',
      contents: map['contents']?.toString() ?? '',
    );
  }

  final String resourcePath;
  final String path;
  final String contents;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'resource_path': resourcePath,
    'path': path,
    'contents': contents,
  };
}

List<ResourceSyncDiff> _resourceDiffsFromJson(Object? json) =>
    json is List ? json.map(ResourceSyncDiff.fromJson).toList() : const [];

List<Map<String, dynamic>> _resourceDiffsToJson(List<ResourceSyncDiff> value) =>
    value.map((item) => item.toJson()).toList();

List<SyncDiffData> _diffDataListFromJson(Object? json) =>
    json is List ? json.map(SyncDiffData.fromJson).toList() : const [];

List<Map<String, dynamic>> _diffDataListToJson(List<SyncDiffData> value) =>
    value.map((item) => item.toJson()).toList();

List<SyncPendingDeploy> _pendingDeploysFromJson(Object? json) =>
    json is List ? json.map(SyncPendingDeploy.fromJson).toList() : const [];

List<Map<String, dynamic>> _pendingDeploysToJson(
  List<SyncPendingDeploy> value,
) => value.map((item) => item.toJson()).toList();

List<SyncFileContents> _syncFilesFromJson(Object? json) =>
    json is List ? json.map(SyncFileContents.fromJson).toList() : const [];

List<Map<String, dynamic>> _syncFilesToJson(List<SyncFileContents> value) =>
    value.map((item) => item.toJson()).toList();

enum ResourceSyncState { syncing, pending, ok, failed, unknown }

ResourceSyncState _resourceSyncStateFromJson(Object? value) {
  if (value is! String) return ResourceSyncState.unknown;
  final normalized = value.trim().toLowerCase().replaceAll('_', '');
  return switch (normalized) {
    'syncing' => ResourceSyncState.syncing,
    'pending' => ResourceSyncState.pending,
    'ok' => ResourceSyncState.ok,
    'failed' => ResourceSyncState.failed,
    _ => ResourceSyncState.unknown,
  };
}

String _resourceSyncStateToJson(ResourceSyncState value) {
  return switch (value) {
    ResourceSyncState.syncing => 'Syncing',
    ResourceSyncState.pending => 'Pending',
    ResourceSyncState.ok => 'Ok',
    ResourceSyncState.failed => 'Failed',
    ResourceSyncState.unknown => 'Unknown',
  };
}

extension ResourceSyncStateX on ResourceSyncState {
  bool get isRunning =>
      this == ResourceSyncState.syncing || this == ResourceSyncState.pending;

  String get displayName {
    return switch (this) {
      ResourceSyncState.syncing => 'Syncing',
      ResourceSyncState.pending => 'Pending',
      ResourceSyncState.ok => 'Ok',
      ResourceSyncState.failed => 'Failed',
      ResourceSyncState.unknown => 'Unknown',
    };
  }
}
