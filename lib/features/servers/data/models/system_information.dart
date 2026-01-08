import 'package:freezed_annotation/freezed_annotation.dart';

part 'system_information.freezed.dart';
part 'system_information.g.dart';

/// System information of a server.
///
/// Mirrors `komodo_client::entities::stats::SystemInformation` (docs.rs).
@freezed
sealed class SystemInformation with _$SystemInformation {
  const factory SystemInformation({
    String? name,
    String? os,
    String? kernel,
    @JsonKey(name: 'core_count') int? coreCount,
    @JsonKey(name: 'host_name') String? hostName,
    @JsonKey(name: 'cpu_brand') @Default('') String cpuBrand,
    @JsonKey(name: 'terminals_disabled') @Default(false) bool terminalsDisabled,
    @JsonKey(name: 'container_exec_disabled')
    @Default(false)
    bool containerExecDisabled,
  }) = _SystemInformation;

  factory SystemInformation.fromJson(Map<String, dynamic> json) =>
      _$SystemInformationFromJson(json);
}
