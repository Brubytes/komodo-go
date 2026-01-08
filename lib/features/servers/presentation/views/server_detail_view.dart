import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/utils/byte_format.dart';

import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/data/models/system_information.dart';
import 'package:komodo_go/features/servers/data/models/system_stats.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';

/// View displaying detailed server information.
class ServerDetailView extends ConsumerStatefulWidget {
  const ServerDetailView({
    required this.serverId,
    required this.serverName,
    super.key,
  });

  final String serverId;
  final String serverName;

  @override
  ConsumerState<ServerDetailView> createState() => _ServerDetailViewState();
}

class _ServerDetailViewState extends ConsumerState<ServerDetailView> {
  Timer? _statsRefreshTimer;
  ProviderSubscription<AsyncValue<SystemStats?>>? _statsSubscription;

  DateTime? _previousSampleTs;
  double? _previousIngressBytes;
  double? _previousEgressBytes;
  double? _ingressBytesPerSecond;
  double? _egressBytesPerSecond;
  final List<_StatsSample> _history = <_StatsSample>[];
  static const int _maxHistorySamples = 120; // ~5 minutes @ 2.5s

  @override
  void initState() {
    super.initState();

    _statsRefreshTimer = Timer.periodic(const Duration(milliseconds: 2500), (
      _,
    ) {
      ref.invalidate(serverStatsProvider(widget.serverId));
    });

    _statsSubscription = ref.listenManual<AsyncValue<SystemStats?>>(
      serverStatsProvider(widget.serverId),
      (previous, next) {
        final stats = next.asData?.value;
        if (stats == null) return;
        _recordSample(stats);
      },
    );
  }

  @override
  void dispose() {
    _statsRefreshTimer?.cancel();
    _statsRefreshTimer = null;
    _statsSubscription?.close();
    _statsSubscription = null;
    super.dispose();
  }

