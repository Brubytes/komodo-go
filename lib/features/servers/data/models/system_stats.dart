import 'package:freezed_annotation/freezed_annotation.dart';

part 'system_stats.freezed.dart';
part 'system_stats.g.dart';

/// System statistics for a server (CPU, memory, disk).
@freezed
sealed class SystemStats with _$SystemStats {
  const SystemStats._();

  const factory SystemStats({
    @JsonKey(name: 'cpu_perc') @Default(0) double cpuPercent,
    @JsonKey(name: 'mem_total_gb') @Default(0) double memTotalGb,
    @JsonKey(name: 'mem_used_gb') @Default(0) double memUsedGb,
    @JsonKey(name: 'disk_total_gb') @Default(0) double diskTotalGb,
    @JsonKey(name: 'disk_used_gb') @Default(0) double diskUsedGb,
  }) = _SystemStats;

  factory SystemStats.fromJson(Map<String, dynamic> json) =>
      _$SystemStatsFromJson(json);

  /// Memory usage as a percentage (0-100).
  double get memPercent =>
      memTotalGb > 0 ? (memUsedGb / memTotalGb) * 100 : 0;

  /// Disk usage as a percentage (0-100).
  double get diskPercent =>
      diskTotalGb > 0 ? (diskUsedGb / diskTotalGb) * 100 : 0;

  /// Available memory in GB.
  double get memAvailableGb => memTotalGb - memUsedGb;

  /// Available disk space in GB.
  double get diskAvailableGb => diskTotalGb - diskUsedGb;
}
