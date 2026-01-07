import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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

    final (icon, color) = switch (alert.level) {
      SeverityLevel.critical => (AppIcons.error, scheme.error),
      SeverityLevel.warning => (AppIcons.warning, scheme.tertiary),
      SeverityLevel.ok => (AppIcons.ok, scheme.primary),
      SeverityLevel.unknown => (AppIcons.unknown, scheme.onSurfaceVariant),
    };

    final title = alert.payload.displayTitle;
    final primary = alert.payload.primaryName;
    final target = alert.target;
    final secondary = [
      if (primary != null) primary,
      if (primary == null && target != null)
        '${target.displayName} ${target.id}',
      _formatTimestamp(alert.timestamp.toLocal()),
    ].where((s) => s.isNotEmpty).join(' · ');

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(secondary),
        trailing: alert.resolved ? const _Badge(label: 'Resolved') : null,
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

    final (icon, color) = switch (update.status) {
      UpdateStatus.running => (AppIcons.loading, scheme.primary),
      UpdateStatus.success => (AppIcons.ok, scheme.primary),
      UpdateStatus.failed => (AppIcons.error, scheme.error),
      UpdateStatus.canceled => (AppIcons.canceled, scheme.onSurfaceVariant),
      _ =>
        update.success
            ? (AppIcons.ok, scheme.primary)
            : (AppIcons.unknown, scheme.onSurfaceVariant),
    };

    final title = update.operation.isNotEmpty
        ? _humanizeVariant(update.operation)
        : 'Update';
    final target = update.target;
    final secondary = [
      if (target != null) '${target.displayName} ${target.id}',
      if (update.operatorName.isNotEmpty) update.operatorName,
      _formatTimestamp(update.timestamp.toLocal()),
    ].where((s) => s.isNotEmpty).join(' · ');

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(secondary),
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

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
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
