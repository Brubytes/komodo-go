import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/dialogs/confirm_destructive_dialog.dart';
import 'package:komodo_go/core/widgets/empty_error_state.dart';
import 'package:komodo_go/core/widgets/layout/list_detail_layout.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_batch_sheet.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card_support.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_filter_disclosure.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_view_controls.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_filters_provider.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_provider.dart';
import 'package:komodo_go/features/stacks/presentation/widgets/stack_card.dart';
import 'package:komodo_go/features/stacks/presentation/widgets/stack_tag_filter_sheet.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';
import 'package:komodo_go/shared/resources/models/resource_batch.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/resource_sorting.dart';

/// View displaying the list of all stacks.
class StacksListView extends ConsumerStatefulWidget {
  const StacksListView({this.selectedId, super.key});

  /// Id of the item open in the detail pane, highlighted in the list.
  final String? selectedId;

  @override
  ConsumerState<StacksListView> createState() => _StacksListViewState();
}

class _StacksListViewState extends ConsumerState<StacksListView> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final ScrollController _scrollController;
  ProviderSubscription<String>? _searchQuerySubscription;
  bool _isSearchVisible = false;
  bool _areFiltersExpanded = false;
  late final _intro = AppListIntro();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(stacksSearchQueryProvider),
    );
    _searchFocusNode = FocusNode();
    _scrollController = ListScrollMemory.controllerFor('resources_stacks');
    _searchQuerySubscription = ref.listenManual<String>(
      stacksSearchQueryProvider,
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
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stacksAsync = ref.watch(stacksProvider);
    final actionsState = ref.watch(stackActionsProvider);
    final tagsAsync = ref.watch(tagsProvider);
    final serversAsync = ref.watch(serversProvider);
    final searchQuery = ref.watch(stacksSearchQueryProvider);
    final selectedTags = ref.watch(stacksTagFilterProvider);
    final pendingUpdate = ref.watch(stacksPendingUpdateFilterProvider);
    final templateFilter = ref.watch(stacksTemplateFilterStateProvider);

    final serverNames = serversAsync.maybeWhen(
      data: (servers) => {
        for (final server in servers) server.id: server.name,
      },
      orElse: () => <String, String>{},
    );

    final tagOptions = tagsAsync.maybeWhen(
      data: (tags) => [
        for (final tag in tags)
          if (tag.name.trim().isNotEmpty)
            StackTagOption(id: tag.id, name: tag.name.trim()),
      ],
      orElse: () => <StackTagOption>[],
    );
    final fallbackTags = stacksAsync.maybeWhen(
      data: (stacks) => _collectTags(
        stacks,
      ).map((name) => StackTagOption(id: name, name: name)).toList(),
      orElse: () => <StackTagOption>[],
    );
    final availableTags = tagOptions.isNotEmpty ? tagOptions : fallbackTags;
    final tagNameById = {
      for (final tag in availableTags) tag.id: tag.name,
    };

    const listId = 'stacks';
    final prefs = watchResourceViewPrefs(ref, listId);
    final activeFilterCount = countActiveResourceFilters(
      query: searchQuery,
      selectedTags: selectedTags,
      problemsOnly: prefs.problemsOnly,
      selectedStates: prefs.states,
      selectedServers: prefs.servers,
      extra:
          (pendingUpdate ? 1 : 0) +
          (templateFilter == StacksTemplateFilter.exclude ? 0 : 1),
    );
    final loadedItems = stacksAsync.maybeWhen(
      data: (items) => items,
      orElse: () => <StackListItem>[],
    );
    final stateOptions = collectDistinct<StackListItem>(
      loadedItems,
      _stateLabel,
    );
    final serverOptions = collectDistinct<StackListItem>(
      loadedItems,
      (i) => _serverNameOf(i, serverNames),
    );
    void clearAllFilters() {
      _searchController.clear();
      ref.read(stacksSearchQueryProvider.notifier).query = '';
      ref.read(stacksTagFilterProvider.notifier).clear();
      ref.read(stacksTemplateFilterStateProvider.notifier).value =
          StacksTemplateFilter.exclude;
      ref.read(stacksPendingUpdateFilterProvider.notifier).enabled = false;
      clearResourceViewFilters(ref, listId);
    }

    final panelCollapsed = !_isSearchVisible || !_areFiltersExpanded;

    return Scaffold(
      appBar: MainAppBar(
        title: 'Stacks',
        icon: AppIcons.stacks,
        markColor: AppTokens.resourceStacks,
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
            kind: ResourceKind.stacks,
            items: stacksAsync.maybeWhen(
              data: (items) => [
                for (final item in items)
                  ResourceBatchItem(id: item.id, name: item.name),
              ],
              orElse: () => const [],
            ),
            onCreate: () => context.openDetail('${AppRoutes.stacks}/new'),
            onRefresh: () => ref.read(stacksProvider.notifier).refresh(),
            onBatchCompleted: () => ref.invalidate(stacksProvider),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => ref.read(stacksProvider.notifier).refresh(),
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                AppSwitcher(
                  child: _isSearchVisible
                      ? Column(
                          key: const ValueKey('resource_search_and_filters'),
                          children: [
                            _SearchField(
                              focusNode: _searchFocusNode,
                              controller: _searchController,
                              onChanged: (value) =>
                                  ref
                                          .read(
                                            stacksSearchQueryProvider.notifier,
                                          )
                                          .query =
                                      value,
                              onClear: () {
                                _searchController.clear();
                                ref
                                        .read(
                                          stacksSearchQueryProvider.notifier,
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
                                viewSection: ResourceViewFiltersSection(
                                  listId: listId,
                                  stateOptions: stateOptions,
                                  serverOptions: serverOptions,
                                ),

                                pendingUpdate: pendingUpdate,
                                templateFilter: templateFilter,
                                selectedTags: selectedTags,
                                availableTags: availableTags,
                                tagNameById: tagNameById,
                                onPendingUpdateChanged: (value) =>
                                    ref
                                            .read(
                                              stacksPendingUpdateFilterProvider
                                                  .notifier,
                                            )
                                            .enabled =
                                        value,
                                onTemplateFilterChanged: (value) =>
                                    ref
                                            .read(
                                              stacksTemplateFilterStateProvider
                                                  .notifier,
                                            )
                                            .value =
                                        value,
                                onSelectTags: (value) =>
                                    ref
                                            .read(
                                              stacksTagFilterProvider.notifier,
                                            )
                                            .selected =
                                        value,
                                onClearTags: () => ref
                                    .read(stacksTagFilterProvider.notifier)
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
                            ref.read(stacksSearchQueryProvider.notifier).query =
                                '';
                          },
                        ),
                      for (final tag in selectedTags)
                        ActiveFilterChip(
                          label: 'Tag: ${tagNameById[tag] ?? tag}',
                          onRemove: () => ref
                              .read(stacksTagFilterProvider.notifier)
                              .toggle(tag),
                        ),
                      if (pendingUpdate)
                        ActiveFilterChip(
                          label: 'Pending updates',
                          onRemove: () =>
                              ref
                                      .read(
                                        stacksPendingUpdateFilterProvider
                                            .notifier,
                                      )
                                      .enabled =
                                  false,
                        ),
                      if (templateFilter != StacksTemplateFilter.exclude)
                        ActiveFilterChip(
                          label: templateFilter == StacksTemplateFilter.only
                              ? 'Only templates'
                              : 'With templates',
                          onRemove: () =>
                              ref
                                  .read(
                                    stacksTemplateFilterStateProvider.notifier,
                                  )
                                  .value = StacksTemplateFilter
                                  .exclude,
                        ),
                    ],
                  ),
                ],
                const Gap(12),
                AppSwitcher(
                  animateSize: false,
                  child: stacksAsync.when(
                    skipLoadingOnRefresh: true,
                    skipLoadingOnReload: true,
                    data: (stacks) {
                      final searched = _applyFilters(
                        stacks,
                        query: searchQuery,
                        selectedTags: selectedTags,
                        pendingUpdate: pendingUpdate,
                        templateFilter: templateFilter,
                        serverNames: serverNames,
                        tagNameById: tagNameById,
                      );

                      final filtered = prefs.process<StackListItem>(
                        searched,
                        severityOf: _severityOf,
                        nameOf: (item) => item.name,
                        stateLabelOf: _stateLabel,
                        serverNameOf: (item) =>
                            _serverNameOf(item, serverNames),
                      );
                      if (filtered.isEmpty) {
                        return _EmptyState(
                          key: const ValueKey('stacks_empty'),
                          hasFilters:
                              _hasActiveFilters(
                                query: searchQuery,
                                selectedTags: selectedTags,
                                pendingUpdate: pendingUpdate,
                                templateFilter: templateFilter,
                              ) ||
                              prefs.activeCount > 0,
                          onClearFilters: () {
                            clearResourceViewFilters(ref, listId);
                            _searchController.clear();
                            ref.read(stacksSearchQueryProvider.notifier).query =
                                '';
                            ref.read(stacksTagFilterProvider.notifier).clear();
                            ref
                                    .read(
                                      stacksPendingUpdateFilterProvider
                                          .notifier,
                                    )
                                    .enabled =
                                false;
                            ref
                                .read(
                                  stacksTemplateFilterStateProvider.notifier,
                                )
                                .value = StacksTemplateFilter
                                .exclude;
                          },
                          tagOptions: availableTags,
                          onSelectTags: (value) =>
                              ref
                                      .read(stacksTagFilterProvider.notifier)
                                      .selected =
                                  value,
                        );
                      }

                      return Column(
                        key: const ValueKey('stacks_data'),
                        children: [
                          for (var i = 0; i < filtered.length; i++) ...[
                            _intro.wrap(
                              i,
                              id: filtered[i].id,
                              SelectionHighlight(
                                selected: filtered[i].id == widget.selectedId,
                                child: StackCard(
                                  stack: filtered[i],
                                  serverName:
                                      serverNames[filtered[i].info.serverId],
                                  displayTags: _displayTags(
                                    filtered[i].tags,
                                    tagNameById,
                                  ),
                                  onTap: () => context.openDetail(
                                    '${AppRoutes.stacks}/${filtered[i].id}?name=${Uri.encodeComponent(filtered[i].name)}',
                                  ),
                                  onAction: (action) => _handleAction(
                                    context,
                                    ref,
                                    filtered[i].id,
                                    filtered[i].name,
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
                    loading: () => const _StacksSkeletonList(
                      key: ValueKey('stacks_loading'),
                    ),
                    error: (error, stack) => ErrorStateView(
                      key: const ValueKey('stacks_error'),
                      title: 'Failed to load stacks',
                      message: error.toString(),
                      onRetry: () => ref.invalidate(stacksProvider),
                    ),
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
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String stackId,
    String stackName,
    StackAction action,
  ) async {
    final actions = ref.read(stackActionsProvider.notifier);
    if (action == StackAction.destroy || action == StackAction.stop) {
      final destroy = action == StackAction.destroy;
      final confirmed = await confirmDestructive(
        context,
        title: destroy ? 'Destroy $stackName?' : 'Stop $stackName?',
        message: destroy
            ? 'This will run docker compose down and remove the stack '
                  'containers of "$stackName".'
            : 'This will stop all containers of "$stackName".',
        confirmLabel: destroy ? 'Destroy' : 'Stop',
      );
      if (!confirmed) return;
      if (!context.mounted) return;
    }

    if (action == StackAction.checkUpdates) {
      final services = await actions.checkForUpdates(stackId);
      if (!context.mounted) return;
      ref.invalidate(stacksProvider);
      final count = services
          ?.where((service) => service.updateAvailable)
          .length;
      AppSnackBar.show(
        context,
        count == null
            ? 'Image check failed. Please try again.'
            : count == 0
            ? 'All service images are up to date.'
            : '$count service image${count == 1 ? '' : 's'} can be updated.',
        tone: count == null
            ? AppSnackBarTone.error
            : count == 0
            ? AppSnackBarTone.success
            : AppSnackBarTone.warning,
      );
      return;
    }

    final success = await switch (action) {
      StackAction.checkUpdates => Future<bool>.value(false),
      StackAction.deployIfChanged => actions.deployIfChanged(stackId),
      StackAction.redeploy => actions.deploy(stackId),
      StackAction.pullImages => actions.pullImages(stackId),
      StackAction.restart => actions.restart(stackId),
      StackAction.pause => actions.pause(stackId),
      StackAction.start => actions.start(stackId),
      StackAction.stop => actions.stop(stackId),
      StackAction.destroy => actions.destroy(stackId),
    };
    if (!context.mounted) return;
    final actionError = ref.read(stackActionsProvider).asError?.error;
    final actionErrorMessage = actionError is String
        ? actionError.trim()
        : actionError?.toString().trim();
    final hasActionError =
        actionErrorMessage != null && actionErrorMessage.isNotEmpty;

    if (context.mounted) {
      AppSnackBar.show(
        context,
        success
            ? 'Action submitted. Check updates for the result.'
            : hasActionError
            ? 'Action failed: $actionErrorMessage'
            : 'Action failed. Please try again.',
        tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
      );
    }
  }
}

class _FiltersPanel extends StatelessWidget {
  const _FiltersPanel({
    required this.viewSection,
    required this.pendingUpdate,
    required this.templateFilter,
    required this.selectedTags,
    required this.availableTags,
    required this.tagNameById,
    required this.onPendingUpdateChanged,
    required this.onTemplateFilterChanged,
    required this.onSelectTags,
    required this.onClearTags,
  });

  final Widget viewSection;
  final bool pendingUpdate;
  final StacksTemplateFilter templateFilter;
  final Set<String> selectedTags;
  final List<StackTagOption> availableTags;
  final Map<String, String> tagNameById;
  final ValueChanged<bool> onPendingUpdateChanged;
  final ValueChanged<StacksTemplateFilter> onTemplateFilterChanged;
  final ValueChanged<Set<String>> onSelectTags;
  final VoidCallback onClearTags;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tagLabel = selectedTags.isEmpty
        ? 'Tags'
        : 'Tags (${selectedTags.length})';
    final templateLabel = switch (templateFilter) {
      StacksTemplateFilter.exclude => 'Exclude',
      StacksTemplateFilter.include => 'Include',
      StacksTemplateFilter.only => 'Only',
    };

    return AppCardSurface(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          viewSection,
          _FilterRow(
            icon: AppIcons.updateAvailable,
            label: 'Pending updates',
            trailing: Switch.adaptive(
              value: pendingUpdate,
              onChanged: onPendingUpdateChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          Divider(
            height: 20,
            color: scheme.outlineVariant.withValues(alpha: 0.35),
          ),
          _FilterRow(
            icon: AppIcons.factory,
            label: 'Templates',
            trailing: PopupMenuButton<StacksTemplateFilter>(
              onSelected: onTemplateFilterChanged,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: StacksTemplateFilter.exclude,
                  child: Text('Exclude templates'),
                ),
                PopupMenuItem(
                  value: StacksTemplateFilter.include,
                  child: Text('Include templates'),
                ),
                PopupMenuItem(
                  value: StacksTemplateFilter.only,
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
            color: scheme.outlineVariant.withValues(alpha: 0.35),
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
                    final next = await StackTagFilterSheet.show(
                      context,
                      availableTags: availableTags,
                      selected: selectedTags,
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
              children: _buildSelectedTagPills(selectedTags, tagNameById),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSelectedTagPills(
    Set<String> tags,
    Map<String, String> tagNameById,
  ) {
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
      key: const ValueKey('stacks_search'),
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

class _StacksSkeletonList extends StatelessWidget {
  const _StacksSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return const ResourceCardSkeletonList(
      title: 'Stack name',
      subtitle: 'owner/repository · main',
      metaLeft: 'Server',
      metaRight: '3 services',
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasFilters,
    required this.onClearFilters,
    required this.tagOptions,
    required this.onSelectTags,
    super.key,
  });

  final bool hasFilters;
  final VoidCallback onClearFilters;
  final List<StackTagOption> tagOptions;
  final ValueChanged<Set<String>> onSelectTags;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final message = hasFilters
        ? 'No stacks match your filters.'
        : 'Create stacks in the Komodo web interface.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.stacks,
              size: 64,
              color: scheme.primary.withValues(alpha: 0.5),
            ),
            const Gap(16),
            Text(
              hasFilters ? 'No stacks found' : 'No stacks found',
              style: textTheme.titleMedium,
            ),
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
                  final next = await StackTagFilterSheet.show(
                    context,
                    availableTags: tagOptions,
                    selected: const <String>{},
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

List<StackListItem> _applyFilters(
  List<StackListItem> stacks, {
  required String query,
  required Set<String> selectedTags,
  required bool pendingUpdate,
  required StacksTemplateFilter templateFilter,
  required Map<String, String> serverNames,
  required Map<String, String> tagNameById,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final normalizedTags = selectedTags
      .map((tag) => tag.trim().toLowerCase())
      .where((tag) => tag.isNotEmpty)
      .toSet();

  return stacks.where((stack) {
    if (pendingUpdate && !stack.hasPendingUpdate) return false;
    switch (templateFilter) {
      case StacksTemplateFilter.exclude:
        if (stack.template) return false;
      case StacksTemplateFilter.only:
        if (!stack.template) return false;
      case StacksTemplateFilter.include:
        break;
    }

    if (normalizedTags.isNotEmpty) {
      final tagMatches = stack.tags.any(
        (tag) => normalizedTags.contains(tag.trim().toLowerCase()),
      );
      if (!tagMatches) return false;
    }

    if (normalizedQuery.isEmpty) return true;

    final name = stack.name.toLowerCase();
    final repo = stack.info.repo.toLowerCase();
    final branch = stack.info.branch.toLowerCase();
    final linkedRepo = stack.info.linkedRepo.toLowerCase();
    final serverName = (serverNames[stack.info.serverId] ?? '').toLowerCase();
    final displayTags = _displayTags(stack.tags, tagNameById);
    final tagMatch = displayTags.any(
      (tag) => tag.trim().toLowerCase().contains(normalizedQuery),
    );

    return name.contains(normalizedQuery) ||
        repo.contains(normalizedQuery) ||
        branch.contains(normalizedQuery) ||
        linkedRepo.contains(normalizedQuery) ||
        serverName.contains(normalizedQuery) ||
        tagMatch;
  }).toList();
}

bool _hasActiveFilters({
  required String query,
  required Set<String> selectedTags,
  required bool pendingUpdate,
  required StacksTemplateFilter templateFilter,
}) {
  return query.trim().isNotEmpty ||
      selectedTags.isNotEmpty ||
      pendingUpdate ||
      templateFilter != StacksTemplateFilter.exclude;
}

List<String> _collectTags(List<StackListItem> stacks) {
  final tags = <String>{};
  for (final stack in stacks) {
    for (final tag in stack.tags) {
      if (tag.trim().isNotEmpty) {
        tags.add(tag.trim());
      }
    }
  }
  final sorted = tags.toList()..sort();
  return sorted;
}

List<String> _displayTags(
  List<String> tags,
  Map<String, String> tagNameById,
) {
  if (tags.isEmpty) return const [];
  return [
    for (final tag in tags) tagNameById[tag] ?? tag,
  ];
}

int _severityOf(StackListItem stack) {
  final info = stack.info;
  final base = switch (info.state) {
    StackState.dead || StackState.unhealthy => ResourceSeverity.attention,
    StackState.restarting ||
    StackState.deploying ||
    StackState.removing => ResourceSeverity.warning,
    StackState.running => ResourceSeverity.healthy,
    StackState.paused ||
    StackState.stopped ||
    StackState.created ||
    StackState.down ||
    StackState.unknown => ResourceSeverity.inactive,
  };
  if (base == ResourceSeverity.attention) return base;
  if (info.state == StackState.running &&
      (stack.hasPendingUpdate ||
          info.projectMissing ||
          info.missingFiles.isNotEmpty)) {
    return ResourceSeverity.warning;
  }
  return base;
}

String _stateLabel(StackListItem stack) => resourceStateLabel(stack.info.state);

String? _serverNameOf(StackListItem stack, Map<String, String> serverNames) {
  final name = serverNames[stack.info.serverId] ?? stack.info.serverName;
  return name.trim().isEmpty ? null : name.trim();
}
