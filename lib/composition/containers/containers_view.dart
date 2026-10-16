import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/containers/containers_provider.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/router/polling_route_aware_state.dart';
import 'package:komodo_go/core/router/shell_state_provider.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/dialogs/confirm_destructive_dialog.dart';
import 'package:komodo_go/core/widgets/empty_error_state.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/menus/komodo_select_menu_field.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card_support.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_view_controls.dart';
import 'package:komodo_go/features/containers/data/models/container.dart';
import 'package:komodo_go/features/containers/presentation/providers/containers_filters_provider.dart';
import 'package:komodo_go/features/containers/presentation/widgets/container_card.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/shared/resources/providers/resource_view_prefs_provider.dart';
import 'package:komodo_go/shared/resources/resource_sorting.dart';

class ContainersView extends ConsumerStatefulWidget {
  const ContainersView({super.key});

  @override
  ConsumerState<ContainersView> createState() => _ContainersViewState();
}

class _ContainersViewState extends PollingRouteAwareState<ContainersView> {
  static const _pollInterval = Duration(seconds: 10);
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
    _refreshTimer = Timer.periodic(_pollInterval, (_) {
      if (!shouldRunPollTick()) return;
      unawaited(ref.read(containersProvider.notifier).pollRefresh());
    });
    unawaited(ref.read(containersProvider.notifier).pollRefresh());
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
    final actionsState = ref.watch(containerActionsProvider);
    final serversAsync = ref.watch(serversProvider);
    final selectedServerId = ref.watch(containersServerFilterProvider);
    final searchQuery = ref.watch(containersSearchQueryProvider);
    final sortState = ref.watch(containersSortProvider);
    final isActiveTab = ref.watch(mainShellIndexProvider) == 2;
    const listId = 'containers';
    final prefs = watchResourceViewPrefs(ref, listId);
    final activeFilterCount =
        (searchQuery.trim().isEmpty ? 0 : 1) +
        (selectedServerId == null ? 0 : 1) +
        prefs.activeCount;
    final stateOptions = collectDistinct<ContainerOverviewItem>(
      containersAsync.maybeWhen(
        data: (result) => result.items,
        orElse: () => const <ContainerOverviewItem>[],
      ),
      (item) => resourceStateLabel(item.container.state),
    );
    void clearAllFilters() {
      _searchController.clear();
      ref.read(containersSearchQueryProvider.notifier).query = '';
      ref.read(containersServerFilterProvider.notifier).serverId = null;
      clearResourceViewFilters(ref, listId);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncRefreshTimer(isActiveTab: isActiveTab);
    });

    return Scaffold(
      appBar: MainAppBar(
        title: 'Containers',
        icon: AppIcons.containers,
        actions: [
          ResourceFilterToggleButton(
            visible: _isSearchVisible,
            activeCount: activeFilterCount,
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
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () =>
                      ref.read(containersProvider.notifier).refresh(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _FiltersRow(
                        servers: serversAsync.maybeWhen(
                          data: (servers) => servers,
                          orElse: () => const <Server>[],
                        ),
                        selectedServerId: selectedServerId,
                        onServerChanged: (value) =>
                            ref
                                    .read(
                                      containersServerFilterProvider.notifier,
                                    )
                                    .serverId =
                                value,
                        stateOptions: stateOptions,
                        problemsOnly: prefs.problemsOnly,
                        selectedStates: prefs.states,
                        onFilterChanged: (value) =>
                            _setQuickFilter(value, listId),
                      ),
                      const Gap(AppSpacing.md),
                      _SortRow(
                        sortState: sortState,
                        onFieldChanged: (value) =>
                            ref.read(containersSortProvider.notifier).field =
                                value,
                        onToggleDirection: () => ref
                            .read(containersSortProvider.notifier)
                            .toggleDirection(),
                      ),
                      AnimatedSwitcher(
                        duration: AppMotion.base,
                        switchInCurve: AppMotion.enterCurve,
                        switchOutCurve: AppMotion.exitCurve,
                        child: _isSearchVisible
                            ? Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: _SearchField(
                                  focusNode: _searchFocusNode,
                                  controller: _searchController,
                                  onChanged: (value) =>
                                      ref
                                              .read(
                                                containersSearchQueryProvider
                                                    .notifier,
                                              )
                                              .query =
                                          value,
                                  onClear: () {
                                    _searchController.clear();
                                    ref
                                            .read(
                                              containersSearchQueryProvider
                                                  .notifier,
                                            )
                                            .query =
                                        '';
                                  },
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (!_isSearchVisible &&
                          searchQuery.trim().isNotEmpty) ...[
                        const Gap(8),
                        ResourceActiveFilterChips(
                          listId: listId,
                          includeQuickFilters: false,
                          onClearAll: clearAllFilters,
                          extraChips: [
                            ActiveFilterChip(
                              label: 'Search: ${searchQuery.trim()}',
                              onRemove: () {
                                _searchController.clear();
                                ref
                                        .read(
                                          containersSearchQueryProvider
                                              .notifier,
                                        )
                                        .query =
                                    '';
                              },
                            ),
                          ],
                        ),
                      ],
                      const Gap(12),
                      containersAsync.when(
                        skipLoadingOnRefresh: true,
                        skipLoadingOnReload: true,
                        data: (result) {
                          final filtered = _applyFilters(
                            result.items,
                            serverId: selectedServerId,
                            query: searchQuery,
                            sort: sortState,
                            problemsOnly: prefs.problemsOnly,
                            states: prefs.states,
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
                              for (var i = 0; i < filtered.length; i++) ...[
                                AppFadeSlide(
                                  delay: AppMotion.stagger(i),
                                  play: i < 10,
                                  child: ContainerCard(
                                    item: filtered[i],
                                    onTap: () {
                                      final containerKey =
                                          filtered[i].container.id ??
                                          filtered[i].container.name;
                                      unawaited(
                                        context.push(
                                          '${AppRoutes.containers}/${filtered[i].serverId}/${Uri.encodeComponent(containerKey)}',
                                          extra: filtered[i],
                                        ),
                                      );
                                    },
                                    onAction: (action) => unawaited(
                                      _handleAction(
                                        context,
                                        ref,
                                        filtered[i],
                                        action,
                                      ),
                                    ),
                                  ),
                                ),
                                const Gap(12),
                              ],
                              const SizedBox(height: 12),
                            ],
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: _ContainersSkeletonBlock(),
                        ),
                        error: (error, stack) => ErrorStateView(
                          title: 'Failed to load containers',
                          message: error.toString(),
                          onRetry: () => ref.invalidate(containersProvider),
                        ),
                      ),
                    ],
                  ),
                ),
                if (actionsState.isLoading)
                  ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.scrim.withValues(alpha: 0.25),
                    child: const Center(child: AppSkeletonCard()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _setQuickFilter(String value, String listId) {
    final problems = ref.read(resourceProblemsOnlyProvider(listId).notifier);
    final states = ref.read(resourceStateFilterProvider(listId).notifier);
    problems.enabled = value == _filterProblems;
    states.selected = value == _filterAll || value == _filterProblems
        ? <String>{}
        : {value};
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    ContainerOverviewItem item,
    ContainerAction action,
  ) async {
    final containerIdOrName = (item.container.id?.trim().isNotEmpty ?? false)
        ? item.container.id!.trim()
        : item.container.name.trim();

    if (containerIdOrName.isEmpty) {
      AppSnackBar.show(
        context,
        'Missing container identifier.',
        tone: AppSnackBarTone.error,
      );
      return;
    }

    final actions = ref.read(containerActionsProvider.notifier);
    if (action == ContainerAction.remove || action == ContainerAction.stop) {
      final remove = action == ContainerAction.remove;
      final confirmed = await confirmDestructive(
        context,
        title: remove
            ? 'Remove ${item.container.name}?'
            : 'Stop ${item.container.name}?',
        message: remove
            ? 'This permanently removes "${item.container.name}". '
                  'A managed Stack or Deployment may recreate it.'
            : 'This will stop "${item.container.name}".',
        confirmLabel: remove ? 'Remove' : 'Stop',
      );
      if (!confirmed || !context.mounted) return;
    }
    final success = await switch (action) {
      ContainerAction.start => actions.start(
        serverIdOrName: item.serverId,
        containerIdOrName: containerIdOrName,
      ),
      ContainerAction.restart => actions.restart(
        serverIdOrName: item.serverId,
        containerIdOrName: containerIdOrName,
      ),
      ContainerAction.stop => actions.stop(
        serverIdOrName: item.serverId,
        containerIdOrName: containerIdOrName,
      ),
      ContainerAction.pause => actions.pause(
        serverIdOrName: item.serverId,
        containerIdOrName: containerIdOrName,
      ),
      ContainerAction.unpause => actions.unpause(
        serverIdOrName: item.serverId,
        containerIdOrName: containerIdOrName,
      ),
      ContainerAction.remove => actions.remove(
        serverIdOrName: item.serverId,
        containerIdOrName: containerIdOrName,
      ),
    };

    if (context.mounted) {
      AppSnackBar.show(
        context,
        success
            ? 'Action submitted. Check updates for the result.'
            : 'Action failed. Please try again.',
        tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
      );
    }
  }
}

const _filterAll = '__all__';
const _filterProblems = '__problems__';

/// Top row: Server dropdown (left half) and quick Filter dropdown (right half).
class _FiltersRow extends StatelessWidget {
  const _FiltersRow({
    required this.servers,
    required this.selectedServerId,
    required this.onServerChanged,
    required this.stateOptions,
    required this.problemsOnly,
    required this.selectedStates,
    required this.onFilterChanged,
  });

  final List<Server> servers;
  final String? selectedServerId;
  final ValueChanged<String?> onServerChanged;
  final List<String> stateOptions;
  final bool problemsOnly;
  final Set<String> selectedStates;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final states = {...stateOptions, ...selectedStates}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final filterValue = problemsOnly
        ? _filterProblems
        : (selectedStates.isEmpty ? _filterAll : selectedStates.first);

    return Row(
      children: [
        Expanded(
          child: KomodoSelectMenuField<String?>(
            key: const ValueKey('containers_server_filter'),
            value: selectedServerId,
            decoration: const InputDecoration(
              labelText: 'Server',
              prefixIcon: Icon(AppIcons.server),
            ),
            items: [
              const KomodoSelectMenuItem(value: null, label: 'All servers'),
              for (final server in servers)
                KomodoSelectMenuItem(value: server.id, label: server.name),
            ],
            onChanged: onServerChanged,
          ),
        ),
        const Gap(AppSpacing.sm),
        Expanded(
          child: KomodoSelectMenuField<String>(
            key: const ValueKey('containers_state_filter'),
            value: filterValue,
            decoration: const InputDecoration(
              labelText: 'Filter',
              prefixIcon: Icon(Icons.filter_list_rounded),
            ),
            items: [
              const KomodoSelectMenuItem(value: _filterAll, label: 'All'),
              const KomodoSelectMenuItem(
                value: _filterProblems,
                label: 'Problems only',
              ),
              for (final state in states)
                KomodoSelectMenuItem(value: state, label: state),
            ],
            onChanged: (value) {
              if (value != null) onFilterChanged(value);
            },
          ),
        ),
      ],
    );
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final directionIcon = sortState.descending
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;
    final directionLabel = sortState.descending ? 'Descending' : 'Ascending';

    return Row(
      children: [
        Expanded(
          child: KomodoSelectMenuField<ContainersSortField>(
            key: const ValueKey('containers_sort_field'),
            value: sortState.field,
            decoration: const InputDecoration(
              labelText: 'Sort by',
              prefixIcon: Icon(Icons.sort),
            ),
            items: const [
              KomodoSelectMenuItem(
                value: ContainersSortField.name,
                label: 'Name',
              ),
              KomodoSelectMenuItem(
                value: ContainersSortField.cpu,
                label: 'CPU',
              ),
              KomodoSelectMenuItem(
                value: ContainersSortField.memory,
                label: 'Memory',
              ),
              KomodoSelectMenuItem(
                value: ContainersSortField.network,
                label: 'Network I/O',
              ),
              KomodoSelectMenuItem(
                value: ContainersSortField.blockIo,
                label: 'Drive I/O',
              ),
              KomodoSelectMenuItem(
                value: ContainersSortField.pids,
                label: 'PIDs',
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              onFieldChanged(value);
            },
          ),
        ),
        const Gap(AppSpacing.sm),
        Material(
          color: theme.cardTheme.color ?? scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          child: IconButton(
            key: const ValueKey('containers_sort_direction'),
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
  bool problemsOnly = false,
  Set<String> states = const {},
}) {
  final normalizedQuery = query.trim().toLowerCase();

  final filtered = items.where((item) {
    if (serverId != null && item.serverId != serverId) return false;
    if (problemsOnly &&
        containerSeverity(item.container) > ResourceSeverity.maxProblem) {
      return false;
    }
    if (states.isNotEmpty &&
        !states.contains(resourceStateLabel(item.container.state))) {
      return false;
    }
    if (normalizedQuery.isEmpty) return true;

    final name = item.container.name.toLowerCase();
    final image = (item.container.image ?? '').toLowerCase();
    final serverName = item.serverName.toLowerCase();
    return name.contains(normalizedQuery) ||
        image.contains(normalizedQuery) ||
        serverName.contains(normalizedQuery);
  }).toList();

  return filtered..sort((a, b) => _compareBySort(a, b, sort));
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

class _ContainersSkeletonBlock extends StatelessWidget {
  const _ContainersSkeletonBlock();

  @override
  Widget build(BuildContext context) {
    return const ResourceCardSkeletonList(
      title: 'Container name',
      metaLeft: 'Server',
      metaRight: 'image:latest',
      count: 3,
      padding: EdgeInsets.zero,
      bottom: Row(
        children: [
          ResourceIconLabel(icon: AppIcons.cpu, label: 'CPU 0.5%'),
          SizedBox(width: AppSpacing.md),
          ResourceIconLabel(icon: AppIcons.memory, label: 'Mem 128MiB / 1GiB'),
        ],
      ),
    );
  }
}

/// Severity bucket of a container, see [ResourceSeverity].
///
/// An exited container with a non-zero exit code needs attention.
int containerSeverity(ContainerListItem container) {
  return switch (container.state) {
    ContainerState.dead => ResourceSeverity.attention,
    ContainerState.exited =>
      _exitedWithError(container.status)
          ? ResourceSeverity.attention
          : ResourceSeverity.inactive,
    ContainerState.restarting ||
    ContainerState.removing => ResourceSeverity.warning,
    ContainerState.running => ResourceSeverity.healthy,
    ContainerState.created ||
    ContainerState.paused ||
    ContainerState.unknown => ResourceSeverity.inactive,
  };
}

bool _exitedWithError(String? status) {
  final match = RegExp(r'Exited \((\d+)\)').firstMatch(status ?? '');
  return match != null && match.group(1) != '0';
}
