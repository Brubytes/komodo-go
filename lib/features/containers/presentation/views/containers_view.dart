import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

import '../../../servers/data/models/server.dart';
import '../../../servers/presentation/providers/servers_provider.dart';
import '../providers/containers_filters_provider.dart';
import '../providers/containers_provider.dart';
import '../widgets/container_card.dart';

class ContainersView extends ConsumerWidget {
  const ContainersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final containersAsync = ref.watch(containersProvider);
    final serversAsync = ref.watch(serversProvider);
    final selectedServerId = ref.watch(containersServerFilterProvider);
    final searchQuery = ref.watch(containersSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Containers'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(AppIcons.refresh),
            onPressed: () => ref.invalidate(containersProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(containersProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _FiltersRow(
              serversAsync: serversAsync,
              selectedServerId: selectedServerId,
              searchQuery: searchQuery,
              onServerChanged: (value) => ref
                  .read(containersServerFilterProvider.notifier)
                  .setServerId(value),
              onSearchChanged: (value) => ref
                  .read(containersSearchQueryProvider.notifier)
                  .setQuery(value),
            ),
            const Gap(12),
            containersAsync.when(
              data: (result) {
                final filtered = _applyFilters(
                  result.items,
                  serverId: selectedServerId,
                  query: searchQuery,
                );

                if (filtered.isEmpty) {
                  return const _EmptyState();
                }

                return Column(
                  children: [
                    if (result.errors.isNotEmpty) ...[
                      _PartialErrorBanner(errors: result.errors),
                      const Gap(12),
                    ],
                    for (final item in filtered) ...[
                      ContainerCard(item: item),
                      const Gap(12),
                    ],
                    const SizedBox(height: 12),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => _ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(containersProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FiltersRow extends StatelessWidget {
  const _FiltersRow({
    required this.serversAsync,
    required this.selectedServerId,
    required this.searchQuery,
    required this.onServerChanged,
    required this.onSearchChanged,
  });

  final AsyncValue<List<Server>> serversAsync;
  final String? selectedServerId;
  final String searchQuery;
  final ValueChanged<String?> onServerChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 520;

    final serverField = serversAsync.maybeWhen(
      data: (servers) => DropdownButtonFormField<String?>(
        value: selectedServerId,
        decoration: const InputDecoration(
          labelText: 'Server',
          prefixIcon: Icon(AppIcons.server),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('All servers')),
          for (final server in servers)
            DropdownMenuItem(value: server.id, child: Text(server.name)),
        ],
        onChanged: onServerChanged,
      ),
      orElse: () => DropdownButtonFormField<String?>(
        value: null,
        decoration: const InputDecoration(
          labelText: 'Server',
          prefixIcon: Icon(AppIcons.server),
        ),
        items: const [
          DropdownMenuItem(value: null, child: Text('All servers')),
        ],
        onChanged: null,
      ),
    );

    final searchField = TextFormField(
      initialValue: searchQuery,
      onChanged: onSearchChanged,
      decoration: const InputDecoration(
        labelText: 'Search',
        prefixIcon: Icon(Icons.search),
      ),
    );

    if (isNarrow) {
      return Column(children: [serverField, const Gap(12), searchField]);
    }

    return Row(
      children: [
        Expanded(child: serverField),
        const Gap(12),
        Expanded(child: searchField),
      ],
    );
  }
}

List<ContainerOverviewItem> _applyFilters(
  List<ContainerOverviewItem> items, {
  required String? serverId,
  required String query,
}) {
  final normalizedQuery = query.trim().toLowerCase();

  return items.where((item) {
    if (serverId != null && item.serverId != serverId) return false;
    if (normalizedQuery.isEmpty) return true;

    final name = item.container.name.toLowerCase();
    final image = (item.container.image ?? '').toLowerCase();
    final serverName = item.serverName.toLowerCase();
    return name.contains(normalizedQuery) ||
        image.contains(normalizedQuery) ||
        serverName.contains(normalizedQuery);
  }).toList();
}

class _PartialErrorBanner extends StatelessWidget {
  const _PartialErrorBanner({required this.errors});

  final List<ContainerFetchError> errors;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final message = errors.length == 1
        ? 'Failed to load containers from ${errors.first.serverName}.'
        : 'Failed to load containers from ${errors.length} servers.';

    return Card(
      color: scheme.errorContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(AppIcons.warning, color: scheme.onErrorContainer),
            const Gap(10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 72),
      child: Center(
        child: Column(
          children: [
            Icon(
              AppIcons.containers,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const Gap(16),
            Text(
              'No containers found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Gap(8),
            Text(
              'Try adjusting filters or check your servers.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 72),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                AppIcons.formError,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const Gap(16),
              Text(
                'Failed to load containers',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Gap(8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const Gap(24),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
