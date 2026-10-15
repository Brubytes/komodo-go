import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/data/models/system_stats.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';

/// Display-ready values of the home "Server overview" metric grid.
///
/// A record so that equal values compare equal: the section only rebuilds
/// when something it actually shows changes, not on every stats poll tick.
typedef HomeServerOverview = ({
  String cpuValue,
  String cpuSubtitle,
  String memValue,
  String memSubtitle,
  String diskValue,
  String diskSubtitle,
  String serverCount,
  String serverSubtitle,
});

/// Aggregates server list + per-server stats into [HomeServerOverview].
///
/// Data is `null` when there are no servers.
final Provider<AsyncValue<HomeServerOverview?>> homeServerOverviewProvider =
    Provider.autoDispose<AsyncValue<HomeServerOverview?>>((ref) {
      final serversAsync = ref.watch(serversProvider);
      return serversAsync.whenData((servers) {
        if (servers.isEmpty) return null;
        final statsValues = [
          for (final server in servers)
            ref.watch(serverStatsProvider(server.id)),
        ];
        return buildHomeServerOverview(servers, statsValues);
      });
    });

/// Pure aggregation behind [homeServerOverviewProvider] (unit-testable).
HomeServerOverview buildHomeServerOverview(
  List<Server> servers,
  List<AsyncValue<SystemStats?>> statsValues,
) {
  final statsEntries = <HomeServerStatsEntry>[
    for (var i = 0; i < servers.length; i++)
      if (statsValues[i].asData?.value != null)
        HomeServerStatsEntry(
          server: servers[i],
          stats: statsValues[i].asData!.value!,
        ),
  ];
  final summary = HomeServerStatsSummary.from(servers, statsEntries);
  final hasStats = summary.statsCount > 0;
  final isStatsLoading = statsValues.any((value) => value.isLoading);

  String avgWithTotals(double average, String totals) {
    final avgLabel = '${average.toStringAsFixed(0)}%';
    if (totals.isEmpty) return avgLabel;
    return '$avgLabel\n$totals';
  }

  String statsSubtitle({
    required double maxValue,
    required String? serverName,
  }) {
    if (!hasStats) {
      return isStatsLoading ? 'Loading stats' : 'No stats yet';
    }
    final label = 'max ${maxValue.toStringAsFixed(0)}%';
    final name = (serverName?.trim().isNotEmpty ?? false)
        ? serverName!.trim()
        : null;
    final parts = <String>[label, ?name];
    return parts.join(' · ');
  }

  final serverSubtitleParts = <String>[
    if (summary.online > 0) '${summary.online} online',
    if (summary.offline > 0) '${summary.offline} down',
    if (summary.disabled > 0) '${summary.disabled} disabled',
    if (summary.unknown > 0) '${summary.unknown} unknown',
  ];

  return (
    cpuValue: hasStats ? '${summary.avgCpu.toStringAsFixed(0)}%' : '—',
    cpuSubtitle: statsSubtitle(
      maxValue: summary.maxCpu,
      serverName: summary.maxCpuServerName,
    ),
    memValue: hasStats
        ? avgWithTotals(summary.avgMem, summary.memTotalsLabel)
        : '—',
    memSubtitle: statsSubtitle(
      maxValue: summary.maxMem,
      serverName: summary.maxMemServerName,
    ),
    diskValue: hasStats
        ? avgWithTotals(summary.avgDisk, summary.diskTotalsLabel)
        : '—',
    diskSubtitle: statsSubtitle(
      maxValue: summary.maxDisk,
      serverName: summary.maxDiskServerName,
    ),
    serverCount: summary.total.toString(),
    serverSubtitle: serverSubtitleParts.isEmpty
        ? 'No status data'
        : serverSubtitleParts.join(' · '),
  );
}

class HomeServerStatsEntry {
  const HomeServerStatsEntry({required this.server, required this.stats});

  final Server server;
  final SystemStats stats;
}

class HomeServerStatsSummary {
  const HomeServerStatsSummary({
    required this.total,
    required this.online,
    required this.offline,
    required this.disabled,
    required this.unknown,
    required this.avgCpu,
    required this.avgMem,
    required this.avgDisk,
    required this.maxCpu,
    required this.maxMem,
    required this.maxDisk,
    required this.maxCpuServerName,
    required this.maxMemServerName,
    required this.maxDiskServerName,
    required this.totalMemUsedGb,
    required this.totalMemGb,
    required this.totalDiskUsedGb,
    required this.totalDiskGb,
    required this.statsCount,
  });

