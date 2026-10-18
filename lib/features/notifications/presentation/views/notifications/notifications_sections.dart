import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/theme/status_colors.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/filters/app_filter_chip.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/notifications/data/models/alert.dart';
import 'package:komodo_go/features/notifications/data/models/resource_target.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';
import 'package:komodo_go/features/notifications/presentation/providers/alerts_provider.dart';
import 'package:komodo_go/features/notifications/presentation/providers/notification_filters_provider.dart';
import 'package:komodo_go/features/notifications/presentation/providers/target_display_name_provider.dart';
import 'package:komodo_go/features/notifications/presentation/providers/updates_provider.dart';
import 'package:komodo_go/features/notifications/presentation/utils/alert_navigation_utils.dart';
import 'package:komodo_go/features/notifications/presentation/utils/alerts_error_utils.dart';
import 'package:skeletonizer/skeletonizer.dart';

class AlertsTab extends ConsumerStatefulWidget {
  const AlertsTab({this.onOpenUpdates, super.key});

  final VoidCallback? onOpenUpdates;

  @override
  ConsumerState<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends ConsumerState<AlertsTab> {
  late final _intro = AppListIntro();

  VoidCallback? get onOpenUpdates => widget.onOpenUpdates;

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(alertsProvider);
    final filters = ref.watch(alertFiltersProvider);

    final alertItems = alertsAsync.asData?.value.items;
    final alertCount = alertItems == null
        ? null
        : filters.apply(alertItems).length;
    final alertSummary = alertCount == null
        ? null
        : '$alertCount ${filters.unresolvedOnly ? 'unresolved' : 'alerts'}';

    return Column(
      children: [
        _FilterBar(
          summary: alertSummary,
          chips: [
            AppFilterChip(
              key: const ValueKey('alerts_filter_unresolved'),
              label: 'Unresolved',
              selected: filters.unresolvedOnly,
              onSelected: (value) =>
                  ref.read(alertFiltersProvider.notifier).filters = filters
                      .copyWith(unresolvedOnly: value),
            ),
            AppFilterChip(
              key: const ValueKey('alerts_filter_critical'),
              label: 'Critical',
              selected: filters.criticalOnly,
              onSelected: (value) =>
                  ref.read(alertFiltersProvider.notifier).filters = filters
                      .copyWith(criticalOnly: value),
            ),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
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

                final items = filters.apply(state.items);
                final isEmpty = items.isEmpty;
                final hasMore = state.nextPage != null;

                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.pixels >=
                        notification.metrics.maxScrollExtent - 200) {
                      unawaited(
                        ref.read(alertsProvider.notifier).fetchNextPage(),
                      );
                    }
                    return false;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    itemCount: (isEmpty ? 1 : items.length) + (hasMore ? 1 : 0),
                    separatorBuilder: (_, _) => const Gap(AppSpacing.md),
                    itemBuilder: (context, index) {
                      if (isEmpty && index == 0) {
                        return _FilteredEmptyMessage(
                          message: filters.criticalOnly
                              ? 'No matching alerts'
                              : 'No unresolved alerts',
                          showAllLabel: 'Show all alerts',
                          onShowAll: () =>
                              ref.read(alertFiltersProvider.notifier).filters =
                                  const AlertFilters(),
                        );
                      }
                      final isFooter = isEmpty
                          ? index > 0
                          : index >= items.length;
                      if (isFooter) {
                        return PaginationFooter(
                          isLoading: state.isLoadingMore,
                          onLoadMore: () => unawaited(
                            ref.read(alertsProvider.notifier).fetchNextPage(),
                          ),
                        );
                      }

                      return _intro.wrap(
                        index,
                        AlertTile(alert: items[index]),
                        id: items[index].id,
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
                  secondaryActionLabel: onOpenUpdates == null
                      ? null
                      : 'Open updates',
                  onSecondaryAction: onOpenUpdates,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Filter row anchored under the tab bar: same surface, hairline divider,
/// chips on the left and a muted result summary on the right.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.chips, this.summary});

  final List<Widget> chips;
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              for (var i = 0; i < chips.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                chips[i],
              ],
              const Spacer(),
              if (summary != null)
                Text(
                  summary!,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilteredEmptyMessage extends StatelessWidget {
  const _FilteredEmptyMessage({
    required this.message,
    required this.showAllLabel,
    required this.onShowAll,
  });

  final String message;
  final String showAllLabel;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const Gap(AppSpacing.sm),
          TextButton(onPressed: onShowAll, child: Text(showAllLabel)),
        ],
      ),
    );
  }
}

class UpdatesTab extends ConsumerStatefulWidget {
  const UpdatesTab({super.key});

  @override
  ConsumerState<UpdatesTab> createState() => _UpdatesTabState();
}

class _UpdatesTabState extends ConsumerState<UpdatesTab> {
  late final _intro = AppListIntro();

  @override
  Widget build(BuildContext context) {
    final updatesAsync = ref.watch(updatesProvider);
    final failedOnly = ref.watch(updatesFailedOnlyProvider);

    final updateItems = updatesAsync.asData?.value.items;
    final updateCount = updateItems == null
        ? null
        : applyUpdatesFilter(updateItems, failedOnly: failedOnly).length;
    final updateSummary = updateCount == null
        ? null
        : '$updateCount ${failedOnly ? 'failed' : 'updates'}';

    return Column(
      children: [
        _FilterBar(
          summary: updateSummary,
          chips: [
            AppFilterChip(
              key: const ValueKey('updates_filter_failed'),
              label: 'Failed only',
              selected: failedOnly,
              onSelected: (value) =>
                  ref.read(updatesFailedOnlyProvider.notifier).value = value,
            ),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
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

                final items = applyUpdatesFilter(
                  state.items,
                  failedOnly: failedOnly,
                );
                final isEmpty = items.isEmpty;
                final hasMore = state.nextPage != null;

                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.pixels >=
                        notification.metrics.maxScrollExtent - 200) {
                      unawaited(
                        ref.read(updatesProvider.notifier).fetchNextPage(),
                      );
                    }
                    return false;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    itemCount: (isEmpty ? 1 : items.length) + (hasMore ? 1 : 0),
                    separatorBuilder: (_, _) => const Gap(AppSpacing.md),
                    itemBuilder: (context, index) {
                      if (isEmpty && index == 0) {
                        return _FilteredEmptyMessage(
                          message: 'No failed updates',
                          showAllLabel: 'Show all updates',
                          onShowAll: () =>
                              ref
                                      .read(updatesFailedOnlyProvider.notifier)
                                      .value =
                                  false,
                        );
                      }
                      final isFooter = isEmpty
                          ? index > 0
                          : index >= items.length;
                      if (isFooter) {
                        return PaginationFooter(
                          isLoading: state.isLoadingMore,
                          onLoadMore: () => unawaited(
                            ref.read(updatesProvider.notifier).fetchNextPage(),
                          ),
                        );
                      }

                      return _intro.wrap(
                        index,
                        UpdateTile(update: items[index]),
                        id: items[index].id,
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
          ),
        ),
      ],
    );
  }
}

class AlertTile extends ConsumerWidget {
  const AlertTile({required this.alert, super.key});

  final Alert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final route = routeForAlert(alert);

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
      SeverityLevel.warning => scheme.statusWarning,
      SeverityLevel.ok => scheme.statusSuccess,
      SeverityLevel.unknown => scheme.onSurfaceVariant,
    };

    final cardRadius = BorderRadius.circular(AppTokens.radiusLg);

    return AppPressable(
      enabled: route != null,
      child: AppCardSurface(
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          borderRadius: cardRadius,
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            titleAlignment: ListTileTitleAlignment.top,
            leading: Icon(_iconForAlert(alert), color: severityColor),
            title: Text(title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (primary != null && primary.isNotEmpty) Text(primary),
                // The target name usually equals the payload's primary name;
                // only show it when it adds information.
                if (targetName != null &&
                    targetName.isNotEmpty &&
                    targetName != primary) ...[
                  const Gap(AppSpacing.xs),
                  Text(
                    targetName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const Gap(AppSpacing.xs),
                Row(
                  children: [
                    Icon(
                      AppIcons.clock,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                    const Gap(AppSpacing.xs),
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
            onTap: route == null ? null : () => context.go(route),
          ),
        ),
      ),
    );
  }
}

class UpdateTile extends ConsumerWidget {
  const UpdateTile({
    required this.update,
    super.key,
    this.currentTargetId,
  });

  final UpdateListItem update;

  /// Id of the resource whose detail screen embeds this tile. When the
  /// update targets it, the target name and the "Open resource" action are
  /// omitted (they would only link back to the current page).
  final String? currentTargetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final route = routeForUpdate(update);

    final title = update.operation.isNotEmpty
        ? _humanizeVariant(update.operation)
        : 'Update';
    final target = update.target;
    final operator = _bestOperatorLabel(update);
    final startTime = _formatDateTime(update.timestamp.toLocal());
    final isCurrent =
        currentTargetId != null &&
        target != null &&
        target.id == currentTargetId;
    final targetName = target == null
        ? 'Unknown target'
        : ref
              .watch(targetDisplayNameProvider(target))
              .maybeWhen(
                data: (value) => value,
                orElse: () => target.displayName,
              );

    final resourceRoute =
        isCurrent ||
            target == null ||
            target.type == ResourceTargetType.system ||
            target.type == ResourceTargetType.unknown
        ? null
        : routeForTarget(target, displayName: targetName);

    final muted = textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final cardRadius = BorderRadius.circular(AppTokens.radiusLg);

    return AppPressable(
      enabled: route != null,
      child: AppCardSurface(
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          borderRadius: cardRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: route == null ? null : () => context.push(route),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      _iconForTargetType(target?.type),
                      color: scheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!isCurrent)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xxs),
                            child: Text(
                              targetName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: muted,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xxs),
                          child: Text(
                            operator == null
                                ? startTime
                                : '$startTime  ·  $operator',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _updateStatusPill(update),
                      if (resourceRoute != null)
                        IconButton(
                          key: ValueKey('update_open_resource_${update.id}'),
                          tooltip: 'Open resource',
                          visualDensity: VisualDensity.compact,
                          style: const ButtonStyle(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          iconSize: 18,
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          onPressed: () => context.push(resourceRoute),
                          icon: const Icon(AppIcons.externalLink),
                        ),
                    ],
                  ),
                ],
              ),
            ),
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
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
    this.scrollable = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      const Gap(64),
      Icon(
        icon,
        size: 64,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
      ),
      const Gap(AppSpacing.lg),
      Center(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      const Gap(AppSpacing.sm),
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
    ];
    if (scrollable) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: children,
      );
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 6,
        separatorBuilder: (_, _) => const Gap(AppSpacing.md),
        itemBuilder: (_, _) => AppCardSurface(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(radius: 16),
                const Gap(AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Alert title', style: textTheme.titleSmall),
                      const Gap(AppSpacing.xs),
                      Text('Primary detail', style: textTheme.bodySmall),
                      const Gap(AppSpacing.xs),
                      Text('Target • Time', style: textTheme.bodySmall),
                    ],
                  ),
                ),
                const Gap(AppSpacing.sm),
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 6,
        separatorBuilder: (_, _) => const Gap(AppSpacing.md),
        itemBuilder: (_, _) => AppCardSurface(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(radius: 16),
                const Gap(AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Update title', style: textTheme.titleSmall),
                      const Gap(AppSpacing.xs),
                      Text('Detail line', style: textTheme.bodySmall),
                      const Gap(AppSpacing.xs),
                      Text('Resource • Time', style: textTheme.bodySmall),
                    ],
                  ),
                ),
                const Gap(AppSpacing.sm),
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
    this.scrollable = true,
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      const Gap(64),
      Icon(
        AppIcons.formError,
        size: 64,
        color: Theme.of(context).colorScheme.error,
      ),
      const Gap(AppSpacing.lg),
      Center(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      const Gap(AppSpacing.sm),
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
      const Gap(AppSpacing.xl),
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
    ];
    if (scrollable) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: children,
      );
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

enum NotificationsStatusChipKind { success, warning, error, neutral, working }

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
        scheme.statusSuccessContainer,
        scheme.statusSuccess,
      ),
      NotificationsStatusChipKind.warning => (
        scheme.statusWarningContainer,
        scheme.statusWarning,
      ),
      NotificationsStatusChipKind.error => (
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      NotificationsStatusChipKind.working => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      NotificationsStatusChipKind.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
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

StatusPill _updateStatusPill(UpdateListItem update) {
  final (label, icon, tone) = switch (update.status) {
    UpdateStatus.running => ('Running', AppIcons.loading, PillTone.warning),
    UpdateStatus.queued => ('Queued', AppIcons.waiting, PillTone.neutral),
    UpdateStatus.success => ('Success', AppIcons.ok, PillTone.success),
    UpdateStatus.failed => ('Failed', AppIcons.error, PillTone.alert),
    UpdateStatus.canceled => ('Canceled', AppIcons.canceled, PillTone.neutral),
    UpdateStatus.unknown =>
      update.success
          ? ('Success', AppIcons.ok, PillTone.success)
          : ('Unknown', AppIcons.unknown, PillTone.neutral),
  };
  return StatusPill(label: label, icon: icon, tone: tone);
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
