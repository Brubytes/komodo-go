import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/empty_error_state.dart';
import 'package:komodo_go/core/widgets/filters/tag_filter_sheet.dart';
import 'package:komodo_go/core/widgets/filters/template_filter.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_batch_sheet.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card_support.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_filter_disclosure.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_view_controls.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/shared/resources/models/resource_list_config.dart';
import 'package:komodo_go/shared/resources/providers/resource_filters_provider.dart';
import 'package:komodo_go/shared/resources/resource_list_filtering.dart';
import 'package:komodo_go/shared/resources/resource_sorting.dart';

/// Generic list screen for Komodo resources.
class ResourceListView<T> extends ConsumerStatefulWidget {
  const ResourceListView({required this.config, super.key});

  final ResourceListConfig<T> config;

  @override
  ConsumerState<ResourceListView<T>> createState() =>
      _ResourceListViewState<T>();
}

class _ResourceListViewState<T> extends ConsumerState<ResourceListView<T>> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  ProviderSubscription<String>? _searchQuerySubscription;
  bool _isSearchVisible = false;
  bool _areFiltersExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(resourceSearchQueryProvider(widget.config.kind)),
    );
    _searchFocusNode = FocusNode();
    _searchQuerySubscription = ref.listenManual<String>(
      resourceSearchQueryProvider(widget.config.kind),
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
    _searchQuerySubscription?.close();
    _searchQuerySubscription = null;
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final itemsAsync = config.watchList(ref);
    final actionsState = config.watchActionsState(ref);
    final tagsAsync = config.watchTagOptions(ref);
    final searchQuery = ref.watch(resourceSearchQueryProvider(config.kind));
    final selectedTags = ref.watch(resourceTagFilterProvider(config.kind));
    final templateFilter = ref.watch(
      resourceTemplateFilterStateProvider(config.kind),
    );

    final listId = config.kind.name;
    final prefs = watchResourceViewPrefs(ref, listId);
    final activeFilterCount = countActiveResourceFilters(
      query: searchQuery,
      selectedTags: selectedTags,
      templateFilter: templateFilter,
      problemsOnly: prefs.problemsOnly,
      selectedStates: prefs.states,
      selectedServers: prefs.servers,
    );
    final loadedItems = itemsAsync.maybeWhen(
      data: (items) => items,
      orElse: () => <T>[],
    );
    final stateOf = config.stateLabelOf;
    final serverOf = config.serverNameOf;
    final stateOptions = stateOf == null
        ? <String>[]
        : collectDistinct(loadedItems, stateOf);
    final serverOptions = serverOf == null
        ? <String>[]
        : collectDistinct(loadedItems, serverOf);

    void clearAllFilters() {
      _searchController.clear();
      ref.read(resourceSearchQueryProvider(config.kind).notifier).query = '';
      ref.read(resourceTagFilterProvider(config.kind).notifier).clear();
      ref
              .read(resourceTemplateFilterStateProvider(config.kind).notifier)
              .value =
          TemplateFilter.exclude;
      clearResourceViewFilters(ref, listId);
    }

    final panelCollapsed = !_isSearchVisible || !_areFiltersExpanded;

    final tagOptions = tagsAsync.maybeWhen(
      data: (tags) => tags,
      orElse: () => <TagOption>[],
    );
    final fallbackTags = itemsAsync.maybeWhen(
      data: (items) => collectResourceTags(
        items,
        config.tagsOf,
      ).map((name) => TagOption(id: name, name: name)).toList(),
      orElse: () => <TagOption>[],
    );
    final availableTags = tagOptions.isNotEmpty ? tagOptions : fallbackTags;
    final tagNameById = {
      for (final tag in availableTags) tag.id: tag.name,
    };

    return Scaffold(
      appBar: MainAppBar(
        title: config.title,
        icon: config.icon,
        markColor: config.markColor,
        markUseGradient: true,
        centerTitle: true,
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
          ResourceListActionsMenu(
            kind: config.kind,
            items: config.batchItemOf == null
                ? const []
                : itemsAsync.maybeWhen(
                    data: (items) => items.map(config.batchItemOf!).toList(),
                    orElse: () => const [],
                  ),
            onCreate: config.onCreate == null
                ? null
                : () => config.onCreate!(context),
            onRefresh: () => config.refreshList(ref),
            onBatchCompleted: config.batchItemOf == null
                ? null
                : () => config.invalidateList(ref),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => config.refreshList(ref),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AnimatedSwitcher(
                  duration: AppMotion.base,
                  switchInCurve: AppMotion.enterCurve,
                  switchOutCurve: AppMotion.exitCurve,
                  child: _isSearchVisible
                      ? Column(
                          key: const ValueKey('resource_search_and_filters'),
                          children: [
                            _SearchField(
                              fieldKey: config.searchFieldKey,
                              focusNode: _searchFocusNode,
                              controller: _searchController,
                              onChanged: (value) =>
                                  ref
                                          .read(
                                            resourceSearchQueryProvider(
                                              config.kind,
                                            ).notifier,
                                          )
                                          .query =
                                      value,
                              onClear: () {
                                _searchController.clear();
                                ref
                                        .read(
                                          resourceSearchQueryProvider(
                                            config.kind,
                                          ).notifier,
                                        )
                                        .query =
                                    '';
                              },
                            ),
                            const Gap(10),
                            ResourceFilterDisclosure(
                              expanded: _areFiltersExpanded,
                              activeFilterCount: activeFilterCount,
                              onExpansionChanged: (value) => setState(
                                () => _areFiltersExpanded = value,
                              ),
                              child: _FiltersPanel(
                                listId: listId,
                                stateOptions: stateOptions,
                                serverOptions: serverOptions,
                                supportsRecentlyUpdated:
                                    config.updatedAtOf != null,
                                resourceName: config.resourceName,
                                templateFilter: templateFilter,
                                selectedTags: selectedTags,
                                availableTags: availableTags,
                                onTemplateFilterChanged: (value) =>
                                    ref
                                            .read(
                                              resourceTemplateFilterStateProvider(
                                                config.kind,
                                              ).notifier,
                                            )
                                            .value =
                                        value,
                                onSelectTags: (value) =>
                                    ref
                                            .read(
                                              resourceTagFilterProvider(
                                                config.kind,
                                              ).notifier,
                                            )
                                            .selected =
                                        value,
                                onClearTags: () => ref
                                    .read(
                                      resourceTagFilterProvider(
                                        config.kind,
                                      ).notifier,
                                    )
                                    .clear(),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                if (activeFilterCount > 0 && panelCollapsed) ...[
                  const Gap(8),
                  ResourceActiveFilterChips(
                    listId: listId,
                    onClearAll: clearAllFilters,
                    extraChips: [
                      if (searchQuery.trim().isNotEmpty)
                        ActiveFilterChip(
                          label: 'Search: ${searchQuery.trim()}',
                          onRemove: () {
                            _searchController.clear();
                            ref
                                    .read(
                                      resourceSearchQueryProvider(
                                        config.kind,
                                      ).notifier,
                                    )
                                    .query =
                                '';
                          },
                        ),
                      for (final tag in selectedTags)
                        ActiveFilterChip(
                          label: 'Tag: ${tagNameById[tag] ?? tag}',
                          onRemove: () => ref
                              .read(
                                resourceTagFilterProvider(config.kind).notifier,
                              )
                              .toggle(tag),
                        ),
                      if (templateFilter != TemplateFilter.exclude)
                        ActiveFilterChip(
                          label: templateFilter == TemplateFilter.only
                              ? 'Only templates'
                              : 'With templates',
                          onRemove: () =>
                              ref
                                      .read(
                                        resourceTemplateFilterStateProvider(
                                          config.kind,
                                        ).notifier,
                                      )
                                      .value =
                                  TemplateFilter.exclude,
                        ),
                    ],
                  ),
                ],
                const Gap(12),
                itemsAsync.when(
                  skipLoadingOnRefresh: true,
                  skipLoadingOnReload: true,
                  data: (items) {
                    final searched = applyResourceFilters(
                      items,
                      query: searchQuery,
                      selectedTags: selectedTags,
                      templateFilter: templateFilter,
                      tagNameById: tagNameById,
                      isTemplate: config.isTemplate,
                      tagsOf: config.tagsOf,
                      searchFieldsOf: config.searchFieldsOf,
                    );
                    final filtered = prefs.process<T>(
                      searched,
                      severityOf: config.severityOf,
                      nameOf: config.nameOf,
                      updatedAtOf: config.updatedAtOf,
                      stateLabelOf: config.stateLabelOf,
                      serverNameOf: config.serverNameOf,
                    );
                    if (filtered.isEmpty) {
                      return _EmptyState(
                        icon: config.icon,
                        resourceName: config.resourceName,
                        hasFilters:
                            hasActiveResourceFilters(
                              query: searchQuery,
                              selectedTags: selectedTags,
                              templateFilter: templateFilter,
                            ) ||
                            prefs.activeCount > 0,
                        onClearFilters: clearAllFilters,
                        tagOptions: availableTags,
                        onSelectTags: (value) =>
                            ref
                                    .read(
                                      resourceTagFilterProvider(
                                        config.kind,
                                      ).notifier,
                                    )
                                    .selected =
                                value,
                      );
                    }

                    return Column(
                      children: [
                        for (var i = 0; i < filtered.length; i++) ...[
                          AppFadeSlide(
                            delay: AppMotion.stagger(i),
                            play: i < 10,
                            child: config.cardBuilder(
                              context,
                              ref,
                              filtered[i],
                              resourceDisplayTags(
                                config.tagsOf(filtered[i]),
                                tagNameById,
                              ),
                            ),
                          ),
                          const Gap(12),
                        ],
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                  loading: () => _ResourceSkeletonList(
                    title: config.skeletonTitle,
                    subtitle: config.skeletonSubtitle,
                    chipLeft: config.skeletonChipLeft,
                    chipRight: config.skeletonChipRight,
                  ),
                  error: (error, stack) => ErrorStateView.fromError(
                    title: 'Failed to load ${config.resourceName}',
                    error: error,
                    onRetry: () => config.invalidateList(ref),
                  ),
                ),
              ],
            ),
          ),
          if (actionsState.isLoading)
            ColoredBox(
              color: Theme.of(context).colorScheme.scrim.withValues(alpha: .25),
              child: const Center(child: AppSkeletonCard()),
            ),
        ],
      ),
    );
  }
}

class _FiltersPanel extends StatelessWidget {
  const _FiltersPanel({
    required this.listId,
    required this.stateOptions,
    required this.serverOptions,
    required this.supportsRecentlyUpdated,
    required this.resourceName,
    required this.templateFilter,
    required this.selectedTags,
    required this.availableTags,
    required this.onTemplateFilterChanged,
    required this.onSelectTags,
    required this.onClearTags,
  });

  final String listId;
  final List<String> stateOptions;
  final List<String> serverOptions;
  final bool supportsRecentlyUpdated;
  final String resourceName;
  final TemplateFilter templateFilter;
  final Set<String> selectedTags;
  final List<TagOption> availableTags;
  final ValueChanged<TemplateFilter> onTemplateFilterChanged;
  final ValueChanged<Set<String>> onSelectTags;
  final VoidCallback onClearTags;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tagLabel = selectedTags.isEmpty
        ? 'Tags'
        : 'Tags (${selectedTags.length})';
    final templateLabel = switch (templateFilter) {
      TemplateFilter.exclude => 'Exclude',
      TemplateFilter.include => 'Include',
      TemplateFilter.only => 'Only',
    };

    return AppCardSurface(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResourceViewFiltersSection(
            listId: listId,
            stateOptions: stateOptions,
            serverOptions: serverOptions,
            supportsRecentlyUpdated: supportsRecentlyUpdated,
          ),
          _FilterRow(
            icon: AppIcons.factory,
            label: 'Templates',
            trailing: PopupMenuButton<TemplateFilter>(
              onSelected: onTemplateFilterChanged,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: TemplateFilter.exclude,
                  child: Text('Exclude templates'),
                ),
                PopupMenuItem(
                  value: TemplateFilter.include,
                  child: Text('Include templates'),
                ),
                PopupMenuItem(
                  value: TemplateFilter.only,
                  child: Text('Only templates'),
                ),
              ],
              child: _FilterValueButton(
                label: templateLabel,
                icon: Icons.expand_more,
              ),
            ),
          ),
          Divider(
            height: 20,
            color: scheme.outlineVariant.withValues(alpha: .35),
          ),
          _FilterRow(
            icon: AppIcons.tag,
            label: tagLabel,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FilterValueButton(
                  label: 'Select',
                  icon: Icons.tune,
                  onPressed: () async {
                    final next = await TagFilterSheet.show(
                      context,
                      availableTags: availableTags,
                      selected: selectedTags,
                      resourceName: resourceName,
                    );
                    if (next != null) {
                      onSelectTags(next);
                    }
                  },
                ),
                if (selectedTags.isNotEmpty) ...[
                  const Gap(6),
                  IconButton(
                    tooltip: 'Clear tags',
                    icon: const Icon(AppIcons.close),
                    onPressed: onClearTags,
                  ),
                ],
              ],
            ),
          ),
          if (selectedTags.isNotEmpty) ...[
            const Gap(8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _buildSelectedTagPills(selectedTags, availableTags),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSelectedTagPills(
    Set<String> tags,
    List<TagOption> availableTags,
  ) {
    final tagNameById = {for (final tag in availableTags) tag.id: tag.name};
    final labels = [
      for (final tag in tags) tagNameById[tag] ?? tag,
    ]..sort();
    final capped = labels.take(6).toList();
    final remaining = labels.length - capped.length;
    return [
      for (final tag in capped) TextPill(label: tag),
      if (remaining > 0) ValuePill(label: 'More', value: '+$remaining'),
    ];
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.icon,
    required this.label,
    required this.trailing,
  });

  final IconData icon;
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const Gap(8),
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        trailing,
      ],
    );
  }
}

