import 'package:freezed_annotation/freezed_annotation.dart';

part 'build.freezed.dart';
part 'build.g.dart';

/// Build list item returned by `ListBuilds` (`BuildListItem` in `komodo_client`).
@freezed
sealed class BuildListItem with _$BuildListItem {
  const factory BuildListItem({
    required String id,
    required String name,
    @Default(false) bool template,
    @Default([]) List<String> tags,
    required BuildListItemInfo info,
  }) = _BuildListItem;

  factory BuildListItem.fromJson(Map<String, dynamic> json) =>
      _$BuildListItemFromJson(json);
}

/// Build info returned by `ListBuilds` (`BuildListItemInfo` in `komodo_client`).
@freezed
sealed class BuildListItemInfo with _$BuildListItemInfo {
  const factory BuildListItemInfo({
    @JsonKey(fromJson: _buildStateFromJson, toJson: _buildStateToJson)
    @Default(BuildState.unknown)
    BuildState state,
    @JsonKey(name: 'last_built_at') @Default(0) int lastBuiltAt,
    @Default(BuildVersion()) BuildVersion version,
    @JsonKey(name: 'builder_id') @Default('') String builderId,
    @Default('') String linkedRepo,
    @Default('') String repo,
    @Default('') String branch,
    @JsonKey(name: 'repo_link') @Default('') String repoLink,
    @JsonKey(name: 'built_hash') String? builtHash,
    @JsonKey(name: 'latest_hash') String? latestHash,
    @JsonKey(name: 'image_registry_domain') String? imageRegistryDomain,
  }) = _BuildListItemInfo;

  factory BuildListItemInfo.fromJson(Map<String, dynamic> json) =>
      _$BuildListItemInfoFromJson(json);
}

/// Build returned by `GetBuild` (`Build` in `komodo_client`).
@freezed
sealed class KomodoBuild with _$KomodoBuild {
  const factory KomodoBuild({
    @JsonKey(readValue: _readId) required String id,
    required String name,
    @Default('') String description,
    @Default(false) bool template,
    @Default([]) List<String> tags,
    required BuildConfig config,
    required BuildInfo info,
  }) = _KomodoBuild;

  factory KomodoBuild.fromJson(Map<String, dynamic> json) =>
      _$KomodoBuildFromJson(json);
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

/// Semantic version used by build resources (`Version` in `komodo_client`).
@freezed
sealed class BuildVersion with _$BuildVersion {
  const factory BuildVersion({
    @Default(0) int major,
    @Default(0) int minor,
    @Default(0) int patch,
  }) = _BuildVersion;

  factory BuildVersion.fromJson(Map<String, dynamic> json) =>
      _$BuildVersionFromJson(json);
}

/// Build configuration (`BuildConfig` in `komodo_client`).
@freezed
sealed class BuildConfig with _$BuildConfig {
  const factory BuildConfig({
    @JsonKey(name: 'builder_id') @Default('') String builderId,
    @Default(BuildVersion()) BuildVersion version,
    @JsonKey(name: 'auto_increment_version')
    @Default(false)
    bool autoIncrementVersion,
    @JsonKey(name: 'image_name') @Default('') String imageName,
    @JsonKey(name: 'image_tag') @Default('') String imageTag,
    @Default('') String linkedRepo,
    @Default('') String repo,
    @Default('') String branch,
    @Default('') String commit,
    @JsonKey(name: 'webhook_enabled') @Default(false) bool webhookEnabled,
    @JsonKey(name: 'files_on_host') @Default(false) bool filesOnHost,
    @JsonKey(name: 'build_path') @Default('') String buildPath,
    @JsonKey(name: 'dockerfile_path') @Default('') String dockerfilePath,
    @JsonKey(name: 'skip_secret_interp') @Default(false) bool skipSecretInterp,
    @JsonKey(name: 'use_buildx') @Default(false) bool useBuildx,
    @Default([]) List<String> extraArgs,
  }) = _BuildConfig;

  factory BuildConfig.fromJson(Map<String, dynamic> json) =>
      _$BuildConfigFromJson(json);
}

/// Build info returned by `GetBuild` (`BuildInfo` in `komodo_client`).
@freezed
sealed class BuildInfo with _$BuildInfo {
  const factory BuildInfo({
    @JsonKey(name: 'last_built_at') @Default(0) int lastBuiltAt,
    @JsonKey(name: 'built_hash') String? builtHash,
    @JsonKey(name: 'built_message') String? builtMessage,
    @JsonKey(name: 'built_contents') String? builtContents,
    @JsonKey(name: 'remote_path') String? remotePath,
    @JsonKey(name: 'remote_contents') String? remoteContents,
    @JsonKey(name: 'remote_error') String? remoteError,
    @JsonKey(name: 'latest_hash') String? latestHash,
    @JsonKey(name: 'latest_message') String? latestMessage,
  }) = _BuildInfo;

  factory BuildInfo.fromJson(Map<String, dynamic> json) =>
      _$BuildInfoFromJson(json);
}

/// The state of a build.
enum BuildState { building, ok, failed, unknown }

BuildState _buildStateFromJson(Object? value) {
  if (value is! String) return BuildState.unknown;
  final normalized = value.trim().toLowerCase().replaceAll('_', '');
  return switch (normalized) {
    'building' => BuildState.building,
    'ok' => BuildState.ok,
    'failed' => BuildState.failed,
    _ => BuildState.unknown,
  };
}

String _buildStateToJson(BuildState value) {
  return switch (value) {
    BuildState.building => 'Building',
    BuildState.ok => 'Ok',
    BuildState.failed => 'Failed',
    BuildState.unknown => 'Unknown',
  };
}

extension BuildStateX on BuildState {
  bool get isRunning => this == BuildState.building;

  String get displayName {
    return switch (this) {
      BuildState.building => 'Building',
      BuildState.ok => 'Ok',
      BuildState.failed => 'Failed',
      BuildState.unknown => 'Unknown',
    };
  }
}

extension BuildVersionX on BuildVersion {
  String get label => '$major.$minor.$patch';
}

