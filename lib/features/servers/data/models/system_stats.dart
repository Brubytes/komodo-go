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
    @JsonKey(name: 'mem_buff_cache_gb') @Default(0) double memBuffCacheGb,
    @JsonKey(name: 'mem_zfs_arc_gb') @Default(0) double memZfsArcGb,
    @JsonKey(name: 'swap_total_gb') @Default(0) double swapTotalGb,
    @JsonKey(name: 'swap_used_gb') @Default(0) double swapUsedGb,
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

/// A database-backed server statistics sample returned by
/// `GetHistoricalServerStats`.
class HistoricalSystemStats {
  const HistoricalSystemStats({
    required this.timestamp,
    required this.cpuPercent,
    required this.memUsedGb,
    required this.memTotalGb,
    required this.diskUsedGb,
    required this.diskTotalGb,
    required this.disks,
    required this.networkIngressBytes,
    required this.networkEgressBytes,
  });

  factory HistoricalSystemStats.fromJson(Map<String, dynamic> json) {
    double number(String key) => (json[key] as num?)?.toDouble() ?? 0;
    final rawTimestamp = (json['ts'] as num?)?.toInt() ?? 0;
    // Komodo serializes Unix timestamps in milliseconds. Accept seconds as a
    // compatibility fallback for older installations and fixtures.
    final timestamp = rawTimestamp.abs() < 100000000000
        ? DateTime.fromMillisecondsSinceEpoch(rawTimestamp * 1000)
        : DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
    final diskJson = json['disks'] as List<dynamic>? ?? const [];

    return HistoricalSystemStats(
      timestamp: timestamp,
      cpuPercent: number('cpu_perc'),
      memUsedGb: number('mem_used_gb'),
      memTotalGb: number('mem_total_gb'),
      diskUsedGb: number('disk_used_gb'),
      diskTotalGb: number('disk_total_gb'),
      disks: diskJson
          .whereType<Map<String, dynamic>>()
          .map(SingleDiskUsage.fromJson)
          .toList(growable: false),
      networkIngressBytes: number('network_ingress_bytes'),
      networkEgressBytes: number('network_egress_bytes'),
    );
  }

  final DateTime timestamp;
  final double cpuPercent;
  final double memUsedGb;
  final double memTotalGb;
  final double diskUsedGb;
  final double diskTotalGb;
  final List<SingleDiskUsage> disks;
  final double networkIngressBytes;
  final double networkEgressBytes;

  double get memPercent => memTotalGb > 0 ? (memUsedGb / memTotalGb) * 100 : 0;
  double get diskPercent =>
      diskTotalGb > 0 ? (diskUsedGb / diskTotalGb) * 100 : 0;
}

class HistoricalSystemStatsPage {
  const HistoricalSystemStatsPage({
    required this.stats,
    required this.nextPage,
  });

  factory HistoricalSystemStatsPage.fromJson(Map<String, dynamic> json) {
    final items = json['stats'] as List<dynamic>? ?? const [];
    return HistoricalSystemStatsPage(
      stats: items
          .whereType<Map<String, dynamic>>()
          .map(HistoricalSystemStats.fromJson)
          .toList(growable: false),
      nextPage: (json['next_page'] as num?)?.toInt(),
    );
  }

  final List<HistoricalSystemStats> stats;
  final int? nextPage;
}

enum ServerStatsGranularity {
  oneMinute('1-min', '1 min'),
  fiveMinutes('5-min', '5 min'),
  oneHour('1-hr', '1 hr');

  const ServerStatsGranularity(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

/// A process sample returned by `ListSystemProcesses`.
class SystemProcess {
  const SystemProcess({
    required this.pid,
    required this.name,
    required this.executable,
    required this.command,
    required this.startTime,
    required this.cpuPercent,
    required this.memoryMb,
    required this.diskReadKb,
    required this.diskWriteKb,
  });

  factory SystemProcess.fromJson(Map<String, dynamic> json) {
    double number(String key) => (json[key] as num?)?.toDouble() ?? 0;
    return SystemProcess(
      pid: (json['pid'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      executable: json['exe'] as String? ?? '',
      command: (json['cmd'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      startTime: number('start_time'),
      cpuPercent: number('cpu_perc'),
      memoryMb: number('mem_mb'),
      diskReadKb: number('disk_read_kb'),
      diskWriteKb: number('disk_write_kb'),
    );
  }

  final int pid;
  final String name;
  final String executable;
  final List<String> command;
  final double startTime;
  final double cpuPercent;
  final double memoryMb;
  final double diskReadKb;
  final double diskWriteKb;
}
