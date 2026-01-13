import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/utils/byte_format.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/data/models/system_information.dart';
import 'package:komodo_go/features/servers/data/models/system_stats.dart';

class ServerHeroPanel extends StatelessWidget {
  const ServerHeroPanel({
    required this.server,
    required this.listServer,
    required this.stats,
    required this.systemInformation,
    required this.ingressBytesPerSecond,
    required this.egressBytesPerSecond,
    super.key,
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

    return DetailHeroPanel(
      tintColor: scheme.primary,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (address?.isNotEmpty ?? false) ...[
            DetailIconInfoRow(
              icon: AppIcons.network,
              label: 'Address',
              value: address!,
            ),
            const Gap(10),
          ],
          if (description?.isNotEmpty ?? false)
            DetailIconInfoRow(
              icon: AppIcons.tag,
              label: 'Description',
              value: description!,
            ),
        ],
      ),
      metrics: [
        DetailMetricTileData(
          icon: AppIcons.ok,
          label: 'Version',
          value: (version?.isNotEmpty ?? false) ? version! : '—',
          tone: DetailMetricTone.success,
        ),
        DetailMetricTileData(
          icon: AppIcons.cpu,
          label: 'Cores',
          value: cores != null ? cores.toString() : '—',
          tone: DetailMetricTone.neutral,
        ),
        DetailMetricTileData(
          icon: AppIcons.activity,
          label: 'Load (1m)',
          value: load != null ? load.toStringAsFixed(2) : '—',
          progress: loadPercent,
          tone: DetailMetricTone.primary,
        ),
        DetailMetricTileData(
          icon: AppIcons.memory,
          label: 'Memory',
          value: memUsed != null && memTotal != null && memTotal > 0
              ? '${memUsed.toStringAsFixed(1)} / ${memTotal.toStringAsFixed(1)} GB'
              : '—',
          progress: memPercent,
          tone: DetailMetricTone.secondary,
        ),
        DetailMetricTileData(
          icon: AppIcons.hardDrive,
          label: 'Disk',
          value: diskUsed != null && diskTotal != null && diskTotal > 0
              ? _formatDiskUsage(usedGb: diskUsed, totalGb: diskTotal)
              : '—',
          progress: diskPercent,
          tone: DetailMetricTone.tertiary,
        ),
        DetailMetricTileData(
          icon: AppIcons.wifi,
          label: 'Net (in/out)',
          value: ingressBytesPerSecond != null && egressBytesPerSecond != null
              ? '${formatBytesPerSecond(ingressBytesPerSecond!)} / ${formatBytesPerSecond(egressBytesPerSecond!)}'
              : '—',
          tone: DetailMetricTone.neutral,
        ),
      ],
      footer: server?.tags.isNotEmpty ?? false
          ? DetailPillList(items: server!.tags, emptyLabel: 'No tags')
          : null,
    );
  }

  String _formatDiskUsage({required double usedGb, required double totalGb}) {
    final showTb = usedGb >= 1024 || totalGb >= 1024;
    if (!showTb) {
      final used = usedGb.toStringAsFixed(1);
      final total = totalGb.toStringAsFixed(1);
      return '$used/$total GB';
    }

    final usedTb = usedGb / 1024;
    final totalTb = totalGb / 1024;

    String fmt(double v) {
      if (v < 10) return v.toStringAsFixed(2);
      if (v < 100) return v.toStringAsFixed(1);
      return v.toStringAsFixed(0);
    }

    final used = fmt(usedTb);
    final total = fmt(totalTb);
    return '$used/$total TB';
  }
}

class ServerSystemInfoContent extends StatelessWidget {
  const ServerSystemInfoContent({required this.info, super.key});

  final SystemInformation info;

