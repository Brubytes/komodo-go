import 'package:freezed_annotation/freezed_annotation.dart';

part 'server.freezed.dart';
part 'server.g.dart';

/// Represents a server managed by Komodo.
@freezed
sealed class Server with _$Server {
  const factory Server({
    required String id,
    required String name,
    String? description,
    @Default([]) List<String> tags,
    @Default(false) bool template,
    ServerInfo? info,
  }) = _Server;

  factory Server.fromJson(Map<String, dynamic> json) => _$ServerFromJson(json);
}

/// Server information from the API.
@freezed
sealed class ServerInfo with _$ServerInfo {
  const factory ServerInfo({
    ServerState? state,
    @Default('') String region,
    @Default('') String address,
    @JsonKey(name: 'external_address') @Default('') String externalAddress,
    String? version,
    @JsonKey(name: 'send_unreachable_alerts') @Default(true) bool sendUnreachableAlerts,
    @JsonKey(name: 'send_cpu_alerts') @Default(true) bool sendCpuAlerts,
    @JsonKey(name: 'send_mem_alerts') @Default(true) bool sendMemAlerts,
    @JsonKey(name: 'send_disk_alerts') @Default(true) bool sendDiskAlerts,
    @JsonKey(name: 'terminals_disabled') @Default(false) bool terminalsDisabled,
  }) = _ServerInfo;

  factory ServerInfo.fromJson(Map<String, dynamic> json) =>
      _$ServerInfoFromJson(json);
}

/// The state of a server.
@JsonEnum(valueField: 'value')
enum ServerState {
  ok('Ok'),
  notOk('NotOk'),
  disabled('Disabled'),
  unknown('Unknown');

  const ServerState(this.value);
  final String value;
}
