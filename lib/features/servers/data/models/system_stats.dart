import 'package:freezed_annotation/freezed_annotation.dart';

part 'system_stats.freezed.dart';
part 'system_stats.g.dart';

/// System statistics for a server (CPU, memory, disk).
///
/// Mirrors `komodo_client::entities::stats::SystemStats` (docs.rs).
@freezed
sealed class SystemStats with _$SystemStats {
  const factory SystemStats({
    @JsonKey(name: 'cpu_perc') @Default(0) double cpuPercent,
    @JsonKey(name: 'load_average') SystemLoadAverage? loadAverage,
    @JsonKey(name: 'mem_free_gb') @Default(0) double memFreeGb,
    @JsonKey(name: 'mem_used_gb') @Default(0) double memUsedGb,
    @JsonKey(name: 'mem_total_gb') @Default(0) double memTotalGb,
    @Default([]) List<SingleDiskUsage> disks,
    @JsonKey(name: 'network_ingress_bytes')
    @Default(0)
    double networkIngressBytes,
    @JsonKey(name: 'network_egress_bytes')
    @Default(0)
    double networkEgressBytes,
    @JsonKey(name: 'polling_rate') String? pollingRate,
    @JsonKey(name: 'refresh_ts') @Default(0) int refreshTs,
    @JsonKey(name: 'refresh_list_ts') @Default(0) int refreshListTs,
  }) = _SystemStats;

  const SystemStats._();

  factory SystemStats.fromJson(Map<String, dynamic> json) =>
      _$SystemStatsFromJson(json);

  /// Memory usage as a percentage (0-100).
  double get memPercent => memTotalGb > 0 ? (memUsedGb / memTotalGb) * 100 : 0;

  /// Disk usage as a percentage (0-100).
  double get diskPercent =>
      diskTotalGb > 0 ? (diskUsedGb / diskTotalGb) * 100 : 0;

  /// Total disk space across all mounts in GB.
  double get diskTotalGb =>
      disks.fold<double>(0, (sum, disk) => sum + disk.totalGb);

  /// Used disk space across all mounts in GB.
  double get diskUsedGb =>
      disks.fold<double>(0, (sum, disk) => sum + disk.usedGb);

  /// Available memory in GB.
  double get memAvailableGb => memTotalGb - memUsedGb;

  /// Available disk space in GB.
  double get diskAvailableGb => diskTotalGb - diskUsedGb;
}

@freezed
sealed class SystemLoadAverage with _$SystemLoadAverage {
  const factory SystemLoadAverage({
    @Default(0) double one,
    @Default(0) double five,
    @Default(0) double fifteen,
  }) = _SystemLoadAverage;

  factory SystemLoadAverage.fromJson(Map<String, dynamic> json) =>
      _$SystemLoadAverageFromJson(json);
}

@freezed
sealed class SingleDiskUsage with _$SingleDiskUsage {
  const factory SingleDiskUsage({
    @Default('') String mount,
    @JsonKey(name: 'file_system') @Default('') String fileSystem,
    @JsonKey(name: 'used_gb') @Default(0) double usedGb,
    @JsonKey(name: 'total_gb') @Default(0) double totalGb,
  }) = _SingleDiskUsage;

  factory SingleDiskUsage.fromJson(Map<String, dynamic> json) =>
      _$SingleDiskUsageFromJson(json);
}
