import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/router/polling_route_aware_state.dart';
import '../../../../core/router/shell_state_provider.dart';
import '../../../../core/widgets/main_app_bar.dart';
import '../../../servers/data/models/server.dart';
import '../../../servers/presentation/providers/servers_provider.dart';
import '../providers/containers_filters_provider.dart';
import '../providers/containers_provider.dart';
import '../widgets/container_card.dart';

class ContainersView extends ConsumerStatefulWidget {
  const ContainersView({super.key});

  @override
  ConsumerState<ContainersView> createState() => _ContainersViewState();
}

class _ContainersViewState
    extends PollingRouteAwareState<ContainersView> {
  Timer? _refreshTimer;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  ProviderSubscription<String>? _searchQuerySubscription;
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(containersSearchQueryProvider),
    );
    _searchFocusNode = FocusNode();
    _searchQuerySubscription = ref.listenManual<String>(
      containersSearchQueryProvider,
      (previous, next) {
        if (_searchController.text == next) return;
        final selection = _searchController.selection;
        _searchController.text = next;
        _searchController.selection = selection.copyWith(
          baseOffset: _searchController.text.length,
          extentOffset: _searchController.text.length,
        );
      },
    );
  }

  @override
  void dispose() {
    _stopRefreshTimer();
    _searchQuerySubscription?.close();
    _searchQuerySubscription = null;
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void onVisibilityChanged() {
    if (!mounted) return;
    _syncRefreshTimer(isActiveTab: ref.read(mainShellIndexProvider) == 2);
    super.onVisibilityChanged();
  }

  void _startRefreshTimer() {
    if (_refreshTimer != null) return;
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      ref.invalidate(containersProvider);
    });
    ref.invalidate(containersProvider);
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _syncRefreshTimer({required bool isActiveTab}) {
    if (shouldPoll(isActiveTab: isActiveTab)) {
      _startRefreshTimer();
    } else {
      _stopRefreshTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final containersAsync = ref.watch(containersProvider);
    final serversAsync = ref.watch(serversProvider);
    final selectedServerId = ref.watch(containersServerFilterProvider);
    final searchQuery = ref.watch(containersSearchQueryProvider);
    final sortState = ref.watch(containersSortProvider);
    final isActiveTab = ref.watch(mainShellIndexProvider) == 2;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncRefreshTimer(isActiveTab: isActiveTab);
    });

    return Scaffold(
      appBar: MainAppBar(
        title: 'Containers',
        icon: AppIcons.containers,
        actions: [
          IconButton(
            tooltip: _isSearchVisible ? 'Hide search' : 'Search',
            icon: Icon(_isSearchVisible ? Icons.close : Icons.search),
            onPressed: () {
              setState(() => _isSearchVisible = !_isSearchVisible);
              if (_isSearchVisible) {
                Future<void>.delayed(const Duration(milliseconds: 50), () {
                  if (context.mounted) _searchFocusNode.requestFocus();
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
            const Gap(12),
            _SortRow(
              sortState: sortState,
              onFieldChanged: (value) => ref
                  .read(containersSortProvider.notifier)
                  .setField(value),
              onToggleDirection: () => ref
                  .read(containersSortProvider.notifier)
                  .toggleDirection(),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _isSearchVisible
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _SearchField(
                        focusNode: _searchFocusNode,
                        controller: _searchController,
                        onChanged: (value) => ref
                            .read(containersSearchQueryProvider.notifier)
                            .setQuery(value),
                        onClear: () {
                          _searchController.clear();
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
                  sort: sortState,
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

class _SortRow extends StatelessWidget {
  const _SortRow({
    required this.sortState,
    required this.onFieldChanged,
    required this.onToggleDirection,
  });

  final ContainersSortState sortState;
  final ValueChanged<ContainersSortField> onFieldChanged;
  final VoidCallback onToggleDirection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final directionIcon = sortState.descending
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;
    final directionLabel =
        sortState.descending ? 'Descending' : 'Ascending';

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<ContainersSortField>(
            value: sortState.field,
            decoration: const InputDecoration(
              labelText: 'Sort by',
              prefixIcon: Icon(Icons.sort),
            ),
            items: const [
              DropdownMenuItem(
                value: ContainersSortField.name,
                child: Text('Name'),
              ),
              DropdownMenuItem(
                value: ContainersSortField.cpu,
                child: Text('CPU'),
              ),
              DropdownMenuItem(
                value: ContainersSortField.memory,
                child: Text('Memory'),
              ),
              DropdownMenuItem(
                value: ContainersSortField.network,
                child: Text('Network I/O'),
              ),
              DropdownMenuItem(
                value: ContainersSortField.blockIo,
                child: Text('Drive I/O'),
              ),
              DropdownMenuItem(
                value: ContainersSortField.pids,
                child: Text('PIDs'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              onFieldChanged(value);
            },
          ),
        ),
        const Gap(8),
        Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          child: IconButton(
            tooltip: directionLabel,
            icon: Icon(directionIcon),
            onPressed: onToggleDirection,
          ),
        ),
      ],
    );
  }
}

List<ContainerOverviewItem> _applyFilters(
  List<ContainerOverviewItem> items, {
  required String? serverId,
  required String query,
  required ContainersSortState sort,
}) {
  final normalizedQuery = query.trim().toLowerCase();

  final filtered = items.where((item) {
    if (serverId != null && item.serverId != serverId) return false;
    if (normalizedQuery.isEmpty) return true;

    final name = item.container.name.toLowerCase();
    final image = (item.container.image ?? '').toLowerCase();
    final serverName = item.serverName.toLowerCase();
    return name.contains(normalizedQuery) ||
        image.contains(normalizedQuery) ||
        serverName.contains(normalizedQuery);
  }).toList();

  filtered.sort((a, b) => _compareBySort(a, b, sort));
  return filtered;
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

int _compareBySort(
  ContainerOverviewItem a,
  ContainerOverviewItem b,
  ContainersSortState sort,
) {
  final nameA = a.container.name.toLowerCase();
  final nameB = b.container.name.toLowerCase();

  final result = switch (sort.field) {
    ContainersSortField.name =>
      sort.descending ? -nameA.compareTo(nameB) : nameA.compareTo(nameB),
    ContainersSortField.cpu => _compareMetric(
      a.container.stats?.cpuPercentValue,
      b.container.stats?.cpuPercentValue,
      sort.descending,
    ),
    ContainersSortField.memory => _compareMetric(
      a.container.stats?.memPercentValue,
      b.container.stats?.memPercentValue,
      sort.descending,
    ),
    ContainersSortField.network => _compareMetric(
      a.container.stats?.netIoTotalBytes,
      b.container.stats?.netIoTotalBytes,
      sort.descending,
    ),
    ContainersSortField.blockIo => _compareMetric(
      a.container.stats?.blockIoTotalBytes,
      b.container.stats?.blockIoTotalBytes,
      sort.descending,
    ),
    ContainersSortField.pids => _compareMetric(
      a.container.stats?.pidsValue?.toDouble(),
      b.container.stats?.pidsValue?.toDouble(),
      sort.descending,
    ),
  };

  if (result != 0) return result;
  return nameA.compareTo(nameB);
}

int _compareMetric(double? a, double? b, bool descending) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  final cmp = a.compareTo(b);
  return descending ? -cmp : cmp;
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
