import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/main_app_bar.dart';
import '../../../servers/data/models/server.dart';
import '../../../servers/presentation/providers/servers_provider.dart';
import '../providers/containers_filters_provider.dart';
import '../providers/containers_provider.dart';
import '../widgets/container_card.dart';

class ContainersView extends HookConsumerWidget {
  const ContainersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final containersAsync = ref.watch(containersProvider);
    final serversAsync = ref.watch(serversProvider);
    final selectedServerId = ref.watch(containersServerFilterProvider);
    final searchQuery = ref.watch(containersSearchQueryProvider);
    final isSearchVisible = useState(false);
    final searchFocusNode = useFocusNode();
    final searchController = useTextEditingController(text: searchQuery);

    useEffect(() {
      if (searchController.text == searchQuery) return null;
      final selection = searchController.selection;
      searchController.text = searchQuery;
      searchController.selection = selection.copyWith(
        baseOffset: searchController.text.length,
        extentOffset: searchController.text.length,
      );
      return null;
    }, [searchQuery]);

    return Scaffold(
      appBar: MainAppBar(
        title: 'Containers',
        icon: AppIcons.containers,
        actions: [
          IconButton(
            tooltip: isSearchVisible.value ? 'Hide search' : 'Search',
            icon: Icon(isSearchVisible.value ? Icons.close : Icons.search),
            onPressed: () {
              isSearchVisible.value = !isSearchVisible.value;
              if (isSearchVisible.value) {
                Future<void>.delayed(const Duration(milliseconds: 50), () {
                  if (context.mounted) searchFocusNode.requestFocus();
                });
              } else {
                FocusManager.instance.primaryFocus?.unfocus();
              }
            },
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
              onServerChanged: (value) => ref
                  .read(containersServerFilterProvider.notifier)
                  .setServerId(value),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: isSearchVisible.value
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _SearchField(
                        focusNode: searchFocusNode,
                        controller: searchController,
                        onChanged: (value) => ref
                            .read(containersSearchQueryProvider.notifier)
                            .setQuery(value),
                        onClear: () {
                          searchController.clear();
                          ref
                              .read(containersSearchQueryProvider.notifier)
                              .setQuery('');
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
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
                      ContainerCard(
                        item: item,
                        onTap: () {
                          final containerKey =
                              item.container.id ?? item.container.name;
                          context.push(
                            '${AppRoutes.containers}/${item.serverId}/${Uri.encodeComponent(containerKey)}',
                            extra: item,
                          );
                        },
                      ),
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
    required this.onServerChanged,
  });

  final AsyncValue<List<Server>> serversAsync;
  final String? selectedServerId;
  final ValueChanged<String?> onServerChanged;

  @override
  Widget build(BuildContext context) {
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

    return serverField;
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.focusNode,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final FocusNode focusNode;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('containers_search'),
      focusNode: focusNode,
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: 'Search',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.trim().isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close),
                onPressed: onClear,
              ),
      ),
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
