import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/utils/byte_format.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/segmented/app_segmented_control.dart';
import 'package:komodo_go/features/servers/data/models/system_stats.dart';

class StatsHistoryContent extends StatelessWidget {
  const StatsHistoryContent({
    required this.history,
    required this.latestStats,
    required this.granularity,
    required this.useFixedPercentScale,
    required this.onGranularityChanged,
    required this.onScaleChanged,
    super.key,
  });

  final List<HistoricalSystemStats> history;
  final SystemStats? latestStats;
  final ServerStatsGranularity granularity;
  final bool useFixedPercentScale;
  final ValueChanged<ServerStatsGranularity> onGranularityChanged;
  final ValueChanged<bool> onScaleChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final latestStats = this.latestStats;

    final cpu = latestStats?.cpuPercent;
    final mem = latestStats?.memPercent;
    final disk = latestStats?.diskPercent;

    final visibleHistory = [...history]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final cpuSeries = visibleHistory
        .map((e) => e.cpuPercent)
        .toList(growable: false);
    final memSeries = visibleHistory
        .map((e) => e.memPercent)
        .toList(growable: false);
    final diskSeries = visibleHistory
        .map((e) => e.diskPercent)
        .toList(growable: false);
    final networkSeries = _networkRates(visibleHistory);
    final ingressSeries = networkSeries.ingress;
    final egressSeries = networkSeries.egress;

    final textTheme = Theme.of(context).textTheme;
    final percentMin = useFixedPercentScale ? 0.0 : null;
    final percentMax = useFixedPercentScale ? 100.0 : null;

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
        const Gap(8),
        Text(
          'Sample interval',
          style: textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Gap(6),
        SizedBox(
          width: double.infinity,
          child: AppSegmentedControl<ServerStatsGranularity>(
            segments: [
              for (final value in ServerStatsGranularity.values)
                AppSegmentOption(value: value, label: value.label),
            ],
            value: granularity,
            onChanged: onGranularityChanged,
          ),
        ),
        const Gap(8),
        Row(
          children: [
            Text(
              'Scale',
              style: textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              useFixedPercentScale ? '0-100%' : 'Auto',
              style: textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const Gap(8),
            Switch.adaptive(
              value: useFixedPercentScale,
              onChanged: onScaleChanged,
            ),
          ],
        ),
        const Gap(12),
        if (cpuSeries.isNotEmpty)
          DetailHistoryRow(
            label: 'CPU',
            value: cpu != null ? '${cpu.toStringAsFixed(0)}%' : '—',
            child: SparklineChart(
              values: cpuSeries,
              color: scheme.primary,
              capMinY: percentMin,
              capMaxY: percentMax,
            ),
          )
        else
          Text(
            'No historical samples yet. Enable stats monitoring on this server '
            'and Komodo will retain database-backed samples here.',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        const Gap(12),
        if (memSeries.isNotEmpty)
          DetailHistoryRow(
            label: 'Memory',
            value: mem != null ? '${mem.toStringAsFixed(0)}%' : '—',
            child: SparklineChart(
              values: memSeries,
              color: scheme.primary,
              capMinY: percentMin,
              capMaxY: percentMax,
            ),
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
            child: SparklineChart(
              values: diskSeries,
              color: scheme.primary,
              capMinY: percentMin,
              capMaxY: percentMax,
            ),
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
              ? '${formatBytesPerSecond(ingressSeries.isEmpty ? 0 : ingressSeries.last)} / ${formatBytesPerSecond(egressSeries.isEmpty ? 0 : egressSeries.last)}'
              : '—',
          child: DualSparklineChart(
            aValues: ingressSeries,
            bValues: egressSeries,
            aColor: scheme.primary,
            bColor: scheme.secondary,
          ),
        ),
        const Gap(12),
        if (latestStats?.disks.isNotEmpty ?? false) ...[
          const Divider(),
          const Gap(8),
          Text(
            'Disks',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(10),
          for (final disk in latestStats!.disks) ...[
            _DiskUsageCard(
              disk: disk,
              history: visibleHistory,
            ),
            const Gap(10),
          ],
        ],
        if (latestStats?.pollingRate?.isNotEmpty ?? false)
          DetailKeyValueRow(
            label: 'Server polling',
            value: latestStats!.pollingRate!,
            bottomPadding: 0,
          ),
      ],
    );
  }

  ({List<double> ingress, List<double> egress}) _networkRates(
    List<HistoricalSystemStats> history,
  ) {
    if (history.isEmpty) return (ingress: const [], egress: const []);
    final ingress = <double>[0];
    final egress = <double>[0];
    for (var index = 1; index < history.length; index++) {
      final previous = history[index - 1];
      final current = history[index];
      final seconds =
          current.timestamp.difference(previous.timestamp).inMilliseconds /
          1000;
      if (seconds <= 0) {
        ingress.add(0);
        egress.add(0);
        continue;
      }
      final ingressDelta =
          current.networkIngressBytes - previous.networkIngressBytes;
      final egressDelta =
          current.networkEgressBytes - previous.networkEgressBytes;
      ingress.add(ingressDelta >= 0 ? ingressDelta / seconds : 0);
      egress.add(egressDelta >= 0 ? egressDelta / seconds : 0);
    }
    return (ingress: ingress, egress: egress);
  }
}

class _DiskUsageCard extends StatelessWidget {
  const _DiskUsageCard({required this.disk, required this.history});

  final SingleDiskUsage disk;
  final List<HistoricalSystemStats> history;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final freeGb = (disk.totalGb - disk.usedGb).clamp(0, double.infinity);
    final percent = disk.totalGb > 0 ? disk.usedGb / disk.totalGb * 100 : 0.0;
    final values = <double>[];
    for (final sample in history) {
      for (final historicalDisk in sample.disks) {
        if (historicalDisk.mount == disk.mount && historicalDisk.totalGb > 0) {
          values.add(historicalDisk.usedGb / historicalDisk.totalGb * 100);
          break;
        }
      }
    }

    return DetailSubCard(
      title: disk.mount.isEmpty ? 'Unknown mount' : disk.mount,
      icon: AppIcons.hardDrive,
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ValuePill(
                label: 'Filesystem',
                value: disk.fileSystem.isEmpty ? '—' : disk.fileSystem,
              ),
              ValuePill(
                label: 'Used',
                value: '${disk.usedGb.toStringAsFixed(1)} GB',
              ),
              ValuePill(
                label: 'Free',
                value: '${freeGb.toStringAsFixed(1)} GB',
              ),
              ValuePill(
                label: 'Total',
                value: '${disk.totalGb.toStringAsFixed(1)} GB',
              ),
            ],
          ),
          const Gap(10),
          LinearProgressIndicator(
            value: (percent / 100).clamp(0, 1),
            minHeight: 7,
            borderRadius: BorderRadius.circular(999),
          ),
          if (values.isNotEmpty) ...[
            const Gap(10),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: SparklineChart(
                values: values,
                color: scheme.primary,
                capMinY: 0,
                capMaxY: 100,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