  void _recordSample(SystemStats stats) {
    final now = DateTime.now();
    final previousSampleTs = _previousSampleTs;
    final previousIngressBytes = _previousIngressBytes;
    final previousEgressBytes = _previousEgressBytes;

    _previousSampleTs = now;
    _previousIngressBytes = stats.networkIngressBytes;
    _previousEgressBytes = stats.networkEgressBytes;

    double ingressBps = 0;
    double egressBps = 0;
    if (previousSampleTs != null &&
        previousIngressBytes != null &&
        previousEgressBytes != null) {
      final dtSeconds =
          now.difference(previousSampleTs).inMilliseconds.toDouble() / 1000.0;

      if (dtSeconds > 0) {
        final ingressDelta = stats.networkIngressBytes - previousIngressBytes;
        final egressDelta = stats.networkEgressBytes - previousEgressBytes;

        if (ingressDelta >= 0 && egressDelta >= 0) {
          ingressBps = ingressDelta / dtSeconds;
          egressBps = egressDelta / dtSeconds;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _ingressBytesPerSecond = ingressBps;
      _egressBytesPerSecond = egressBps;

      _history.add(
        _StatsSample(
          ts: DateTime.now(),
          cpuPercent: stats.cpuPercent,
          memPercent: stats.memPercent,
          diskPercent: stats.diskPercent,
          ingressBytesPerSecond: ingressBps,
          egressBytesPerSecond: egressBps,
        ),
      );
      if (_history.length > _maxHistorySamples) {
        _history.removeRange(0, _history.length - _maxHistorySamples);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final serverAsync = ref.watch(serverDetailProvider(widget.serverId));
    final statsAsync = ref.watch(serverStatsProvider(widget.serverId));
    final systemInfoAsync = ref.watch(
      serverSystemInformationProvider(widget.serverId),
    );
    final serversListAsync = ref.watch(serversProvider);

    final server = serverAsync.asData?.value;
    final stats = statsAsync.asData?.value;
    final systemInformation = systemInfoAsync.asData?.value;

    Server? listServer;
    final servers = serversListAsync.asData?.value;
    if (servers != null) {
      for (final s in servers) {
        if (s.id == widget.serverId) {
          listServer = s;
          break;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.serverName)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(serverDetailProvider(widget.serverId))
            ..invalidate(serverSystemInformationProvider(widget.serverId))
            ..invalidate(serverStatsProvider(widget.serverId));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ServerSummaryCard(
              server: server ?? listServer,
              listServer: listServer,
              stats: stats,
              systemInformation: systemInformation,
              ingressBytesPerSecond: _ingressBytesPerSecond,
              egressBytesPerSecond: _egressBytesPerSecond,
            ),
            const Gap(16),
            statsAsync.when(
              data: (stats) =>
                  _StatsHistoryCard(history: _history, latestStats: stats),
              loading: () => const _LoadingCard(),
              error: (error, _) =>
                  _MessageCard(message: 'Stats unavailable: $error'),
            ),
            const Gap(16),
            serverAsync.when(
              data: (server) => server?.config != null
                  ? _ServerConfigCard(config: server!.config!)
                  : const _MessageCard(message: 'No config available'),
              loading: () => const _LoadingCard(),
              error: (error, _) => _MessageCard(message: 'Config: $error'),
            ),
            const Gap(16),
            systemInfoAsync.when(
              data: (info) => info != null
                  ? _SystemInfoCard(info: info)
                  : const _MessageCard(message: 'System info unavailable'),
              loading: () => const _LoadingCard(),
              error: (error, _) =>
                  _MessageCard(message: 'System info unavailable: $error'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerSummaryCard extends StatelessWidget {
  const _ServerSummaryCard({
    required this.server,
    required this.listServer,
    required this.stats,
    required this.systemInformation,
    required this.ingressBytesPerSecond,
    required this.egressBytesPerSecond,
  });

  final Server? server;
  final Server? listServer;
  final SystemStats? stats;
  final SystemInformation? systemInformation;
  final double? ingressBytesPerSecond;
  final double? egressBytesPerSecond;

  @override
  Widget build(BuildContext context) {
    final server = this.server;
    final listServer = this.listServer;
    final stats = this.stats;
    final systemInformation = this.systemInformation;

    final scheme = Theme.of(context).colorScheme;

    final version = (listServer?.info?.version.isNotEmpty ?? false)
        ? listServer!.info!.version
        : server?.info?.version;
    final cores = systemInformation?.coreCount;
    final load = stats?.loadAverage?.one;
    final memUsed = stats?.memUsedGb;
    final memTotal = stats?.memTotalGb;
    final diskUsed = stats?.diskUsedGb;
    final diskTotal = stats?.diskTotalGb;

    final address = (listServer?.address.isNotEmpty ?? false)
        ? listServer!.address
        : server?.address;
    final description = server?.description;

    final loadPercent = (load != null && (cores ?? 0) > 0)
        ? (load / cores!).clamp(0.0, 1.0)
        : null;
    final memPercent = stats != null
        ? (stats.memPercent / 100).clamp(0.0, 1.0)
        : null;
    final diskPercent = stats != null
        ? (stats.diskPercent / 100).clamp(0.0, 1.0)
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricChip(
                  icon: AppIcons.ok,
                  label: 'Version',
                  value: (version?.isNotEmpty ?? false) ? version! : '—',
                ),
                _MetricChip(
                  icon: AppIcons.cpu,
                  label: 'Cores',
                  value: cores != null ? cores.toString() : '—',
                ),
                _MetricChip(
                  icon: AppIcons.activity,
                  label: 'Load (1m)',
                  value: load != null ? load.toStringAsFixed(2) : '—',
                  progress: loadPercent,
                ),
                _MetricChip(
                  icon: AppIcons.memory,
                  label: 'Memory',
                  value: memUsed != null && memTotal != null && memTotal > 0
                      ? '${memUsed.toStringAsFixed(1)} / ${memTotal.toStringAsFixed(1)} GB'
                      : '—',
                  progress: memPercent,
                ),
                _MetricChip(
                  icon: AppIcons.hardDrive,
                  label: 'Disk',
                  value: diskUsed != null && diskTotal != null && diskTotal > 0
                      ? '${diskUsed.toStringAsFixed(1)} / ${diskTotal.toStringAsFixed(1)} GB'
                      : '—',
                  progress: diskPercent,
                ),
                _MetricChip(
                  icon: AppIcons.wifi,
                  label: 'Net (in/out)',
                  value:
                      ingressBytesPerSecond != null &&
                          egressBytesPerSecond != null
                      ? '${formatBytesPerSecond(ingressBytesPerSecond!)} / ${formatBytesPerSecond(egressBytesPerSecond!)}'
                      : '—',
                ),
              ],
            ),
            if ((address?.isNotEmpty ?? false) ||
                (description?.isNotEmpty ?? false)) ...[
              const Gap(12),
              if (address?.isNotEmpty ?? false)
                _InfoRow(label: 'Address', value: address!),
              if (description?.isNotEmpty ?? false)
                _InfoRow(label: 'Description', value: description!),
            ],
            if (server?.tags.isNotEmpty ?? false) ...[
              const Gap(12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in server!.tags)
                    Chip(
                      label: Text(tag),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: scheme.secondaryContainer,
                      labelStyle: TextStyle(color: scheme.onSecondaryContainer),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
    this.progress,
  });

  final IconData icon;
  final String label;
  final String value;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const Gap(8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (progress != null) ...[
                const Gap(6),
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress!.clamp(0, 1),
                      minHeight: 4,
                      backgroundColor: scheme.onSurfaceVariant.withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SystemInfoCard extends StatelessWidget {
  const _SystemInfoCard({required this.info});

  final SystemInformation info;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(16),
            if (info.name?.isNotEmpty ?? false)
              _InfoRow(label: 'Name', value: info.name!),
            if (info.hostName?.isNotEmpty ?? false)
              _InfoRow(label: 'Host', value: info.hostName!),
            if (info.os?.isNotEmpty ?? false)
              _InfoRow(label: 'OS', value: info.os!),
            if (info.kernel?.isNotEmpty ?? false)
              _InfoRow(label: 'Kernel', value: info.kernel!),
            if (info.cpuBrand.isNotEmpty)
              _InfoRow(label: 'CPU', value: info.cpuBrand),
            if (info.coreCount != null)
              _InfoRow(label: 'Cores', value: info.coreCount.toString()),
            _InfoRow(
              label: 'Terminal',
              value: info.terminalsDisabled ? 'Disabled' : 'Enabled',
            ),
            _InfoRow(
              label: 'Container exec',
              value: info.containerExecDisabled ? 'Disabled' : 'Enabled',
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerConfigCard extends StatelessWidget {
  const _ServerConfigCard({required this.config});

  final ServerConfig config;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Config',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(16),
            _InfoRow(label: 'Enabled', value: config.enabled ? 'Yes' : 'No'),
            _InfoRow(
              label: 'Region',
              value: config.region.isNotEmpty ? config.region : '—',
            ),
            _InfoRow(
              label: 'Address',
              value: config.address.isNotEmpty ? config.address : '—',
            ),
            _InfoRow(
              label: 'External',
              value: config.externalAddress.isNotEmpty
                  ? config.externalAddress
                  : '—',
            ),
            _InfoRow(
              label: 'Timeout',
              value: config.timeoutSeconds > 0
                  ? '${config.timeoutSeconds}s'
                  : '—',
            ),
            _InfoRow(
              label: 'Passkey',
              value: config.passkey.isNotEmpty ? 'Set' : 'Not set',
            ),
            _InfoRow(
              label: 'Stats monitoring',
              value: config.statsMonitoring ? 'On' : 'Off',
            ),
            _InfoRow(
              label: 'Auto prune',
              value: config.autoPrune ? 'On' : 'Off',
            ),
            if (config.ignoreMounts.isNotEmpty)
              _InfoRow(
                label: 'Ignore mounts',
                value: config.ignoreMounts.join(', '),
              ),
            if (config.links.isNotEmpty)
              _InfoRow(label: 'Links', value: config.links.join('\n')),
            const Gap(8),
            Text(
              'Alerts & thresholds',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(8),
            _InfoRow(
              label: 'Unreachable',
              value: config.sendUnreachableAlerts ? 'On' : 'Off',
            ),
            _InfoRow(
              label: 'CPU alerts',
              value: config.sendCpuAlerts ? 'On' : 'Off',
            ),
            _InfoRow(
              label: 'Mem alerts',
              value: config.sendMemAlerts ? 'On' : 'Off',
            ),
            _InfoRow(
              label: 'Disk alerts',
              value: config.sendDiskAlerts ? 'On' : 'Off',
            ),
            _InfoRow(
              label: 'Version mismatch',
              value: config.sendVersionMismatchAlerts ? 'On' : 'Off',
            ),
            _InfoRow(
              label: 'CPU warn/crit',
              value:
                  '${config.cpuWarning.toStringAsFixed(0)}% / ${config.cpuCritical.toStringAsFixed(0)}%',
            ),
            _InfoRow(
              label: 'Mem warn/crit',
              value:
                  '${config.memWarning.toStringAsFixed(1)} GB / ${config.memCritical.toStringAsFixed(1)} GB',
            ),
            _InfoRow(
              label: 'Disk warn/crit',
              value:
                  '${config.diskWarning.toStringAsFixed(1)} GB / ${config.diskCritical.toStringAsFixed(1)} GB',
            ),
            if (config.maintenanceWindows.isNotEmpty) ...[
              const Gap(8),
              Text(
                'Maintenance windows',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Gap(8),
              for (final window in config.maintenanceWindows)
                _InfoRow(
                  label: window.enabled ? 'Enabled' : 'Disabled',
                  value:
                      '${window.name} • ${window.scheduleType.name} • ${window.hour.toString().padLeft(2, '0')}:${window.minute.toString().padLeft(2, '0')} (${window.timezone})',
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _StatsSample {
  const _StatsSample({
    required this.ts,
    required this.cpuPercent,
    required this.memPercent,
    required this.diskPercent,
    required this.ingressBytesPerSecond,
    required this.egressBytesPerSecond,
  });

  final DateTime ts;
  final double cpuPercent;
  final double memPercent;
  final double diskPercent;
  final double ingressBytesPerSecond;
  final double egressBytesPerSecond;
}

class _StatsHistoryCard extends StatelessWidget {
  const _StatsHistoryCard({required this.history, required this.latestStats});

  final List<_StatsSample> history;
  final SystemStats? latestStats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final uiRefreshSeconds = _estimateUiRefreshSeconds(history);
    final cpu = latestStats?.cpuPercent;
    final mem = latestStats?.memPercent;
    final disk = latestStats?.diskPercent;

    final cpuSeries = history.map((e) => e.cpuPercent).toList(growable: false);
    final memSeries = history.map((e) => e.memPercent).toList(growable: false);
    final diskSeries = history
        .map((e) => e.diskPercent)
        .toList(growable: false);
    final ingressSeries = history
        .map((e) => e.ingressBytesPerSecond)
        .toList(growable: false);
    final egressSeries = history
        .map((e) => e.egressBytesPerSecond)
        .toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stats',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(16),
            _HistoryRow(
              label: 'CPU',
              value: cpu != null ? '${cpu.toStringAsFixed(1)}%' : '—',
              child: _SparklineChart(
                values: cpuSeries,
                color: scheme.primary,
                capMinY: 0,
                capMaxY: 100,
              ),
            ),
            const Gap(12),
            _HistoryRow(
              label: 'Memory',
              value: mem != null ? '${mem.toStringAsFixed(1)}%' : '—',
              child: _SparklineChart(
                values: memSeries,
                color: scheme.secondary,
                capMinY: 0,
                capMaxY: 100,
              ),
            ),
            const Gap(12),
            _HistoryRow(
              label: 'Disk',
              value: disk != null ? '${disk.toStringAsFixed(1)}%' : '—',
              child: _SparklineChart(
                values: diskSeries,
                color: scheme.tertiary,
                capMinY: 0,
                capMaxY: 100,
              ),
            ),
            const Gap(16),
            Text(
              'Network',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const Gap(8),
            _HistoryRow(
              label: 'In / Out',
              value: history.isNotEmpty
                  ? '${formatBytesPerSecond(history.last.ingressBytesPerSecond)} / ${formatBytesPerSecond(history.last.egressBytesPerSecond)}'
                  : '—',
              child: _DualSparklineChart(
                aValues: ingressSeries,
                bValues: egressSeries,
                aColor: scheme.primary,
                bColor: scheme.secondary,
              ),
            ),
            const Gap(12),
            _InfoRow(
              label: 'UI refresh',
              value: uiRefreshSeconds != null
                  ? '~${uiRefreshSeconds.toStringAsFixed(1)} s'
                  : '—',
            ),
            if (latestStats?.pollingRate?.isNotEmpty ?? false)
              _InfoRow(
                label: 'Server polling',
                value: latestStats!.pollingRate!,
              ),
          ],
        ),
      ),
    );
  }

  double? _estimateUiRefreshSeconds(List<_StatsSample> history) {
    if (history.length < 2) return null;

    final startIndex = (history.length - 6).clamp(0, history.length - 2);
    var sumSeconds = 0.0;
    var count = 0;

    for (var i = startIndex; i < history.length - 1; i++) {
      final dtMs = history[i + 1].ts.difference(history[i].ts).inMilliseconds;
      if (dtMs <= 0) continue;
      sumSeconds += dtMs / 1000.0;
      count++;
    }

    if (count == 0) return null;
    return sumSeconds / count;
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.label,
    required this.value,
    required this.child,
  });

  final String label;
  final String value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const Gap(6),
        SizedBox(height: 56, child: child),
      ],
    );
  }
}

class _SparklineChart extends StatelessWidget {
  const _SparklineChart({
    required this.values,
    required this.color,
    this.capMinY,
    this.capMaxY,
  });

  final List<double> values;
  final Color color;
  final double? capMinY;
  final double? capMaxY;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _SparklinePainter(
        values: values,
        color: color,
        gridColor: scheme.outlineVariant.withValues(alpha: 0.6),
        capMinY: capMinY,
        capMaxY: capMaxY,
      ),
    );
  }
}

class _DualSparklineChart extends StatelessWidget {
  const _DualSparklineChart({
    required this.aValues,
    required this.bValues,
    required this.aColor,
    required this.bColor,
  });

  final List<double> aValues;
  final List<double> bValues;
  final Color aColor;
  final Color bColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _DualSparklinePainter(
        aValues: aValues,
        bValues: bValues,
        aColor: aColor,
        bColor: bColor,
        gridColor: scheme.outlineVariant.withValues(alpha: 0.6),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.gridColor,
    this.capMinY,
    this.capMaxY,
  });

  final List<double> values;
  final Color color;
  final Color gridColor;
  final double? capMinY;
  final double? capMaxY;

  @override
  void paint(Canvas canvas, Size size) {
    const padding = 6.0;
    final rect = Rect.fromLTWH(
      padding,
      padding,
      size.width - padding * 2,
      size.height - padding * 2,
    );

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final y in [0.0, 0.5, 1.0]) {
      final dy = rect.bottom - rect.height * y;
      canvas.drawLine(Offset(rect.left, dy), Offset(rect.right, dy), gridPaint);
    }

    if (values.length < 2) return;

    final rawMin = values.reduce((a, b) => a < b ? a : b);
    final rawMax = values.reduce((a, b) => a > b ? a : b);

    final range = (rawMax - rawMin).abs();

    var paddedMin = rawMin;
    var paddedMax = rawMax;
    var pad = range * 0.12;
    if (pad < 1e-6) {
      pad = 1;
    }
    paddedMin -= pad;
    paddedMax += pad;

    if (capMinY != null) {
      paddedMin = paddedMin < capMinY! ? capMinY! : paddedMin;
    }
    if (capMaxY != null) {
      paddedMax = paddedMax > capMaxY! ? capMaxY! : paddedMax;
    }

    if (paddedMax - paddedMin < 1e-9) {
      paddedMax = paddedMin + 1;
    }

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final t = i / (values.length - 1);
      final x = rect.left + rect.width * t;
      final normalized = (values[i] - paddedMin) / (paddedMax - paddedMin);
      final y = rect.bottom - rect.height * normalized.clamp(0, 1);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.capMinY != capMinY ||
        oldDelegate.capMaxY != capMaxY;
  }
}

class _DualSparklinePainter extends CustomPainter {
  _DualSparklinePainter({
    required this.aValues,
    required this.bValues,
    required this.aColor,
    required this.bColor,
    required this.gridColor,
  });

  final List<double> aValues;
  final List<double> bValues;
  final Color aColor;
  final Color bColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const padding = 6.0;
    final rect = Rect.fromLTWH(
      padding,
      padding,
      size.width - padding * 2,
      size.height - padding * 2,
    );

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final y in [0.0, 0.5, 1.0]) {
      final dy = rect.bottom - rect.height * y;
      canvas.drawLine(Offset(rect.left, dy), Offset(rect.right, dy), gridPaint);
    }

    if (aValues.length < 2 || bValues.length < 2) return;

    var localMin = aValues.first;
    var localMax = aValues.first;

    for (final v in aValues) {
      if (v < localMin) localMin = v;
      if (v > localMax) localMax = v;
    }
    for (final v in bValues) {
      if (v < localMin) localMin = v;
      if (v > localMax) localMax = v;
    }
    if (localMax - localMin < 1e-9) {
      localMax = localMin + 1;
    }

    void drawLine(List<double> values, Color color) {
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final t = i / (values.length - 1);
        final x = rect.left + rect.width * t;
        final normalized = (values[i] - localMin) / (localMax - localMin);
        final y = rect.bottom - rect.height * normalized.clamp(0, 1);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, linePaint);
    }

    drawLine(aValues, aColor);
    drawLine(bValues, bColor);
  }

  @override
  bool shouldRepaint(covariant _DualSparklinePainter oldDelegate) {
    return oldDelegate.aValues != aValues ||
        oldDelegate.bValues != bValues ||
        oldDelegate.aColor != aColor ||
        oldDelegate.bColor != bColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
