import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/notifications/data/models/alert.dart';
import 'package:komodo_go/features/notifications/data/models/resource_target.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';
import 'package:komodo_go/features/notifications/presentation/providers/alerts_provider.dart';
import 'package:komodo_go/features/notifications/presentation/providers/target_display_name_provider.dart';
import 'package:komodo_go/features/notifications/presentation/providers/updates_provider.dart';
import 'package:komodo_go/features/notifications/presentation/utils/alerts_error_utils.dart';
import 'package:skeletonizer/skeletonizer.dart';

class AlertsTab extends ConsumerWidget {
  const AlertsTab({this.onOpenUpdates, super.key});

  final VoidCallback? onOpenUpdates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(alertsProvider.notifier).refresh(),
      child: alertsAsync.when(
        data: (state) {
          if (state.items.isEmpty) {
            return const NotificationsEmptyState(
              icon: AppIcons.warning,
              title: 'No alerts',
              description: 'You’re all caught up.',
            );
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200) {
                unawaited(ref.read(alertsProvider.notifier).fetchNextPage());
              }
              return false;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.items.length + (state.nextPage == null ? 0 : 1),
              separatorBuilder: (_, _) => const Gap(12),
              itemBuilder: (context, index) {
                final isFooter = index >= state.items.length;
                if (isFooter) {
                  return PaginationFooter(
                    isLoading: state.isLoadingMore,
                    onLoadMore: () => unawaited(
                      ref.read(alertsProvider.notifier).fetchNextPage(),
                    ),
                  );
                }

                final alert = state.items[index];
                return AppFadeSlide(
                  delay: AppMotion.stagger(index),
                  play: index < 10,
                  child: AlertTile(alert: alert),
                );
              },
            ),
          );
        },
        loading: () => const _AlertsSkeletonList(),
        error: (error, stack) {
          final title = alertsUnavailableTitle(error);
          final message = alertsUnavailableMessage(error);
          return NotificationsErrorState(
            title: title,
            message: message,
            onRetry: () => ref.invalidate(alertsProvider),
            secondaryActionLabel: onOpenUpdates == null ? null : 'Open updates',
            onSecondaryAction: onOpenUpdates,
          );
        },
      ),
    );
  }
}

class UpdatesTab extends ConsumerWidget {
  const UpdatesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updatesAsync = ref.watch(updatesProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(updatesProvider.notifier).refresh(),
      child: updatesAsync.when(
        data: (state) {
          if (state.items.isEmpty) {
            return const NotificationsEmptyState(
              icon: AppIcons.updateAvailable,
              title: 'No updates',
              description: 'No recent activity yet.',
            );
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200) {
                unawaited(ref.read(updatesProvider.notifier).fetchNextPage());
              }
              return false;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.items.length + (state.nextPage == null ? 0 : 1),
              separatorBuilder: (_, _) => const Gap(12),
              itemBuilder: (context, index) {
                final isFooter = index >= state.items.length;
                if (isFooter) {
                  return PaginationFooter(
                    isLoading: state.isLoadingMore,
                    onLoadMore: () => unawaited(
                      ref.read(updatesProvider.notifier).fetchNextPage(),
                    ),
                  );
                }

                final update = state.items[index];
                return AppFadeSlide(
                  delay: AppMotion.stagger(index),
                  play: index < 10,
                  child: UpdateTile(update: update),
                );
              },
            ),
          );
        },
        loading: () => const _UpdatesSkeletonList(),
        error: (error, stack) => NotificationsErrorState(
          title: 'Failed to load updates',
          message: error.toString(),
          onRetry: () => ref.invalidate(updatesProvider),
        ),
      ),
    );
  }
}

class AlertTile extends ConsumerWidget {
  const AlertTile({required this.alert, super.key});

  final Alert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    final title = alert.payload.displayTitle;
    final primary = alert.payload.primaryName;
    final target = alert.target;
    final targetName = target == null
        ? null
        : ref
              .watch(targetDisplayNameProvider(target))
              .maybeWhen(
                data: (value) => value,
                orElse: () => target.displayName,
              );

    final severityColor = switch (alert.level) {
      SeverityLevel.critical => scheme.error,
      SeverityLevel.warning => scheme.tertiary,
      SeverityLevel.ok => scheme.primary,
      SeverityLevel.unknown => scheme.onSurfaceVariant,
    };

    final cardRadius = BorderRadius.circular(AppTokens.radiusLg);