  @override
  Widget build(BuildContext context) {
    final isLockedDown = info.terminalsDisabled || info.containerExecDisabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailSubCard(
          title: 'Basics',
          icon: AppIcons.server,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (info.name?.isNotEmpty ?? false)
                ValuePill(label: 'Name', value: info.name!),
              if (info.hostName?.isNotEmpty ?? false)
                ValuePill(label: 'Host', value: info.hostName!),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'OS',
          icon: AppIcons.settings,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (info.os?.isNotEmpty ?? false)
                ValuePill(label: 'OS', value: info.os!),
              if (info.kernel?.isNotEmpty ?? false)
                ValuePill(label: 'Kernel', value: info.kernel!),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Hardware',
          icon: AppIcons.cpu,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (info.cpuBrand.isNotEmpty)
                ValuePill(label: 'CPU', value: info.cpuBrand),
              if (info.coreCount != null)
                ValuePill(label: 'Cores', value: info.coreCount.toString()),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Access',
          icon: AppIcons.lock,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill.onOff(
                isOn: !info.terminalsDisabled,
                onLabel: 'Terminal enabled',
                offLabel: 'Terminal disabled',
                onIcon: AppIcons.ok,
                offIcon: AppIcons.warning,
                offTone: PillTone.warning,
              ),
              StatusPill.onOff(
                isOn: !info.containerExecDisabled,
                onLabel: 'Exec enabled',
                offLabel: 'Exec disabled',
                onIcon: AppIcons.ok,
                offIcon: AppIcons.warning,
                offTone: PillTone.warning,
              ),
              StatusPill(
                label: isLockedDown ? 'Locked down' : 'Operational',
                icon: isLockedDown ? AppIcons.warning : AppIcons.ok,
                tone: isLockedDown ? PillTone.warning : PillTone.success,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ServerConfigContent extends StatelessWidget {
  const ServerConfigContent({required this.config, super.key});

  final ServerConfig config;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final enabledPill = StatusPill.onOff(
      isOn: config.enabled,
      onLabel: 'Enabled',
      offLabel: 'Disabled',
      onIcon: AppIcons.ok,
      offIcon: AppIcons.close,
      offTone: PillTone.alert,
    );
    final statsMonitoringPill = StatusPill.onOff(
      isOn: config.statsMonitoring,
      onLabel: 'Monitoring on',
      offLabel: 'Monitoring off',
      onIcon: AppIcons.ok,
      offIcon: AppIcons.warning,
      offTone: PillTone.warning,
    );
    final autoPrunePill = StatusPill.onOff(
      isOn: config.autoPrune,
      onLabel: 'Auto prune on',
      offLabel: 'Auto prune off',
      onIcon: AppIcons.ok,
      offIcon: AppIcons.unknown,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            enabledPill,
            statsMonitoringPill,
            autoPrunePill,
            if (config.passkey.isNotEmpty)
              const StatusPill(
                label: 'Passkey set',
                icon: AppIcons.key,
                tone: PillTone.success,
              )
            else
              const StatusPill(
                label: 'No passkey',
                icon: AppIcons.lock,
                tone: PillTone.neutral,
              ),
          ],
        ),
        const Gap(14),
        DetailSubCard(
          title: 'Connection',
          icon: AppIcons.network,
          child: Column(
            children: [
              DetailKeyValueRow(
                label: 'Address',
                value: config.address.isNotEmpty ? config.address : '—',
              ),
              DetailKeyValueRow(
                label: 'External',
                value: config.externalAddress.isNotEmpty
                    ? config.externalAddress
                    : '—',
              ),
              DetailKeyValueRow(
                label: 'Region',
                value: config.region.isNotEmpty ? config.region : '—',
              ),
              DetailKeyValueRow(
                label: 'Timeout',
                value: config.timeoutSeconds > 0
                    ? '${config.timeoutSeconds}s'
                    : '—',
              ),
              if (config.links.isNotEmpty)
                DetailKeyValueRow(
                  label: 'Links',
                  value: config.links.join('\n'),
                ),
              if (config.ignoreMounts.isNotEmpty)
                DetailKeyValueRow(
                  label: 'Ignore mounts',
                  value: config.ignoreMounts.join(', '),
                ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Alerts',
          icon: AppIcons.notifications,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill.onOff(
                isOn: config.sendUnreachableAlerts,
                onLabel: 'Unreachable alerts',
                offLabel: 'Unreachable alerts',
                onIcon: AppIcons.ok,
                offIcon: AppIcons.warning,
                offTone: PillTone.warning,
              ),
              StatusPill.onOff(
                isOn: config.sendCpuAlerts,
                onLabel: 'CPU alerts',
                offLabel: 'CPU alerts',
                onIcon: AppIcons.ok,
                offIcon: AppIcons.warning,
                offTone: PillTone.warning,
              ),
              StatusPill.onOff(
                isOn: config.sendMemAlerts,
                onLabel: 'Memory alerts',
                offLabel: 'Memory alerts',
                onIcon: AppIcons.ok,
                offIcon: AppIcons.warning,
                offTone: PillTone.warning,
              ),
              StatusPill.onOff(
                isOn: config.sendDiskAlerts,
                onLabel: 'Disk alerts',
                offLabel: 'Disk alerts',
                onIcon: AppIcons.ok,
                offIcon: AppIcons.warning,
                offTone: PillTone.warning,
              ),
              StatusPill.onOff(
                isOn: config.sendVersionMismatchAlerts,
                onLabel: 'Version mismatch',
                offLabel: 'Version mismatch',
                onIcon: AppIcons.ok,
                offIcon: AppIcons.warning,
                offTone: PillTone.warning,
              ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Thresholds',
          icon: AppIcons.warning,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CPU',
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ValuePill(
                    label: 'Warn',
                    value: '${config.cpuWarning.toStringAsFixed(0)}%',
                  ),
                  ValuePill(
                    label: 'Crit',
                    value: '${config.cpuCritical.toStringAsFixed(0)}%',
                  ),
                ],
              ),
              const Gap(10),
              Text(
                'Memory',
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ValuePill(
                    label: 'Warn',
                    value: '${config.memWarning.toStringAsFixed(1)} GB',
                  ),
                  ValuePill(
                    label: 'Crit',
                    value: '${config.memCritical.toStringAsFixed(1)} GB',
                  ),
                ],
              ),
              const Gap(10),
              Text(
                'Disk',
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ValuePill(
                    label: 'Warn',
                    value: '${config.diskWarning.toStringAsFixed(1)} GB',
                  ),
                  ValuePill(
                    label: 'Crit',
                    value: '${config.diskCritical.toStringAsFixed(1)} GB',
                  ),
                ],
              ),
            ],
          ),
        ),
        if (config.maintenanceWindows.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Maintenance',
            icon: AppIcons.maintenance,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final window in config.maintenanceWindows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusPill.onOff(
                          isOn: window.enabled,
                          onLabel: 'Enabled',
                          offLabel: 'Disabled',
                          onIcon: AppIcons.ok,
                          offIcon: AppIcons.close,
                        ),
                        ValuePill(label: 'Name', value: window.name),
                        ValuePill(
                          label: 'Type',
                          value: window.scheduleType.name,
                        ),
                        ValuePill(
                          label: 'At',
                          value:
                              '${window.hour.toString().padLeft(2, '0')}:${window.minute.toString().padLeft(2, '0')}',
                        ),
                        ValuePill(label: 'TZ', value: window.timezone),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class ServerMessageCard extends StatelessWidget {
  const ServerMessageCard({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCardSurface(
      padding: const EdgeInsets.all(16),
      child: Text(message),
    );
  }
}

class ServerLoadingCard extends StatelessWidget {
  const ServerLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppCardSurface(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class StatsSample {
  const StatsSample({
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

class StatsHistoryContent extends StatelessWidget {
  const StatsHistoryContent({
    required this.history,
    required this.latestStats,
    super.key,
  });

  final List<StatsSample> history;
  final SystemStats? latestStats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final uiRefreshSeconds = _estimateUiRefreshSeconds(history);
    final cpu = latestStats?.cpuPercent;
    final mem = latestStats?.memPercent;
    final disk = latestStats?.diskPercent;

    const windowSamples = 60; // ~2.5 min @ 2.5s refresh
    final visibleHistory = history.length > windowSamples
        ? history.sublist(history.length - windowSamples)
        : history;

    final cpuSeries = visibleHistory
        .map((e) => e.cpuPercent)
        .toList(growable: false);
    final memSeries = visibleHistory
        .map((e) => e.memPercent)
        .toList(growable: false);
    final diskSeries = visibleHistory
        .map((e) => e.diskPercent)
        .toList(growable: false);
    final ingressSeries = visibleHistory
        .map((e) => e.ingressBytesPerSecond)
        .toList(growable: false);
    final egressSeries = visibleHistory
        .map((e) => e.egressBytesPerSecond)
        .toList(growable: false);

    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ValuePill(
              label: 'CPU',
              value: cpu != null ? '${cpu.toStringAsFixed(0)}%' : '—',
            ),
            ValuePill(
              label: 'Mem',
              value: mem != null ? '${mem.toStringAsFixed(0)}%' : '—',
            ),
            ValuePill(
              label: 'Disk',
              value: disk != null ? '${disk.toStringAsFixed(0)}%' : '—',
            ),
            if (latestStats?.loadAverage?.one != null)
              ValuePill(
                label: 'Load',
                value: latestStats!.loadAverage!.one.toStringAsFixed(2),
              ),
          ],
        ),
        const Gap(12),
        if (cpuSeries.isNotEmpty)
          DetailHistoryRow(
            label: 'CPU',
            value: cpu != null ? '${cpu.toStringAsFixed(0)}%' : '—',
            child: SparklineChart(values: cpuSeries, color: scheme.primary),
          )
        else
          Text(
            'Not enough data to chart CPU usage',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        const Gap(12),
        if (memSeries.isNotEmpty)
          DetailHistoryRow(
            label: 'Memory',
            value: mem != null ? '${mem.toStringAsFixed(0)}%' : '—',
            child: SparklineChart(values: memSeries, color: scheme.secondary),
          )
        else
          Text(
            'Not enough data to chart memory usage',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        const Gap(12),
        if (diskSeries.isNotEmpty)
          DetailHistoryRow(
            label: 'Disk',
            value: disk != null ? '${disk.toStringAsFixed(0)}%' : '—',
            child: SparklineChart(values: diskSeries, color: scheme.tertiary),
          )
        else
          Text(
            'Not enough data to chart disk usage',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        const Gap(12),
        DetailHistoryRow(
          label: 'In / Out',
          value: history.isNotEmpty
              ? '${formatBytesPerSecond(history.last.ingressBytesPerSecond)} / ${formatBytesPerSecond(history.last.egressBytesPerSecond)}'
              : '—',
          child: DualSparklineChart(
            aValues: ingressSeries,
            bValues: egressSeries,
            aColor: scheme.primary,
            bColor: scheme.secondary,
          ),
        ),
        const Gap(12),
        DetailKeyValueRow(
          label: 'UI refresh',
          value: uiRefreshSeconds != null
              ? '~${uiRefreshSeconds.toStringAsFixed(1)} s'
              : '—',
        ),
        if (latestStats?.pollingRate?.isNotEmpty ?? false)
          DetailKeyValueRow(
            label: 'Server polling',
            value: latestStats!.pollingRate!,
            bottomPadding: 0,
          ),
      ],
    );
  }

  double? _estimateUiRefreshSeconds(List<StatsSample> history) {
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