  factory HomeServerStatsSummary.from(
    List<Server> servers,
    List<HomeServerStatsEntry> entries,
  ) {
    final total = servers.length;
    final online = servers
        .where((server) => server.state == ServerState.ok)
        .length;
    final offline = servers
        .where((server) => server.state == ServerState.notOk)
        .length;
    final disabled = servers
        .where((server) => server.state == ServerState.disabled)
        .length;
    final unknown = servers
        .where((server) => server.state == ServerState.unknown)
        .length;

    if (entries.isEmpty) {
      return HomeServerStatsSummary(
        total: total,
        online: online,
        offline: offline,
        disabled: disabled,
        unknown: unknown,
        avgCpu: 0,
        avgMem: 0,
        avgDisk: 0,
        maxCpu: 0,
        maxMem: 0,
        maxDisk: 0,
        maxCpuServerName: null,
        maxMemServerName: null,
        maxDiskServerName: null,
        totalMemUsedGb: 0,
        totalMemGb: 0,
        totalDiskUsedGb: 0,
        totalDiskGb: 0,
        statsCount: 0,
      );
    }

    var sumCpu = 0.0;
    var sumMem = 0.0;
    var sumDisk = 0.0;
    var totalMemUsed = 0.0;
    var totalMem = 0.0;
    var totalDiskUsed = 0.0;
    var totalDisk = 0.0;

    var maxCpu = -1.0;
    var maxMem = -1.0;
    var maxDisk = -1.0;
    String? maxCpuServerName;
    String? maxMemServerName;
    String? maxDiskServerName;

    for (final entry in entries) {
      final stats = entry.stats;
      sumCpu += stats.cpuPercent;
      sumMem += stats.memPercent;
      sumDisk += stats.diskPercent;

      totalMemUsed += stats.memUsedGb;
      totalMem += stats.memTotalGb;
      totalDiskUsed += stats.diskUsedGb;
      totalDisk += stats.diskTotalGb;

      if (stats.cpuPercent >= maxCpu) {
        maxCpu = stats.cpuPercent;
        maxCpuServerName = entry.server.name;
      }
      if (stats.memPercent >= maxMem) {
        maxMem = stats.memPercent;
        maxMemServerName = entry.server.name;
      }
      if (stats.diskPercent >= maxDisk) {
        maxDisk = stats.diskPercent;
        maxDiskServerName = entry.server.name;
      }
    }

    final count = entries.length.toDouble();

    return HomeServerStatsSummary(
      total: total,
      online: online,
      offline: offline,
      disabled: disabled,
      unknown: unknown,
      avgCpu: sumCpu / count,
      avgMem: sumMem / count,
      avgDisk: sumDisk / count,
      maxCpu: maxCpu < 0 ? 0 : maxCpu,
      maxMem: maxMem < 0 ? 0 : maxMem,
      maxDisk: maxDisk < 0 ? 0 : maxDisk,
      maxCpuServerName: maxCpuServerName,
      maxMemServerName: maxMemServerName,
      maxDiskServerName: maxDiskServerName,
      totalMemUsedGb: totalMemUsed,
      totalMemGb: totalMem,
      totalDiskUsedGb: totalDiskUsed,
      totalDiskGb: totalDisk,
      statsCount: entries.length,
    );
  }

  final int total;
  final int online;
  final int offline;
  final int disabled;
  final int unknown;
  final double avgCpu;
  final double avgMem;
  final double avgDisk;
  final double maxCpu;
  final double maxMem;
  final double maxDisk;
  final String? maxCpuServerName;
  final String? maxMemServerName;
  final String? maxDiskServerName;
  final double totalMemUsedGb;
  final double totalMemGb;
  final double totalDiskUsedGb;
  final double totalDiskGb;
  final int statsCount;

  String get memTotalsLabel => _totalsLabel(totalMemUsedGb, totalMemGb);
  String get diskTotalsLabel => _totalsLabel(totalDiskUsedGb, totalDiskGb);

  String _totalsLabel(double used, double total) {
    if (total <= 0) return '';
    return _formatCapacity(used, total);
  }

  String _formatCapacity(double usedGb, double totalGb) {
    if (totalGb >= 1024) {
      final usedTb = usedGb / 1024;
      final totalTb = totalGb / 1024;
      return '${_formatNumber(usedTb)}/${_formatNumber(totalTb)}TB';
    }
    return '${_formatNumber(usedGb, decimals: 0)}/${_formatNumber(totalGb, decimals: 0)}GB';
  }

  String _formatNumber(double value, {int decimals = 1}) {
    final fixed = value.toStringAsFixed(decimals);
    if (decimals == 0) return fixed;
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }
}
