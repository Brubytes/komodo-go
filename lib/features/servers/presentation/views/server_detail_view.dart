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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            _ServerHeroPanel(
              server: server ?? listServer,
              listServer: listServer,
              stats: stats,
              systemInformation: systemInformation,
              ingressBytesPerSecond: _ingressBytesPerSecond,
              egressBytesPerSecond: _egressBytesPerSecond,
            ),
            const Gap(16),
            statsAsync.when(
              data: (stats) => _DetailSection(
                title: 'Stats',
                icon: AppIcons.activity,
                child: _StatsHistoryContent(
                  history: _history,
                  latestStats: stats,
                ),
              ),
              loading: () => const _LoadingCard(),
              error: (error, _) =>
                  _MessageCard(message: 'Stats unavailable: $error'),
            ),
            const Gap(16),
            serverAsync.when(
              data: (server) => server?.config != null
                  ? _DetailSection(
                      title: 'Config',
                      icon: AppIcons.settings,
                      tone: _SectionTone.secondary,
                      child: _ServerConfigContent(config: server!.config!),
                    )
                  : const _MessageCard(message: 'No config available'),
              loading: () => const _LoadingCard(),
              error: (error, _) => _MessageCard(message: 'Config: $error'),
            ),
            const Gap(16),
            systemInfoAsync.when(
              data: (info) => info != null
                  ? _DetailSection(
                      title: 'System',
                      icon: AppIcons.server,
                      tone: _SectionTone.tertiary,
                      child: _SystemInfoContent(info: info),
                    )
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

class _ServerHeroPanel extends StatelessWidget {
  const _ServerHeroPanel({
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? scheme.surfaceContainer
            : Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.06),
                scheme.surfaceContainer,
              ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant),
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary.withValues(alpha: 0.14),
                  scheme.secondary.withValues(alpha: 0.10),
                  scheme.surfaceContainer,
                ],
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (address?.isNotEmpty ?? false) ...[
            _HeroInfoRow(
              icon: AppIcons.network,
              label: 'Address',
              value: address!,
            ),
            const Gap(10),
          ],
          if (description?.isNotEmpty ?? false) ...[
            _HeroInfoRow(
              icon: AppIcons.tag,
              label: 'Description',
              value: description!,
            ),
            const Gap(12),
          ],
          _MetricGrid(
            items: [
              _MetricTileData(
                icon: AppIcons.ok,
                label: 'Version',
                value: (version?.isNotEmpty ?? false) ? version! : '—',
                tone: _MetricTone.success,
              ),
              _MetricTileData(
                icon: AppIcons.cpu,
                label: 'Cores',
                value: cores != null ? cores.toString() : '—',
                tone: _MetricTone.neutral,
              ),
              _MetricTileData(
                icon: AppIcons.activity,
                label: 'Load (1m)',
                value: load != null ? load.toStringAsFixed(2) : '—',
                progress: loadPercent,
                tone: _MetricTone.primary,
              ),
              _MetricTileData(
                icon: AppIcons.memory,
                label: 'Memory',
                value: memUsed != null && memTotal != null && memTotal > 0
                    ? '${memUsed.toStringAsFixed(1)} / ${memTotal.toStringAsFixed(1)} GB'
                    : '—',
                progress: memPercent,
                tone: _MetricTone.secondary,
              ),
              _MetricTileData(
                icon: AppIcons.hardDrive,
                label: 'Disk',
                value: diskUsed != null && diskTotal != null && diskTotal > 0
                    ? '${diskUsed.toStringAsFixed(1)} / ${diskTotal.toStringAsFixed(1)} GB'
                    : '—',
                progress: diskPercent,
                tone: _MetricTone.tertiary,
              ),
              _MetricTileData(
                icon: AppIcons.wifi,
                label: 'Net (in/out)',
                value:
                    ingressBytesPerSecond != null &&
                        egressBytesPerSecond != null
                    ? '${formatBytesPerSecond(ingressBytesPerSecond!)} / ${formatBytesPerSecond(egressBytesPerSecond!)}'
                    : '—',
                tone: _MetricTone.neutral,
              ),
            ],
          ),
          if (server?.tags.isNotEmpty ?? false) ...[
            const Gap(12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final tag in server!.tags) _TagPill(text: tag)],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.child,
    this.tone = _SectionTone.primary,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final _SectionTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (Color accent, Color accent2) = switch (tone) {
      _SectionTone.primary => (scheme.primary, scheme.secondary),
      _SectionTone.secondary => (scheme.secondary, scheme.primary),
      _SectionTone.tertiary => (scheme.tertiary, scheme.primary),
    };

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? scheme.surfaceContainer
            : Color.alphaBlend(
                accent.withValues(alpha: 0.06),
                scheme.surfaceContainer,
              ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant),
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.10),
                  accent2.withValues(alpha: 0.08),
                  scheme.surfaceContainer,
                ],
              )
            : null,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const Gap(12),
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const Gap(14),
          child,
        ],
      ),
    );
  }
}

