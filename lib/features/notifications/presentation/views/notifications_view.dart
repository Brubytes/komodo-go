import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/features/notifications/data/models/alert.dart';
import 'package:komodo_go/features/notifications/data/models/resource_target.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';
import 'package:komodo_go/features/notifications/presentation/providers/alerts_provider.dart';
import 'package:komodo_go/features/notifications/presentation/providers/updates_provider.dart';

class NotificationsView extends ConsumerWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(AppIcons.refresh),
              onPressed: () {
                ref.invalidate(alertsProvider);
                ref.invalidate(updatesProvider);
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Alerts'),
              Tab(text: 'Updates'),
            ],
          ),
        ),
        body: const TabBarView(children: [_AlertsTab(), _UpdatesTab()]),
      ),
    );
  }
}

class _AlertsTab extends ConsumerWidget {
  const _AlertsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(alertsProvider.notifier).refresh(),
      child: alertsAsync.when(
        data: (state) {
          if (state.items.isEmpty) {
            return const _EmptyState(
              icon: AppIcons.warning,
              title: 'No alerts',
              description: 'You’re all caught up.',
            );
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200) {
                ref.read(alertsProvider.notifier).fetchNextPage();
              }
              return false;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.items.length + (state.nextPage == null ? 0 : 1),
              separatorBuilder: (_, __) => const Gap(12),
              itemBuilder: (context, index) {
                final isFooter = index >= state.items.length;
                if (isFooter) {
                  return _PaginationFooter(
                    isLoading: state.isLoadingMore,
                    onLoadMore: () =>
                        ref.read(alertsProvider.notifier).fetchNextPage(),
                  );
                }

                final alert = state.items[index];
                return _AlertTile(alert: alert);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          title: 'Failed to load alerts',
          message: error.toString(),
          onRetry: () => ref.invalidate(alertsProvider),
        ),
      ),
    );
  }
}

