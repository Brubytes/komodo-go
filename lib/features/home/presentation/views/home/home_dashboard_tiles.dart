import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
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
    final statsValue = stats.asData?.value;
    final isLoading = stats.isLoading && statsValue == null;

    return Card(
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
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
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(10),
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _StatPill(
                    label: 'CPU',
                    value: _percentLabel(statsValue?.cpuPercent),
                    color: AppTokens.statusGreen,
                  ),
                  _StatPill(
                    label: 'Mem',
                    value: _percentWithAbsolute(
                      statsValue?.memPercent,
                      statsValue?.memUsedGb,
                      statsValue?.memTotalGb,
                    ),
                    color: AppTokens.statusOrange,
                  ),
                  _StatPill(
                    label: 'Disk',
                    value: _percentWithAbsolute(
                      statsValue?.diskPercent,
                      statsValue?.diskUsedGb,
                      statsValue?.diskTotalGb,
                    ),
                    color: AppTokens.statusRed,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _percentLabel(double? value) {
    if (value == null || value.isNaN) return '—';
    return '${value.toStringAsFixed(0)}%';
  }

  String _percentWithAbsolute(double? percent, double? used, double? total) {
    final percentLabel = _percentLabel(percent);
    final absoluteLabel = _absoluteLabel(used, total);
    if (absoluteLabel == '—') return percentLabel;
    return '$percentLabel\n$absoluteLabel';
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

    return Card(
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

    return Card(
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

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Builder(
        builder: (context) {
          final parts = value.split('\n');
          final primaryStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            height: 1.1,
          );
          final secondaryStyle = Theme.of(context).textTheme.labelSmall
              ?.copyWith(
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
                fontSize: 10,
                height: 1.1,
              );

          if (parts.length == 1) {
            return Text(
              '$label ${parts.first}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: primaryStyle,
            );
          }

          return Text.rich(
            TextSpan(
              text: '$label ${parts.first}',
              style: primaryStyle,
              children: [
                TextSpan(
                  text: '\n${parts.skip(1).join(' ')}',
                  style: secondaryStyle,
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );
        },
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
