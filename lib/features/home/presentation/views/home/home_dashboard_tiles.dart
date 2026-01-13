import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/notifications/data/models/alert.dart';
import 'package:komodo_go/features/notifications/data/models/resource_target.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/data/models/system_stats.dart';

class HomeServerStatTile extends StatelessWidget {
  const HomeServerStatTile({
    required this.server,
    required this.stats,
    super.key,
  });

  final Server server;
  final AsyncValue<SystemStats?> stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = _serverStatusColor(server.state);
    final statusIcon = _serverStatusIcon(server.state);
    final statsValue = stats.asData?.value;
    final isLoading = stats.isLoading && statsValue == null;

    final cardRadius = BorderRadius.circular(AppTokens.radiusLg);

    return SizedBox(
      width: 220,
      child: AppCardSurface(
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          borderRadius: cardRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              final id = server.id;
              if (id.isEmpty) return;
              context.go(
                '${AppRoutes.servers}/$id?name=${Uri.encodeComponent(server.name)}',
              );
            },
            borderRadius: cardRadius,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // This tile is rendered inside a fixed-height horizontal list (currently 130).
                // Use a compact layout to prevent vertical overflow.
                final isCompact = constraints.maxHeight <= 132;
                final padding = isCompact ? 7.0 : 12.0;
                final headerGap = isCompact ? 3.0 : 10.0;

                return Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Gap(8),
                          Expanded(
                            child: Text(
                              server.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Icon(statusIcon, size: 14, color: statusColor),
                        ],
                      ),
                      Gap(headerGap),
                      if (isLoading)
                        Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.primary,
                              ),
                            ),
                            const Gap(8),
                            Text(
                              'Loading stats',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        )
                      else if (isCompact)
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _CompactStatLine(
                                icon: AppIcons.cpu,
                                label: 'CPU',
                                primary: _percentLabel(statsValue?.cpuPercent),
                                color: AppTokens.statusGreen,
                              ),
                              _CompactStatLine(
                                icon: AppIcons.memory,
                                label: 'Memory',
                                primary: _percentLabel(statsValue?.memPercent),
                                secondary: _absoluteLabel(
                                  statsValue?.memUsedGb,
                                  statsValue?.memTotalGb,
                                ),
                                color: AppTokens.statusOrange,
                              ),
                              _CompactStatLine(
                                icon: AppIcons.hardDrive,
                                label: 'Disk',
                                primary: _percentLabel(statsValue?.diskPercent),
                                secondary: _absoluteLabel(
                                  statsValue?.diskUsedGb,
                                  statsValue?.diskTotalGb,
                                ),
                                color: AppTokens.statusRed,
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: [
                            _StatRow(
                              icon: AppIcons.cpu,
                              label: 'CPU',
                              percent: statsValue?.cpuPercent,
                              color: AppTokens.statusGreen,
                            ),
                            const Gap(10),
                            _StatRow(
                              icon: AppIcons.memory,
                              label: 'Memory',
                              percent: statsValue?.memPercent,
                              secondary: _absoluteLabel(
                                statsValue?.memUsedGb,
                                statsValue?.memTotalGb,
                              ),
                              color: AppTokens.statusOrange,
                            ),
                            const Gap(10),
                            _StatRow(
                              icon: AppIcons.hardDrive,
                              label: 'Disk',
                              percent: statsValue?.diskPercent,
                              secondary: _absoluteLabel(
                                statsValue?.diskUsedGb,
                                statsValue?.diskTotalGb,
                              ),
                              color: AppTokens.statusRed,
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _percentLabel(double? value) {
    if (value == null || value.isNaN) return '—';
    return '${value.toStringAsFixed(0)}%';
  }

  String _absoluteLabel(double? used, double? total) {
    if (used == null || total == null || total <= 0) return '—';
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

  Color _serverStatusColor(ServerState state) {
    return switch (state) {
      ServerState.ok => AppTokens.statusGreen,
      ServerState.notOk => AppTokens.statusRed,
      ServerState.disabled => Colors.grey,
      ServerState.unknown => AppTokens.statusOrange,
    };
  }

  IconData _serverStatusIcon(ServerState state) {
    return switch (state) {
      ServerState.ok => AppIcons.ok,
      ServerState.notOk => AppIcons.error,
      ServerState.disabled => AppIcons.paused,
      ServerState.unknown => AppIcons.unknown,
    };
  }
}

class HomeAlertPreviewTile extends StatelessWidget {
  const HomeAlertPreviewTile({required this.alert, super.key});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _alertColor(alert.level, scheme);
    final title = alert.payload.displayTitle;
    final primary = alert.payload.primaryName;

    final cardRadius = BorderRadius.circular(AppTokens.radiusLg);

    return AppCardSurface(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: cardRadius,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(_alertIcon(alert.level), color: color),
          title: Text(title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (primary != null && primary.isNotEmpty) Text(primary),
              const Gap(4),
              Text(
                _formatTimestamp(alert.timestamp.toLocal()),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _alertIcon(SeverityLevel level) {
    return switch (level) {
      SeverityLevel.critical => AppIcons.error,
      SeverityLevel.warning => AppIcons.warning,
      SeverityLevel.ok => AppIcons.ok,
      SeverityLevel.unknown => AppIcons.unknown,
    };
  }

  Color _alertColor(SeverityLevel level, ColorScheme scheme) {
    return switch (level) {
      SeverityLevel.critical => scheme.error,
      SeverityLevel.warning => AppTokens.statusOrange,
      SeverityLevel.ok => scheme.primary,
      SeverityLevel.unknown => scheme.onSurfaceVariant,
    };
  }
}

class HomeUpdatePreviewTile extends StatelessWidget {
  const HomeUpdatePreviewTile({required this.update, super.key});

  final UpdateListItem update;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(update.status, scheme);
    final label = update.operation.isNotEmpty
        ? _humanizeVariant(update.operation)
        : 'Update';
    final targetName = update.target?.displayName ?? 'Unknown target';

    final cardRadius = BorderRadius.circular(AppTokens.radiusLg);

    return AppCardSurface(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: cardRadius,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(
            _iconForTargetType(update.target?.type),
            color: statusColor,
          ),
          title: Text(label),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                targetName,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Gap(4),
              Text(
                _formatTimestamp(update.timestamp.toLocal()),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          trailing: _StatusChip(
            label: _statusLabel(update.status, update.success),
            color: statusColor,
          ),
        ),
      ),
    );
  }

  Color _statusColor(UpdateStatus status, ColorScheme scheme) {
    return switch (status) {
      UpdateStatus.success => AppTokens.statusGreen,
      UpdateStatus.failed => scheme.error,
      UpdateStatus.running || UpdateStatus.queued => AppTokens.statusOrange,
      UpdateStatus.canceled => scheme.onSurfaceVariant,
      UpdateStatus.unknown => scheme.primary,
    };
  }

  String _statusLabel(UpdateStatus status, bool success) {
    return switch (status) {
      UpdateStatus.running => 'RUNNING',
      UpdateStatus.queued => 'QUEUED',
      UpdateStatus.success => 'SUCCESS',
      UpdateStatus.failed => 'FAILED',
      UpdateStatus.canceled => 'CANCELED',
      UpdateStatus.unknown => success ? 'SUCCESS' : 'UNKNOWN',
    };
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.percent,
    required this.color,
    this.secondary,
  });

  final IconData icon;
  final String label;
  final double? percent;
  final String? secondary;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percentValue = _percentValue(percent);
    final percentLabel = _percentLabel(percent);
    final showSecondary = secondary != null && secondary != '—';

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  if (showSecondary) ...[
                    const Gap(2),
                    Text(
                      secondary!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Gap(8),
            Text(
              percentLabel,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const Gap(6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percentValue ?? 0,
            minHeight: 6,
            color: color,
            backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }

  double? _percentValue(double? value) {
    if (value == null || value.isNaN) return null;
    return (value / 100).clamp(0.0, 1.0);
  }

  String _percentLabel(double? value) {
    if (value == null || value.isNaN) return '—';
    return '${value.toStringAsFixed(0)}%';
  }
}

class _CompactStatLine extends StatelessWidget {
  const _CompactStatLine({
    required this.icon,
    required this.label,
    required this.primary,
    required this.color,
    this.secondary,
  });

  final IconData icon;
  final String label;
  final String primary;
  final String? secondary;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w700,
      height: 1.0,
    );
    final primaryStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w800,
      height: 1.0,
    );

    final secondaryValue = secondary;
    final showSecondary = secondaryValue != null && secondaryValue != '—';
    final secondaryStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: color.withValues(alpha: 0.9),
      fontWeight: FontWeight.w700,
      fontSize: 10,
      height: 1.0,
    );

    return SizedBox(
      height: 26,
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 13, color: color),
          ),
          const Gap(7),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
          const Gap(7),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                primary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: primaryStyle,
              ),
              if (showSecondary) ...[
                const Gap(1),
                Text(
                  secondaryValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: secondaryStyle,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

IconData _iconForTargetType(ResourceTargetType? type) {
  return switch (type) {
    ResourceTargetType.system => AppIcons.settings,
    ResourceTargetType.server => AppIcons.server,
    ResourceTargetType.stack => AppIcons.stacks,
    ResourceTargetType.deployment => AppIcons.deployments,
    ResourceTargetType.build => AppIcons.builds,
    ResourceTargetType.repo => AppIcons.repos,
    ResourceTargetType.procedure => AppIcons.procedures,
    ResourceTargetType.action => AppIcons.actions,
    ResourceTargetType.resourceSync => AppIcons.syncs,
    ResourceTargetType.builder => AppIcons.factory,
    ResourceTargetType.alerter => AppIcons.notifications,
    ResourceTargetType.unknown || null => AppIcons.widgets,
  };
}

String _humanizeVariant(String value) {
  final withSpaces = value.replaceAllMapped(
    RegExp('(?<=[a-z0-9])(?=[A-Z])'),
    (_) => ' ',
  );
  if (withSpaces.isEmpty) return value;
  return withSpaces[0].toUpperCase() + withSpaces.substring(1);
}

String _formatTimestamp(DateTime dateTime) {
  final local = dateTime.toLocal();
  final now = DateTime.now();
  final difference = now.difference(local);

  if (difference.inMinutes < 1) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';

  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
