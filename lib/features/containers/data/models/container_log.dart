import 'package:freezed_annotation/freezed_annotation.dart';

part 'container_log.freezed.dart';
part 'container_log.g.dart';

/// Log returned by `GetContainerLog` (`Log` in `komodo_client`).
@freezed
sealed class ContainerLog with _$ContainerLog {
  const factory ContainerLog({
    @Default('') String stage,
    @Default('') String command,
    @Default('') String stdout,
    @Default('') String stderr,
    @Default(false) bool success,
    @JsonKey(name: 'start_ts') @Default(0) int startTs,
    @JsonKey(name: 'end_ts') @Default(0) int endTs,
  }) = _ContainerLog;

  factory ContainerLog.fromJson(Map<String, dynamic> json) =>
      _$ContainerLogFromJson(json);
}
