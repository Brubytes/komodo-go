import 'package:freezed_annotation/freezed_annotation.dart';

part 'repo.freezed.dart';
part 'repo.g.dart';

/// Repo list item returned by `ListRepos` (`RepoListItem` in `komodo_client`).
@freezed
sealed class RepoListItem with _$RepoListItem {
  const factory RepoListItem({
    required String id,
    required String name,
    required RepoListItemInfo info, @Default(false) bool template,
    @Default([]) List<String> tags,
  }) = _RepoListItem;

  factory RepoListItem.fromJson(Map<String, dynamic> json) =>
      _$RepoListItemFromJson(json);
}

/// Repo info returned by `ListRepos` (`RepoListItemInfo` in `komodo_client`).
@freezed
sealed class RepoListItemInfo with _$RepoListItemInfo {
  const factory RepoListItemInfo({
    @JsonKey(name: 'server_id') @Default('') String serverId,
    @JsonKey(name: 'builder_id') @Default('') String builderId,
    @JsonKey(name: 'git_provider') @Default('') String gitProvider,
    @Default('') String repo,
    @Default('') String branch,
    @JsonKey(name: 'repo_link') @Default('') String repoLink,
    @JsonKey(fromJson: _repoStateFromJson, toJson: _repoStateToJson)
    @Default(RepoState.unknown)
    RepoState state,
    @JsonKey(name: 'last_pulled_at') @Default(0) int lastPulledAt,
    @JsonKey(name: 'last_built_at') @Default(0) int lastBuiltAt,
    @JsonKey(name: 'cloned_hash') String? clonedHash,
    @JsonKey(name: 'cloned_message') String? clonedMessage,
    @JsonKey(name: 'built_hash') String? builtHash,
    @JsonKey(name: 'latest_hash') String? latestHash,
  }) = _RepoListItemInfo;

  factory RepoListItemInfo.fromJson(Map<String, dynamic> json) =>
      _$RepoListItemInfoFromJson(json);
}

/// Repo returned by `GetRepo` (`Repo` in `komodo_client`).
@freezed
sealed class KomodoRepo with _$KomodoRepo {
  const factory KomodoRepo({
    @JsonKey(readValue: _readId) required String id,
    required String name,
    required RepoConfig config, required RepoInfo info, @Default('') String description,
    @Default(false) bool template,
    @Default([]) List<String> tags,
  }) = _KomodoRepo;

  factory KomodoRepo.fromJson(Map<String, dynamic> json) =>
      _$KomodoRepoFromJson(json);
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

/// Repo configuration (`RepoConfig` in `komodo_client`).
@freezed
sealed class RepoConfig with _$RepoConfig {
  const factory RepoConfig({
    @JsonKey(name: 'server_id') @Default('') String serverId,
    @JsonKey(name: 'builder_id') @Default('') String builderId,
    @JsonKey(name: 'git_provider') @Default('') String gitProvider,
    @JsonKey(name: 'git_https') @Default(false) bool gitHttps,
    @JsonKey(name: 'git_account') @Default('') String gitAccount,
    @Default('') String repo,
    @Default('') String branch,
    @Default('') String commit,
    @Default('') String path,
    @JsonKey(name: 'webhook_enabled') @Default(false) bool webhookEnabled,
    @JsonKey(name: 'skip_secret_interp') @Default(false) bool skipSecretInterp,
  }) = _RepoConfig;

  factory RepoConfig.fromJson(Map<String, dynamic> json) =>
      _$RepoConfigFromJson(json);
}

/// Repo info returned by `GetRepo` (`RepoInfo` in `komodo_client`).
@freezed
sealed class RepoInfo with _$RepoInfo {
  const factory RepoInfo({
    @JsonKey(name: 'last_pulled_at') @Default(0) int lastPulledAt,
    @JsonKey(name: 'last_built_at') @Default(0) int lastBuiltAt,
    @JsonKey(name: 'built_hash') String? builtHash,
    @JsonKey(name: 'built_message') String? builtMessage,
    @JsonKey(name: 'latest_hash') String? latestHash,
    @JsonKey(name: 'latest_message') String? latestMessage,
  }) = _RepoInfo;

  factory RepoInfo.fromJson(Map<String, dynamic> json) => _$RepoInfoFromJson(json);
}

/// The state of a repo.
enum RepoState { unknown, ok, failed, cloning, pulling, building }

RepoState _repoStateFromJson(Object? value) {
  if (value is! String) return RepoState.unknown;
  final normalized = value.trim().toLowerCase().replaceAll('_', '');
  return switch (normalized) {
    'ok' => RepoState.ok,
    'failed' => RepoState.failed,
    'cloning' => RepoState.cloning,
    'pulling' => RepoState.pulling,
    'building' => RepoState.building,
    'unknown' => RepoState.unknown,
    _ => RepoState.unknown,
  };
}

String _repoStateToJson(RepoState value) {
  return switch (value) {
    RepoState.ok => 'Ok',
    RepoState.failed => 'Failed',
    RepoState.cloning => 'Cloning',
    RepoState.pulling => 'Pulling',
    RepoState.building => 'Building',
    RepoState.unknown => 'Unknown',
  };
}

extension RepoStateX on RepoState {
  bool get isBusy =>
      this == RepoState.cloning || this == RepoState.pulling || this == RepoState.building;

  String get displayName {
    return switch (this) {
      RepoState.ok => 'Ok',
      RepoState.failed => 'Failed',
      RepoState.cloning => 'Cloning',
      RepoState.pulling => 'Pulling',
      RepoState.building => 'Building',
      RepoState.unknown => 'Unknown',
    };
  }
}

