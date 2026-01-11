import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync.freezed.dart';
part 'sync.g.dart';

/// Resource sync list item returned by `ListResourceSyncs` (`ResourceSyncListItem` in `komodo_client`).
@freezed
sealed class ResourceSyncListItem with _$ResourceSyncListItem {
  const factory ResourceSyncListItem({
    required String id,
    required String name,
    required ResourceSyncListItemInfo info, @Default(false) bool template,
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
    required ResourceSyncConfig config, required ResourceSyncInfo info, @Default('') String description,
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
  }) = _ResourceSyncInfo;

  factory ResourceSyncInfo.fromJson(Map<String, dynamic> json) =>
      _$ResourceSyncInfoFromJson(json);
}

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