class _UpdatesTab extends ConsumerWidget {
  const _UpdatesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updatesAsync = ref.watch(updatesProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(updatesProvider.notifier).refresh(),
      child: updatesAsync.when(
        data: (state) {
          if (state.items.isEmpty) {
            return const _EmptyState(
              icon: AppIcons.updateAvailable,
              title: 'No updates',
              description: 'No recent activity yet.',
            );
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200) {
                ref.read(updatesProvider.notifier).fetchNextPage();
              }
              return false;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.items.length + (state.nextPage == null ? 0 : 1),
              separatorBuilder: (_, __) => const Gap(12),
              itemBuilder: (context, index) {
                final isFooter = index >= state.items.length;
                if (isFooter) {
                  return _PaginationFooter(
                    isLoading: state.isLoadingMore,
                    onLoadMore: () =>
                        ref.read(updatesProvider.notifier).fetchNextPage(),
                  );
                }

                final update = state.items[index];
                return _UpdateTile(update: update);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          title: 'Failed to load updates',
          message: error.toString(),
          onRetry: () => ref.invalidate(updatesProvider),
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final title = alert.payload.displayTitle;
    final primary = alert.payload.primaryName;
    final target = alert.target;

    final severityColor = switch (alert.level) {
      SeverityLevel.critical => scheme.error,
      SeverityLevel.warning => scheme.tertiary,
      SeverityLevel.ok => scheme.primary,
      SeverityLevel.unknown => scheme.onSurfaceVariant,
    };

    return Card(
      child: ListTile(
        leading: Icon(_iconForAlert(alert), color: severityColor),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (primary != null && primary.isNotEmpty) Text(primary),
            const Gap(4),
            Row(
              children: [
                Icon(
                  _iconForTargetType(target?.type),
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const Gap(6),
                Expanded(
                  child: Text(
                    _labelForTarget(target),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(4),
            Row(
              children: [
                Icon(AppIcons.clock, size: 16, color: scheme.onSurfaceVariant),
                const Gap(6),
                Expanded(
                  child: Text(
                    _formatTimestamp(alert.timestamp.toLocal()),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: alert.resolved
            ? const _StatusChip(label: 'RESOLVED', kind: _ChipKind.neutral)
            : _StatusChip(
                label: _labelForSeverity(alert.level),
                kind: _chipKindForAlertLevel(alert.level),
              ),
        onTap: () {
          final route = _routeForTarget(target);
          if (route != null) {
            context.push(route);
          }
        },
      ),
    );
  }
}

class _UpdateTile extends StatelessWidget {
  const _UpdateTile({required this.update});

  final UpdateListItem update;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final title = update.operation.isNotEmpty
        ? _humanizeVariant(update.operation)
        : 'Update';
    final target = update.target;
    final operator = _bestOperatorLabel(update);
    final startTime = _formatDateTime(update.timestamp.toLocal());

    return Card(
      child: ListTile(
        leading: Icon(_iconForTargetType(target?.type), color: scheme.primary),
        title: Row(
          children: [
            Expanded(child: Text(title)),
            _StatusChip(
              label: _labelForUpdateStatus(update),
              kind: _kindForUpdate(update),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Gap(4),
            Row(
              children: [
                Icon(
                  _iconForTargetType(target?.type),
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const Gap(6),
                Expanded(
                  child: Text(
                    _labelForTarget(target),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(4),
            Row(
              children: [
                if (operator != null) ...[
                  Icon(AppIcons.user, size: 16, color: scheme.onSurfaceVariant),
                  const Gap(6),
                  Expanded(
                    child: Text(
                      operator,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Gap(12),
                ] else
                  const Spacer(),
                Icon(AppIcons.clock, size: 16, color: scheme.onSurfaceVariant),
                const Gap(6),
                Text(
                  startTime,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          final route = _routeForTarget(target);
          if (route != null) {
            context.push(route);
          }
        },
      ),
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({required this.isLoading, required this.onLoadMore});

  final bool isLoading;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Center(
      child: FilledButton.tonal(
        onPressed: onLoadMore,
        child: const Text('Load more'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Gap(64),
        Icon(
          icon,
          size: 64,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
        ),
        const Gap(16),
        Center(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        const Gap(8),
        Center(
          child: Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Gap(64),
        Icon(
          AppIcons.formError,
          size: 64,
          color: Theme.of(context).colorScheme.error,
        ),
        const Gap(16),
        Center(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        const Gap(8),
        Center(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const Gap(24),
        Center(
          child: FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}

enum _ChipKind { success, warning, error, neutral }

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.kind});

  final String label;
  final _ChipKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (bg, fg) = switch (kind) {
      _ChipKind.success => (
        AppTokens.statusGreen.withValues(alpha: 0.16),
        AppTokens.statusGreen,
      ),
      _ChipKind.warning => (
        AppTokens.statusOrange.withValues(alpha: 0.18),
        AppTokens.statusOrange,
      ),
      _ChipKind.error => (
        AppTokens.statusRed.withValues(alpha: 0.16),
        AppTokens.statusRed,
      ),
      _ChipKind.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
      ),
    );
  }
}

String? _routeForTarget(ResourceTarget? target) {
  if (target == null) return null;
  final id = Uri.encodeComponent(target.id);

  return switch (target.type) {
    ResourceTargetType.server => '${AppRoutes.servers}/$id',
    ResourceTargetType.stack => '${AppRoutes.stacks}/$id',
    ResourceTargetType.repo => '${AppRoutes.repos}/$id',
    ResourceTargetType.build => '${AppRoutes.builds}/$id',
    ResourceTargetType.procedure => '${AppRoutes.procedures}/$id',
    ResourceTargetType.action => '${AppRoutes.actions}/$id',
    _ => null,
  };
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

String _humanizeVariant(String value) {
  final withSpaces = value.replaceAllMapped(
    RegExp(r'(?<=[a-z0-9])(?=[A-Z])'),
    (_) => ' ',
  );
  if (withSpaces.isEmpty) return value;
  return withSpaces[0].toUpperCase() + withSpaces.substring(1);
}

IconData _iconForTargetType(ResourceTargetType? type) {
  return switch (type) {
    ResourceTargetType.system => AppIcons.maintenance,
    ResourceTargetType.server => AppIcons.server,
    ResourceTargetType.stack => AppIcons.stacks,
    ResourceTargetType.deployment => AppIcons.deployments,
    ResourceTargetType.build => AppIcons.builds,
    ResourceTargetType.repo => AppIcons.repos,
    ResourceTargetType.procedure => AppIcons.procedures,
    ResourceTargetType.action => AppIcons.actions,
    ResourceTargetType.resourceSync => AppIcons.syncs,
    ResourceTargetType.builder => AppIcons.builds,
    ResourceTargetType.alerter => AppIcons.notifications,
    ResourceTargetType.unknown || null => AppIcons.widgets,
  };
}

String _labelForTarget(ResourceTarget? target) {
  if (target == null) return 'Unknown target';
  return target.displayName;
}

String? _shortId(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  if (value.length <= 12) return value;

  final isHexish = RegExp(r'^[a-fA-F0-9]{12,}$').hasMatch(value);
  final isDigits = RegExp(r'^[0-9]{12,}$').hasMatch(value);
  if (!isHexish && !isDigits) return null;

  return '${value.substring(0, 6)}…${value.substring(value.length - 4)}';
}

bool _looksLikeOpaqueId(String raw) => _shortId(raw) != null;

IconData _iconForAlert(Alert alert) {
  return switch (alert.level) {
    SeverityLevel.critical => AppIcons.error,
    SeverityLevel.warning => AppIcons.warning,
    SeverityLevel.ok => AppIcons.ok,
    SeverityLevel.unknown => AppIcons.unknown,
  };
}

String _labelForSeverity(SeverityLevel level) {
  return switch (level) {
    SeverityLevel.ok => 'OK',
    SeverityLevel.warning => 'WARNING',
    SeverityLevel.critical => 'CRITICAL',
    SeverityLevel.unknown => 'ALERT',
  };
}

String _labelForUpdateStatus(UpdateListItem update) {
  return switch (update.status) {
    UpdateStatus.running => 'RUNNING',
    UpdateStatus.queued => 'QUEUED',
    UpdateStatus.success => 'SUCCESS',
    UpdateStatus.failed => 'FAILED',
    UpdateStatus.canceled => 'CANCELED',
    UpdateStatus.unknown => update.success ? 'SUCCESS' : 'UNKNOWN',
  };
}

_ChipKind _kindForUpdate(UpdateListItem update) {
  return switch (update.status) {
    UpdateStatus.success => _ChipKind.success,
    UpdateStatus.failed => _ChipKind.error,
    UpdateStatus.running || UpdateStatus.queued => _ChipKind.warning,
    UpdateStatus.canceled => _ChipKind.neutral,
    UpdateStatus.unknown =>
      update.success ? _ChipKind.success : _ChipKind.neutral,
  };
}

_ChipKind _chipKindForAlertLevel(SeverityLevel level) {
  return switch (level) {
    SeverityLevel.ok => _ChipKind.success,
    SeverityLevel.warning => _ChipKind.warning,
    SeverityLevel.critical => _ChipKind.error,
    SeverityLevel.unknown => _ChipKind.neutral,
  };
}

String? _bestOperatorLabel(UpdateListItem update) {
  final preferred = update.operatorName.trim();
  final fallback = update.username.trim();

  if (preferred.isNotEmpty && !_looksLikeOpaqueId(preferred)) {
    return preferred;
  }
  if (fallback.isNotEmpty && !_looksLikeOpaqueId(fallback)) {
    return fallback;
  }
  return null;
}

String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final now = DateTime.now();

  final isToday =
      now.year == local.year &&
      now.month == local.month &&
      now.day == local.day;

  final hour = local.hour;
  final isPm = hour >= 12;
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final ampm = isPm ? 'PM' : 'AM';

  if (isToday) {
    return '$hour12:$minute $ampm';
  }

  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[local.month - 1];
  return '$month ${local.day} · $hour12:$minute $ampm';
}
