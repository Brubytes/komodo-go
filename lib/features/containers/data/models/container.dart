import 'package:freezed_annotation/freezed_annotation.dart';

part 'container.freezed.dart';
part 'container.g.dart';

/// Container summary returned by `ListDockerContainers` (`ContainerListItem` in `komodo_client`).
@freezed
sealed class ContainerListItem with _$ContainerListItem {
  const factory ContainerListItem({
    @JsonKey(name: 'server_id') String? serverId,
    @Default('') String name,
    String? id,
    String? image,
    String? status,
    @JsonKey(fromJson: _containerStateFromJson, toJson: _containerStateToJson)
    @Default(ContainerState.unknown)
    ContainerState state,
    @Default([]) List<String> networks,
    @Default([]) List<ContainerPort> ports,
  }) = _ContainerListItem;

  factory ContainerListItem.fromJson(Map<String, dynamic> json) =>
      _$ContainerListItemFromJson(json);
}

@freezed
sealed class ContainerPort with _$ContainerPort {
  const factory ContainerPort({
    String? ip,
    @JsonKey(name: 'private_port') @Default(0) int privatePort,
    @JsonKey(name: 'public_port') int? publicPort,
    @JsonKey(name: 'typ', fromJson: _portTypeFromJson, toJson: _portTypeToJson)
    @Default(PortType.unknown)
    PortType type,
  }) = _ContainerPort;

  factory ContainerPort.fromJson(Map<String, dynamic> json) =>
      _$ContainerPortFromJson(json);
}

enum ContainerState {
  running,
  created,
  paused,
  restarting,
  exited,
  removing,
  dead,
  unknown,
}

ContainerState _containerStateFromJson(Object? value) {
  if (value is! String) return ContainerState.unknown;
  final normalized = value.trim().toLowerCase().replaceAll('_', '');
  return switch (normalized) {
    'running' => ContainerState.running,
    'created' => ContainerState.created,
    'paused' => ContainerState.paused,
    'restarting' => ContainerState.restarting,
    'exited' => ContainerState.exited,
    'removing' => ContainerState.removing,
    'dead' => ContainerState.dead,
    _ => ContainerState.unknown,
  };
}

String _containerStateToJson(ContainerState value) {
  return switch (value) {
    ContainerState.running => 'Running',
    ContainerState.created => 'Created',
    ContainerState.paused => 'Paused',
    ContainerState.restarting => 'Restarting',
    ContainerState.exited => 'Exited',
    ContainerState.removing => 'Removing',
    ContainerState.dead => 'Dead',
    ContainerState.unknown => 'Unknown',
  };
}

enum PortType { tcp, udp, unknown }

PortType _portTypeFromJson(Object? value) {
  if (value is! String) return PortType.unknown;
  final normalized = value.trim().toLowerCase().replaceAll('_', '');
  return switch (normalized) {
    'tcp' => PortType.tcp,
    'udp' => PortType.udp,
    _ => PortType.unknown,
  };
}

String _portTypeToJson(PortType value) {
  return switch (value) {
    PortType.tcp => 'Tcp',
    PortType.udp => 'Udp',
    PortType.unknown => 'Unknown',
  };
}
