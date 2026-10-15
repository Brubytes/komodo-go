import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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

/// Sort selector, "Problems only" chip, and state/server chips.
///
/// Meant to be placed at the top of a filters panel.
class ResourceViewFiltersSection extends ConsumerWidget {
  const ResourceViewFiltersSection({
    required this.listId,
    required this.stateOptions,
    this.serverOptions = const [],
    this.supportsRecentlyUpdated = false,
    this.showSort = true,
    super.key,
  });

  final String listId;
  final bool showSort;
  final List<String> stateOptions;
  final List<String> serverOptions;
  final bool supportsRecentlyUpdated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sortMode = ref.watch(resourceSortModeStateProvider(listId));
    final problemsOnly = ref.watch(resourceProblemsOnlyProvider(listId));
    final states = ref.watch(resourceStateFilterProvider(listId));
    final servers = ref.watch(resourceServerFilterProvider(listId));
    final modes = [
      for (final mode in ResourceSortMode.values)
        if (mode != ResourceSortMode.recentlyUpdated || supportsRecentlyUpdated)
          mode,
    ];
    final effectiveSort = modes.contains(sortMode)
        ? sortMode
        : ResourceSortMode.problemsFirst;

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );

    Widget chips(
      List<String> options,
      Set<String> selected,
      void Function(String) onToggle,
    ) {
      // Keep selected values visible even if no item currently carries them.
      final all = {...options, ...selected}.toList();
      return Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final option in all)
            FilterChip(
              label: Text(option),
              selected: selected.contains(option),
              visualDensity: VisualDensity.compact,
              onSelected: (_) => onToggle(option),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSort) ...[
          Row(
            children: [
              Icon(Icons.sort, size: 16, color: scheme.onSurfaceVariant),
              const Gap(8),
              Expanded(
                child: Text(
                  'Sort by',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              PopupMenuButton<ResourceSortMode>(
                key: ValueKey('resource_sort_$listId'),
                initialValue: effectiveSort,
                onSelected: (mode) =>
                    ref
                            .read(
                              resourceSortModeStateProvider(listId).notifier,
                            )
                            .mode =
                        mode,
                itemBuilder: (context) => [
                  for (final mode in modes)
                    PopupMenuItem(value: mode, child: Text(mode.label)),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        effectiveSort.label,
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Icon(Icons.expand_more, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Gap(8),
        ],
        FilterChip(
          key: ValueKey('resource_problems_only_$listId'),
          avatar: const Icon(Icons.warning_amber_rounded, size: 16),
          label: const Text('Problems only'),
          selected: problemsOnly,
          visualDensity: VisualDensity.compact,
          onSelected: (value) =>
              ref.read(resourceProblemsOnlyProvider(listId).notifier).enabled =
                  value,
        ),
        if (stateOptions.isNotEmpty || states.isNotEmpty) ...[
          const Gap(12),
          label('State'),
          chips(
            stateOptions,
            states,
            ref.read(resourceStateFilterProvider(listId).notifier).toggle,
          ),
        ],
        if (serverOptions.isNotEmpty || servers.isNotEmpty) ...[
          const Gap(12),
          label('Server'),
          chips(
            serverOptions,
            servers,
            ref.read(resourceServerFilterProvider(listId).notifier).toggle,
          ),
        ],
        if (showSort) ...[
          const Gap(12),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: .35),
          ),
          const Gap(12),
        ],
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