    return AppCardSurface(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: cardRadius,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(_iconForAlert(alert), color: severityColor),
          title: Text(title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (primary != null && primary.isNotEmpty) Text(primary),
              if (targetName != null && targetName.isNotEmpty) ...[
                const Gap(4),
                Text(
                  targetName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const Gap(4),
              Row(
                children: [
                  Icon(
                    AppIcons.clock,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
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
              ? const NotificationsStatusChip(
                  label: 'RESOLVED',
                  kind: NotificationsStatusChipKind.neutral,
                )
              : NotificationsStatusChip(
                  label: _labelForSeverity(alert.level),
                  kind: _chipKindForAlertLevel(alert.level),
                ),
          onTap: () {
            final route = _routeForTarget(target);
            if (route != null) {
              context.go(route);
            }
          },
        ),
      ),
    );
  }
}

class UpdateTile extends ConsumerWidget {
  const UpdateTile({required this.update, super.key});

  final UpdateListItem update;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    final title = update.operation.isNotEmpty
        ? _humanizeVariant(update.operation)
        : 'Update';
    final target = update.target;
    final operator = _bestOperatorLabel(update);
    final startTime = _formatDateTime(update.timestamp.toLocal());
    final targetName = target == null
        ? 'Unknown target'
        : ref
              .watch(targetDisplayNameProvider(target))
              .maybeWhen(
                data: (value) => value,
                orElse: () => target.displayName,
              );

    final cardRadius = BorderRadius.circular(AppTokens.radiusLg);

    return AppCardSurface(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: cardRadius,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(
            _iconForTargetType(target?.type),
            color: scheme.primary,
          ),
          title: Row(
            children: [
              Expanded(child: Text(title)),
              NotificationsStatusChip(
                label: _labelForUpdateStatus(update),
                kind: _kindForUpdate(update),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(4),
              Text(
                targetName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Gap(4),
              Row(
                children: [
                  if (operator != null) ...[
                    Icon(
                      AppIcons.user,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
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
                  ],
                  Icon(
                    AppIcons.clock,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
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
        ),
      ),
    );
  }
}

class PaginationFooter extends StatelessWidget {
  const PaginationFooter({
    required this.isLoading,
    required this.onLoadMore,
    super.key,
  });

  final bool isLoading;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: AppInlineSkeleton(size: 20)),
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

class NotificationsEmptyState extends StatelessWidget {
  const NotificationsEmptyState({
    required this.icon,
    required this.title,
    required this.description,
    super.key,
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

class _AlertsSkeletonList extends StatelessWidget {
  const _AlertsSkeletonList();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Skeletonizer(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, _) => const Gap(12),
        itemBuilder: (_, _) => AppCardSurface(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(radius: 16),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Alert title', style: textTheme.titleSmall),
                      const Gap(6),
                      Text('Primary detail', style: textTheme.bodySmall),
                      const Gap(6),
                      Text('Target • Time', style: textTheme.bodySmall),
                    ],
                  ),
                ),
                const Gap(8),
                const Chip(label: Text('OPEN')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpdatesSkeletonList extends StatelessWidget {
  const _UpdatesSkeletonList();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Skeletonizer(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, _) => const Gap(12),
        itemBuilder: (_, _) => AppCardSurface(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(radius: 16),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Update title', style: textTheme.titleSmall),
                      const Gap(6),
                      Text('Detail line', style: textTheme.bodySmall),
                      const Gap(6),
                      Text('Resource • Time', style: textTheme.bodySmall),
                    ],
                  ),
                ),
                const Gap(8),
                const Chip(label: Text('NEW')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NotificationsErrorState extends StatelessWidget {
  const NotificationsErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Retry',
    this.secondaryActionLabel,
    this.onSecondaryAction,
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

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
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.tonal(
              onPressed: onRetry,
              child: Text(retryLabel),
            ),
            if (secondaryActionLabel != null && onSecondaryAction != null)
              FilledButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionLabel!),
              ),
          ],
        ),
      ],
    );
  }
}

enum NotificationsStatusChipKind { success, warning, error, neutral }

class NotificationsStatusChip extends StatelessWidget {
  const NotificationsStatusChip({
    required this.label,
    required this.kind,
    super.key,
  });

  final String label;
  final NotificationsStatusChipKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (bg, fg) = switch (kind) {
      NotificationsStatusChipKind.success => (
        AppTokens.statusGreen.withValues(alpha: 0.16),
        AppTokens.statusGreen,
      ),
      NotificationsStatusChipKind.warning => (
        AppTokens.statusOrange.withValues(alpha: 0.18),
        AppTokens.statusOrange,
      ),
      NotificationsStatusChipKind.error => (
        AppTokens.statusRed.withValues(alpha: 0.16),
        AppTokens.statusRed,
      ),
      NotificationsStatusChipKind.neutral => (
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
    RegExp('(?<=[a-z0-9])(?=[A-Z])'),
    (_) => ' ',
  );
  if (withSpaces.isEmpty) return value;
  return withSpaces[0].toUpperCase() + withSpaces.substring(1);
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

NotificationsStatusChipKind _kindForUpdate(UpdateListItem update) {
  return switch (update.status) {
    UpdateStatus.success => NotificationsStatusChipKind.success,
    UpdateStatus.failed => NotificationsStatusChipKind.error,
    UpdateStatus.running ||
    UpdateStatus.queued => NotificationsStatusChipKind.warning,
    UpdateStatus.canceled => NotificationsStatusChipKind.neutral,
    UpdateStatus.unknown =>
      update.success
          ? NotificationsStatusChipKind.success
          : NotificationsStatusChipKind.neutral,
  };
}

NotificationsStatusChipKind _chipKindForAlertLevel(SeverityLevel level) {
  return switch (level) {
    SeverityLevel.ok => NotificationsStatusChipKind.success,
    SeverityLevel.warning => NotificationsStatusChipKind.warning,
    SeverityLevel.critical => NotificationsStatusChipKind.error,
    SeverityLevel.unknown => NotificationsStatusChipKind.neutral,
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
