import 'package:freezed_annotation/freezed_annotation.dart';

part 'deployment.freezed.dart';
part 'deployment.g.dart';

/// Represents a deployment managed by Komodo.
@freezed
sealed class Deployment with _$Deployment {
  const factory Deployment({
    required String id,
    required String name,
    String? description,
    @Default([]) List<String> tags,
    required DeploymentConfig config,
    @JsonKey(name: 'info') DeploymentInfo? info,
  }) = _Deployment;

  factory Deployment.fromJson(Map<String, dynamic> json) =>
      _$DeploymentFromJson(json);
}

/// Deployment configuration.
@freezed
sealed class DeploymentConfig with _$DeploymentConfig {
  const factory DeploymentConfig({
    @JsonKey(name: 'server_id') required String serverId,
    DeploymentImage? image,
    String? restart,
    String? network,
    @Default([]) List<PortMapping> ports,
    @Default([]) List<VolumeMapping> volumes,
    @Default([]) List<EnvironmentVar> environment,
  }) = _DeploymentConfig;

  factory DeploymentConfig.fromJson(Map<String, dynamic> json) =>
      _$DeploymentConfigFromJson(json);
}

/// Docker image configuration.
@freezed
sealed class DeploymentImage with _$DeploymentImage {
  const DeploymentImage._();

  const factory DeploymentImage({
    required String image,
    String? tag,
  }) = _DeploymentImage;

  factory DeploymentImage.fromJson(Map<String, dynamic> json) =>
      _$DeploymentImageFromJson(json);

  /// Returns the full image name with tag.
  String get fullName => tag != null ? '$image:$tag' : image;
}

/// Port mapping configuration.
@freezed
sealed class PortMapping with _$PortMapping {
  const factory PortMapping({
    @JsonKey(name: 'local') required String hostPort,
    @JsonKey(name: 'container') required String containerPort,
  }) = _PortMapping;

  factory PortMapping.fromJson(Map<String, dynamic> json) =>
      _$PortMappingFromJson(json);
}

/// Volume mapping configuration.
@freezed
sealed class VolumeMapping with _$VolumeMapping {
  const factory VolumeMapping({
    @JsonKey(name: 'local') required String hostPath,
    @JsonKey(name: 'container') required String containerPath,
  }) = _VolumeMapping;

  factory VolumeMapping.fromJson(Map<String, dynamic> json) =>
      _$VolumeMappingFromJson(json);
}

/// Environment variable configuration.
@freezed
sealed class EnvironmentVar with _$EnvironmentVar {
  const factory EnvironmentVar({
    required String variable,
    required String value,
  }) = _EnvironmentVar;

  factory EnvironmentVar.fromJson(Map<String, dynamic> json) =>
      _$EnvironmentVarFromJson(json);
}

/// Additional deployment information.
@freezed
sealed class DeploymentInfo with _$DeploymentInfo {
  const factory DeploymentInfo({
    DeploymentState? state,
  }) = _DeploymentInfo;

  factory DeploymentInfo.fromJson(Map<String, dynamic> json) =>
      _$DeploymentInfoFromJson(json);
}

/// The state of a deployment container.
@JsonEnum(valueField: 'value')
enum DeploymentState {
  running('Running'),
  restarting('Restarting'),
  exited('Exited'),
  paused('Paused'),
  notDeployed('NotDeployed'),
  unknown('Unknown');

  const DeploymentState(this.value);
  final String value;
}

extension DeploymentStateX on DeploymentState {
  bool get isRunning => this == DeploymentState.running;
  bool get isStopped =>
      this == DeploymentState.exited || this == DeploymentState.notDeployed;
  bool get isPaused => this == DeploymentState.paused;

  String get displayName => switch (this) {
        DeploymentState.running => 'Running',
        DeploymentState.restarting => 'Restarting',
        DeploymentState.exited => 'Exited',
        DeploymentState.paused => 'Paused',
        DeploymentState.notDeployed => 'Not Deployed',
        DeploymentState.unknown => 'Unknown',
      };
}
