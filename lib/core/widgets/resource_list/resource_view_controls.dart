import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/filters/app_filter_chip.dart';
import 'package:komodo_go/shared/resources/providers/resource_view_prefs_provider.dart';
import 'package:komodo_go/shared/resources/resource_sorting.dart';

/// Snapshot of the session-scoped sort and quick-filter choices of one list.
class ResourceViewPrefs {
  const ResourceViewPrefs({
    required this.sortMode,
    required this.problemsOnly,
    required this.states,
    required this.servers,
  });

  final ResourceSortMode sortMode;
  final bool problemsOnly;
  final Set<String> states;
  final Set<String> servers;

  /// Count of active quick filters (problems/state/server; not sort).
  int get activeCount =>
      (problemsOnly ? 1 : 0) + states.length + servers.length;

  /// Applies quick filters, then sorts.
  List<T> process<T>(
    List<T> items, {
    required int Function(T item) severityOf,
    required String Function(T item) nameOf,
    int Function(T item)? updatedAtOf,
    String Function(T item)? stateLabelOf,
    String? Function(T item)? serverNameOf,
  }) {
    final filtered = applyResourceViewFilters<T>(
      items,
      problemsOnly: problemsOnly,
      selectedStates: states,
      selectedServers: servers,
      severityOf: severityOf,
      stateLabelOf: stateLabelOf,
      serverNameOf: serverNameOf,
    );
    return sortResources<T>(
      filtered,
      mode: sortMode,
      severityOf: severityOf,
      nameOf: nameOf,
      updatedAtOf: updatedAtOf,
    );
  }
}

/// Watches the sort and quick-filter providers of [listId].
ResourceViewPrefs watchResourceViewPrefs(WidgetRef ref, String listId) {
  return ResourceViewPrefs(
    sortMode: ref.watch(resourceSortModeStateProvider(listId)),
    problemsOnly: ref.watch(resourceProblemsOnlyProvider(listId)),
    states: ref.watch(resourceStateFilterProvider(listId)),
    servers: ref.watch(resourceServerFilterProvider(listId)),
  );
}

/// Resets problems-only, state and server filters (sort is kept).
void clearResourceViewFilters(WidgetRef ref, String listId) {
  ref.read(resourceProblemsOnlyProvider(listId).notifier).enabled = false;
  ref.read(resourceStateFilterProvider(listId).notifier).clear();
  ref.read(resourceServerFilterProvider(listId).notifier).clear();
}

/// Search/filter AppBar action with a badge showing the active filter count.
class ResourceFilterToggleButton extends StatelessWidget {
  const ResourceFilterToggleButton({
    required this.visible,
    required this.activeCount,
    required this.onPressed,
    super.key,
  });

  final bool visible;
  final int activeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: visible ? 'Hide search' : 'Search',
      icon: Badge(
        isLabelVisible: activeCount > 0 && !visible,
        label: Text('$activeCount'),
        child: Icon(visible ? Icons.close : Icons.search),
      ),
      onPressed: onPressed,
    );
  }
}

/// Compact sort menu chip for the generic list sort modes.
class ResourceSortMenuChip extends ConsumerWidget {
  const ResourceSortMenuChip({
    required this.listId,
    this.supportsRecentlyUpdated = false,
    super.key,
  });

  final String listId;
  final bool supportsRecentlyUpdated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortMode = ref.watch(resourceSortModeStateProvider(listId));
    final modes = [
      for (final mode in ResourceSortMode.values)
        if (mode != ResourceSortMode.recentlyUpdated || supportsRecentlyUpdated)
          mode,
    ];
    final effective = modes.contains(sortMode)
        ? sortMode
        : ResourceSortMode.problemsFirst;
    return AppFilterMenuChip<ResourceSortMode>(
      key: ValueKey('resource_sort_$listId'),
      icon: Icons.sort,
      label: effective.label,
      value: effective,
      options: [
        for (final mode in modes)
          AppFilterMenuOption(value: mode, label: mode.label),
      ],
      onSelected: (mode) =>
          ref.read(resourceSortModeStateProvider(listId).notifier).mode = mode,
    );
  }
}