enum _SectionTone { primary, secondary, tertiary }

class _HeroInfoRow extends StatelessWidget {
  const _HeroInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Icon(icon, size: 18, color: scheme.primary),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Gap(2),
              Text(
                value,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

enum _MetricTone { primary, secondary, tertiary, success, neutral }

class _SubCard extends StatelessWidget {
  const _SubCard({
    required this.title,
    required this.icon,
    required this.tone,
    required this.child,
  });

  final String title;
  final IconData icon;
  final _SectionTone tone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final accent = switch (tone) {
      _SectionTone.primary => scheme.primary,
      _SectionTone.secondary => scheme.secondary,
      _SectionTone.tertiary => scheme.tertiary,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const Gap(10),
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const Gap(12),
          child,
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.background,
    required this.icon,
  });

  factory _StatusPill.onOff({
    required bool isOn,
    required String onLabel,
    required String offLabel,
  }) {
    return _StatusPill(
      label: isOn ? onLabel : offLabel,
      color: isOn ? const Color(0xFF014226) : const Color(0xFF8C1D1D),
      background: isOn ? const Color(0x1A4EB333) : const Color(0x1ADF2C2C),
      icon: isOn ? AppIcons.ok : AppIcons.error,
    );
  }

  final String label;
  final Color color;
  final Color background;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const Gap(6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(6),
          Text(
            value,
            style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _MetricTileData {
  const _MetricTileData({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    this.progress,
  });

  final IconData icon;
  final String label;
  final String value;
  final double? progress;
  final _MetricTone tone;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});

  final List<_MetricTileData> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 520 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
          ),
          itemBuilder: (context, index) => _MetricTile(item: items[index]),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.item});

  final _MetricTileData item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final (Color accent, Color accentContainer) = switch (item.tone) {
      _MetricTone.primary => (scheme.primary, scheme.primaryContainer),
      _MetricTone.secondary => (scheme.secondary, scheme.secondaryContainer),
      _MetricTone.tertiary => (scheme.tertiary, scheme.tertiaryContainer),
      _MetricTone.success => (scheme.secondary, scheme.secondaryContainer),
      _MetricTone.neutral => (
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHigh,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentContainer.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Icon(item.icon, size: 18, color: accent),
              ),
              const Gap(10),
              Expanded(
                child: Text(
                  item.label,
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            item.value,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (item.progress != null) ...[
            const Gap(10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: item.progress!.clamp(0, 1),
                minHeight: 6,
                backgroundColor: scheme.onSurfaceVariant.withValues(
                  alpha: 0.10,
                ),
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SystemInfoContent extends StatelessWidget {
  const _SystemInfoContent({required this.info});

  final SystemInformation info;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubCard(
          title: 'Basics',
          icon: AppIcons.server,
          tone: _SectionTone.primary,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (info.name?.isNotEmpty ?? false)
                _ValuePill(label: 'Name', value: info.name!),
              if (info.hostName?.isNotEmpty ?? false)
                _ValuePill(label: 'Host', value: info.hostName!),
            ],
          ),
        ),
        const Gap(12),
        _SubCard(
          title: 'OS',
          icon: AppIcons.settings,
          tone: _SectionTone.secondary,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (info.os?.isNotEmpty ?? false)
                _ValuePill(label: 'OS', value: info.os!),
              if (info.kernel?.isNotEmpty ?? false)
                _ValuePill(label: 'Kernel', value: info.kernel!),
            ],
          ),
        ),
        const Gap(12),
        _SubCard(
          title: 'Hardware',
          icon: AppIcons.cpu,
          tone: _SectionTone.tertiary,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (info.cpuBrand.isNotEmpty)
                _ValuePill(label: 'CPU', value: info.cpuBrand),
              if (info.coreCount != null)
                _ValuePill(label: 'Cores', value: info.coreCount.toString()),
            ],
          ),
        ),
        const Gap(12),
        _SubCard(
          title: 'Access',
          icon: AppIcons.lock,
          tone: _SectionTone.secondary,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill.onOff(
                isOn: !info.terminalsDisabled,
                onLabel: 'Terminal enabled',
                offLabel: 'Terminal disabled',
              ),
              _StatusPill.onOff(
                isOn: !info.containerExecDisabled,
                onLabel: 'Exec enabled',
                offLabel: 'Exec disabled',
              ),
              _StatusPill(
                label: info.terminalsDisabled ? 'Locked down' : 'Operational',
                color: scheme.primary,
                background: scheme.primaryContainer.withValues(alpha: 0.55),
                icon: AppIcons.ok,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServerConfigContent extends StatelessWidget {
  const _ServerConfigContent({required this.config});

  final ServerConfig config;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final enabledPill = _StatusPill.onOff(
      isOn: config.enabled,
      onLabel: 'Enabled',
      offLabel: 'Disabled',
    );
    final statsMonitoringPill = _StatusPill.onOff(
      isOn: config.statsMonitoring,
      onLabel: 'Monitoring on',
      offLabel: 'Monitoring off',
    );
    final autoPrunePill = _StatusPill.onOff(
      isOn: config.autoPrune,
      onLabel: 'Auto prune on',
      offLabel: 'Auto prune off',
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
              _StatusPill(
                label: 'Passkey set',
                color: scheme.primary,
                background: scheme.primaryContainer.withValues(alpha: 0.55),
                icon: AppIcons.key,
              )
            else
              _StatusPill(
                label: 'No passkey',
                color: scheme.onSurfaceVariant,
                background: scheme.surfaceContainerHigh,
                icon: AppIcons.lock,
              ),
          ],
        ),
        const Gap(14),
        _SubCard(
          title: 'Connection',
          icon: AppIcons.network,
          tone: _SectionTone.secondary,
          child: Column(
            children: [
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
                label: 'Region',
                value: config.region.isNotEmpty ? config.region : '—',
              ),
              _InfoRow(
                label: 'Timeout',
                value: config.timeoutSeconds > 0
                    ? '${config.timeoutSeconds}s'
                    : '—',
              ),
              if (config.links.isNotEmpty)
                _InfoRow(label: 'Links', value: config.links.join('\n')),
              if (config.ignoreMounts.isNotEmpty)
                _InfoRow(
                  label: 'Ignore mounts',
                  value: config.ignoreMounts.join(', '),
                ),
            ],
          ),
        ),
        const Gap(12),
        _SubCard(
          title: 'Alerts',
          icon: AppIcons.notifications,
          tone: _SectionTone.primary,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill.onOff(
                isOn: config.sendUnreachableAlerts,
                onLabel: 'Unreachable alerts',
                offLabel: 'Unreachable alerts',
              ),
              _StatusPill.onOff(
                isOn: config.sendCpuAlerts,
                onLabel: 'CPU alerts',
                offLabel: 'CPU alerts',
              ),
              _StatusPill.onOff(
                isOn: config.sendMemAlerts,
                onLabel: 'Memory alerts',
                offLabel: 'Memory alerts',
              ),
              _StatusPill.onOff(
                isOn: config.sendDiskAlerts,
                onLabel: 'Disk alerts',
                offLabel: 'Disk alerts',
              ),
              _StatusPill.onOff(
                isOn: config.sendVersionMismatchAlerts,
                onLabel: 'Version mismatch',
                offLabel: 'Version mismatch',
              ),
            ],
          ),
        ),
        const Gap(12),
        _SubCard(
          title: 'Thresholds',
          icon: AppIcons.warning,
          tone: _SectionTone.tertiary,
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
                  _ValuePill(
                    label: 'Warn',
                    value: '${config.cpuWarning.toStringAsFixed(0)}%',
                  ),
                  _ValuePill(
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
                  _ValuePill(
                    label: 'Warn',
                    value: '${config.memWarning.toStringAsFixed(1)} GB',
                  ),
                  _ValuePill(
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
                  _ValuePill(
                    label: 'Warn',
                    value: '${config.diskWarning.toStringAsFixed(1)} GB',
                  ),
                  _ValuePill(
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
          _SubCard(
            title: 'Maintenance',
            icon: AppIcons.maintenance,
            tone: _SectionTone.secondary,
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
                        _StatusPill.onOff(
                          isOn: window.enabled,
                          onLabel: 'Enabled',
                          offLabel: 'Disabled',
                        ),
                        _ValuePill(label: 'Name', value: window.name),
                        _ValuePill(
                          label: 'Type',
                          value: window.scheduleType.name,
                        ),
                        _ValuePill(
                          label: 'At',
                          value:
                              '${window.hour.toString().padLeft(2, '0')}:${window.minute.toString().padLeft(2, '0')}',
                        ),
                        _ValuePill(label: 'TZ', value: window.timezone),
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

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(message),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: const Center(child: CircularProgressIndicator()),
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

class _StatsHistoryContent extends StatelessWidget {
  const _StatsHistoryContent({
    required this.history,
    required this.latestStats,
  });

  final List<_StatsSample> history;
  final SystemStats? latestStats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final uiRefreshSeconds = _estimateUiRefreshSeconds(history);
    final cpu = latestStats?.cpuPercent;
    final mem = latestStats?.memPercent;
    final disk = latestStats?.diskPercent;

    const windowSamples = 32; // ~80s @ 2.5s refresh
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
        const Gap(14),
        Text(
          'Network',
          style: textTheme.titleSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
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
          _InfoRow(label: 'Server polling', value: latestStats!.pollingRate!),
      ],
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

    final fillPath = Path.from(path)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

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
