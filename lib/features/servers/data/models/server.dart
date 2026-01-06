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
    required ServerConfig config,
    @JsonKey(name: 'info') ServerInfo? info,
  }) = _Server;

  factory Server.fromJson(Map<String, dynamic> json) => _$ServerFromJson(json);
}

/// Server configuration.
@freezed
sealed class ServerConfig with _$ServerConfig {
  const factory ServerConfig({
    required String address,
    int? port,
    @Default(true) bool enabled,
  }) = _ServerConfig;

  factory ServerConfig.fromJson(Map<String, dynamic> json) =>
      _$ServerConfigFromJson(json);
}

/// Additional server information.
@freezed
sealed class ServerInfo with _$ServerInfo {
  const factory ServerInfo({
    ServerState? state,
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
