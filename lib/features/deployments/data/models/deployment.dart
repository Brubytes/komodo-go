import 'package:freezed_annotation/freezed_annotation.dart';
part 'deployment.freezed.dart';
part 'deployment.g.dart';

/// Represents a deployment managed by Komodo.
///
/// This model is designed to parse both:
/// - `ListDeploymentsResponse` (`DeploymentListItem`) which includes `info`
/// - `GetDeploymentResponse` (`Deployment`) which includes `config`
@freezed
sealed class Deployment with _$Deployment {
  const factory Deployment({
    @JsonKey(readValue: _readId) required String id,
    required String name,
    String? description,
    @Default([]) List<String> tags,
    @Default(false) bool template,
    @JsonKey(name: 'config') DeploymentConfig? config,
    @JsonKey(name: 'info') DeploymentListInfo? info,
  }) = _Deployment;

  const Deployment._();

  factory Deployment.fromJson(Map<String, dynamic> json) =>
      _$DeploymentFromJson(json);

  /// Best-effort image display for both list and detail payloads.
  String get imageLabel {
    final infoImage = info?.image;
    if (infoImage != null && infoImage.isNotEmpty) {
      return infoImage;
    }

    final configImage = config?.image;
    if (configImage is String && configImage.isNotEmpty) {
      return configImage;
    }
    if (configImage is Map) {
      // Newer API shape: tagged enum (serde `tag = "type"`), optionally using
      // `content = "params"`.
      final type = configImage['type'];
      if (type == 'Image') {
        final direct = configImage['image'];
        if (direct is String && direct.isNotEmpty) {
          return direct;
        }
        final params = configImage['params'];
        if (params is Map) {
          final nested = params['image'];
          if (nested is String && nested.isNotEmpty) {
            return nested;
          }
        }
      }

      final image = configImage['image'];
      if (image is String && image.isNotEmpty) {
        return image;
      }

      final imageVariant = configImage['Image'];
      if (imageVariant is Map) {
        final variantImage = imageVariant['image'];
        if (variantImage is String && variantImage.isNotEmpty) {
          return variantImage;
        }
      }
    }

    return '';
  }
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

/// List-deployment info (`DeploymentListItemInfo` in `komodo_client`).
@freezed
sealed class DeploymentListInfo with _$DeploymentListInfo {
  const factory DeploymentListInfo({
    @JsonKey(fromJson: _deploymentStateFromJson, toJson: _deploymentStateToJson)
    @Default(DeploymentState.unknown)
    DeploymentState state,
    String? status,
    @Default('') String image,
    @JsonKey(name: 'update_available') @Default(false) bool updateAvailable,
    @JsonKey(name: 'server_id') @Default('') String serverId,
    @JsonKey(name: 'build_id') String? buildId,
  }) = _DeploymentListInfo;

  factory DeploymentListInfo.fromJson(Map<String, dynamic> json) =>
      _$DeploymentListInfoFromJson(json);
}

/// Deployment configuration (`DeploymentConfig` in `komodo_client`).
@freezed
sealed class DeploymentConfig with _$DeploymentConfig {
  const factory DeploymentConfig({
    @JsonKey(name: 'server_id') @Default('') String serverId,
    dynamic image,
    @JsonKey(name: 'image_registry_account')
    @Default('')
    String imageRegistryAccount,
    @JsonKey(name: 'skip_secret_interp') @Default(false) bool skipSecretInterp,
    @JsonKey(name: 'redeploy_on_build') @Default(false) bool redeployOnBuild,
    @JsonKey(name: 'poll_for_updates') @Default(false) bool pollForUpdates,
    @JsonKey(name: 'auto_update') @Default(false) bool autoUpdate,
    @JsonKey(name: 'send_alerts') @Default(false) bool sendAlerts,
    @Default([]) List<String> links,
    @Default('') String network,
    dynamic restart,
    @Default('') String command,
    @JsonKey(name: 'termination_signal') dynamic terminationSignal,
    @JsonKey(name: 'termination_timeout') @Default(0) int terminationTimeout,
    @JsonKey(name: 'extra_args') @Default([]) List<String> extraArgs,
    @JsonKey(name: 'term_signal_labels') @Default('') String termSignalLabels,
    @Default('') String ports,
    @Default('') String volumes,
    @Default('') String environment,
    @Default('') String labels,
  }) = _DeploymentConfig;

  factory DeploymentConfig.fromJson(Map<String, dynamic> json) =>
      _$DeploymentConfigFromJson(json);
}

/// The state of a deployment container.
enum DeploymentState {
  deploying,
  running,
  created,
  restarting,
  removing,
  paused,
  exited,
  dead,
  notDeployed,
  unknown,
}

extension DeploymentStateX on DeploymentState {
  bool get isRunning => this == DeploymentState.running;
  bool get isStopped =>
      this == DeploymentState.created ||
      this == DeploymentState.exited ||
      this == DeploymentState.dead ||
      this == DeploymentState.notDeployed;
  bool get isPaused => this == DeploymentState.paused;

  String get displayName => switch (this) {
    DeploymentState.deploying => 'Deploying',
    DeploymentState.running => 'Running',
    DeploymentState.created => 'Created',
    DeploymentState.restarting => 'Restarting',
    DeploymentState.removing => 'Removing',
    DeploymentState.exited => 'Exited',
    DeploymentState.dead => 'Dead',
    DeploymentState.paused => 'Paused',
    DeploymentState.notDeployed => 'Not Deployed',
    DeploymentState.unknown => 'Unknown',
  };
}

DeploymentState _deploymentStateFromJson(Object? value) {
  if (value is! String) return DeploymentState.unknown;
  final normalized = value.trim().toLowerCase();
  return switch (normalized) {
    'deploying' => DeploymentState.deploying,
    'running' => DeploymentState.running,
    'created' => DeploymentState.created,
    'restarting' => DeploymentState.restarting,
    'removing' => DeploymentState.removing,
    'paused' => DeploymentState.paused,
    'exited' => DeploymentState.exited,
    'dead' => DeploymentState.dead,
    'not_deployed' || 'notdeployed' => DeploymentState.notDeployed,
    'unknown' => DeploymentState.unknown,
    _ => DeploymentState.unknown,
  };
}

String _deploymentStateToJson(DeploymentState value) {
  return switch (value) {
    DeploymentState.notDeployed => 'not_deployed',
    _ => value.name,
  };
}