class _FilterValueButton extends StatelessWidget {
  const _FilterValueButton({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerHighest;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const Gap(6),
              Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.fieldKey,
    required this.focusNode,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final Key fieldKey;
  final FocusNode focusNode;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
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

class _ResourceSkeletonList extends StatelessWidget {
  const _ResourceSkeletonList({
    required this.title,
    required this.subtitle,
    required this.chipLeft,
    required this.chipRight,
  });

  final String title;
  final String subtitle;
  final String chipLeft;
  final String chipRight;

  @override
  Widget build(BuildContext context) {
    return ResourceCardSkeletonList(
      title: title,
      subtitle: subtitle,
      metaLeft: chipLeft,
      metaRight: chipRight,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.resourceName,
    required this.hasFilters,
    required this.onClearFilters,
    required this.tagOptions,
    required this.onSelectTags,
  });

  final IconData icon;
  final String resourceName;
  final bool hasFilters;
  final VoidCallback onClearFilters;
  final List<TagOption> tagOptions;
  final ValueChanged<Set<String>> onSelectTags;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final message = hasFilters
        ? 'No $resourceName match your filters.'
        : 'Create $resourceName in the Komodo web interface.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: scheme.primary.withValues(alpha: 0.5),
            ),
            const Gap(16),
            Text('No $resourceName found', style: textTheme.titleMedium),
            const Gap(8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (hasFilters) ...[
              const Gap(16),
              FilledButton(
                onPressed: onClearFilters,
                child: const Text('Clear filters'),
              ),
            ],
            if (!hasFilters && tagOptions.isNotEmpty) ...[
              const Gap(16),
              OutlinedButton.icon(
                icon: const Icon(AppIcons.tag),
                label: const Text('Filter by tag'),
                onPressed: () async {
                  final next = await TagFilterSheet.show(
                    context,
                    availableTags: tagOptions,
                    selected: const <String>{},
                    resourceName: resourceName,
                  );
                  if (next != null) {
                    onSelectTags(next);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