/// Thin separator between chip groups inside an [AppFilterChipBar].
class ResourceChipGroupDivider extends StatelessWidget {
  const ResourceChipGroupDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

/// "Problems only" and state chips shared by every resource list.
///
/// Intended as children of an [AppFilterChipBar].
List<Widget> buildResourceQuickFilterChips(
  WidgetRef ref, {
  required String listId,
  required List<String> stateOptions,
}) {
  final problemsOnly = ref.watch(resourceProblemsOnlyProvider(listId));
  final states = ref.watch(resourceStateFilterProvider(listId));
  // Keep selected values visible even if no item currently carries them.
  final allStates = {...stateOptions, ...states}.toList();
  return [
    AppFilterChip(
      key: ValueKey('resource_problems_only_$listId'),
      icon: Icons.warning_amber_rounded,
      label: 'Problems only',
      selected: problemsOnly,
      onSelected: (value) =>
          ref.read(resourceProblemsOnlyProvider(listId).notifier).enabled =
              value,
    ),
    for (final state in allStates)
      AppFilterChip(
        label: state,
        selected: states.contains(state),
        onSelected: (_) => ref
            .read(resourceStateFilterProvider(listId).notifier)
            .toggle(state),
      ),
  ];
}

/// Single scrollable chip row: sort, "Problems only", state and server chips.
///
/// Meant to be placed at the top of a filters panel.
class ResourceViewFiltersSection extends ConsumerWidget {
  const ResourceViewFiltersSection({
    required this.listId,
    required this.stateOptions,
    this.serverOptions = const [],
    this.supportsRecentlyUpdated = false,
    this.showSort = true,
    this.extraChips = const [],
    super.key,
  });

  final String listId;
  final bool showSort;
  final List<Widget> extraChips;
  final List<String> stateOptions;
  final List<String> serverOptions;
  final bool supportsRecentlyUpdated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(resourceServerFilterProvider(listId));
    final allServers = {...serverOptions, ...servers}.toList();

    return AppFilterChipBar(
      padding: EdgeInsets.zero,
      verticalPadding: 0,
      children: [
        if (showSort)
          ResourceSortMenuChip(
            listId: listId,
            supportsRecentlyUpdated: supportsRecentlyUpdated,
          ),
        ...buildResourceQuickFilterChips(
          ref,
          listId: listId,
          stateOptions: stateOptions,
        ),
        if (allServers.isNotEmpty) const ResourceChipGroupDivider(),
        for (final server in allServers)
          AppFilterChip(
            icon: AppIcons.server,
            label: server,
            selected: servers.contains(server),
            onSelected: (_) => ref
                .read(resourceServerFilterProvider(listId).notifier)
                .toggle(server),
          ),
        ...extraChips,
      ],
    );
  }
}

/// A removable summary chip for one active filter.
class ActiveFilterChip {
  const ActiveFilterChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;
}

/// Compact removable chip row summarising active filters, with "Clear all".
///
/// Renders nothing when there are no chips. Shared problems/state/server chips
/// are produced here; [extraChips] carry kind-specific ones (search, tags,
/// templates, pending updates).
class ResourceActiveFilterChips extends ConsumerWidget {
  const ResourceActiveFilterChips({
    required this.listId,
    required this.onClearAll,
    this.extraChips = const [],
    this.includeQuickFilters = true,
    super.key,
  });

  final bool includeQuickFilters;
  final String listId;
  final VoidCallback onClearAll;
  final List<ActiveFilterChip> extraChips;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final problemsOnly = ref.watch(resourceProblemsOnlyProvider(listId));
    final states = ref.watch(resourceStateFilterProvider(listId));
    final servers = ref.watch(resourceServerFilterProvider(listId));

    final chips = <ActiveFilterChip>[
      ...extraChips,
      if (includeQuickFilters && problemsOnly)
        ActiveFilterChip(
          label: 'Problems only',
          onRemove: () =>
              ref.read(resourceProblemsOnlyProvider(listId).notifier).enabled =
                  false,
        ),
      if (includeQuickFilters)
        for (final state in states)
          ActiveFilterChip(
            label: 'State: $state',
            onRemove: () => ref
                .read(resourceStateFilterProvider(listId).notifier)
                .toggle(
                  state,
                ),
          ),
      if (includeQuickFilters)
        for (final server in servers)
          ActiveFilterChip(
            label: 'Server: $server',
            onRemove: () => ref
                .read(resourceServerFilterProvider(listId).notifier)
                .toggle(
                  server,
                ),
          ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView(
        key: ValueKey('resource_active_filters_$listId'),
        scrollDirection: Axis.horizontal,
        children: [
          for (final chip in chips) ...[
            InputChip(
              label: Text(chip.label),
              visualDensity: VisualDensity.compact,
              onDeleted: chip.onRemove,
              deleteButtonTooltipMessage: 'Remove ${chip.label}',
            ),
            const Gap(8),
          ],
          TextButton(
            onPressed: onClearAll,
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
  }
}
