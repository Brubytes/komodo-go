import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/empty_error_state.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/menus/komodo_select_menu_field.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_filters_provider.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_provider.dart';
import 'package:komodo_go/features/stacks/presentation/widgets/stack_card.dart';
import 'package:komodo_go/features/stacks/presentation/widgets/stack_tag_filter_sheet.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// View displaying the list of all stacks.
class StacksListView extends ConsumerStatefulWidget {
  const StacksListView({super.key});

  @override
  ConsumerState<StacksListView> createState() => _StacksListViewState();
}

class _StacksListViewState extends ConsumerState<StacksListView> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  ProviderSubscription<String>? _searchQuerySubscription;
  bool _isSearchVisible = false;
  bool _isFiltersVisible = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(stacksSearchQueryProvider),
    );
    _searchFocusNode = FocusNode();
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
      data: (stacks) => _collectTags(stacks)
          .map((name) => StackTagOption(id: name, name: name))
          .toList(),
      orElse: () => <StackTagOption>[],
    );
    final availableTags =
        tagOptions.isNotEmpty ? tagOptions : fallbackTags;
    final tagNameById = {
      for (final tag in availableTags) tag.id: tag.name,
    };

    return Scaffold(
      appBar: MainAppBar(
        title: 'Stacks',
        icon: AppIcons.stacks,
        markColor: AppTokens.resourceStacks,
        markUseGradient: true,
        centerTitle: true,
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
          IconButton(
            tooltip: _isFiltersVisible ? 'Hide filters' : 'Filters',
            icon: Icon(
              _isFiltersVisible ? Icons.tune : Icons.tune_outlined,
            ),
            onPressed: () => setState(() {
              _isFiltersVisible = !_isFiltersVisible;
            }),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => ref.read(stacksProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AnimatedSwitcher(
                  duration: AppMotion.base,
                  switchInCurve: AppMotion.enterCurve,
                  switchOutCurve: AppMotion.exitCurve,
                  child: _isFiltersVisible
                      ? _FiltersPanel(
                          pendingUpdate: pendingUpdate,
                          templateFilter: templateFilter,
                          selectedTags: selectedTags,
                          availableTags: availableTags,
                          tagNameById: tagNameById,
                          onPendingUpdateChanged: (value) => ref
                              .read(
                                stacksPendingUpdateFilterProvider.notifier,
                              )
                              .enabled = value,
                          onTemplateFilterChanged: (value) => ref
                              .read(
                                stacksTemplateFilterStateProvider.notifier,
                              )
                              .value = value,
                          onSelectTags: (value) => ref
                              .read(stacksTagFilterProvider.notifier)
                              .selected = value,
                          onClearTags: () =>
                              ref.read(stacksTagFilterProvider.notifier).clear(),
                        )
                      : const SizedBox.shrink(),
                ),
                if (_isFiltersVisible) const Gap(12),
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
                        )
                      : const SizedBox.shrink(),
                ),
                const Gap(12),
                stacksAsync.when(
                  skipLoadingOnRefresh: true,
                  skipLoadingOnReload: true,
                  data: (stacks) {
                    final filtered = _applyFilters(
                      stacks,
                      query: searchQuery,
                      selectedTags: selectedTags,
                      pendingUpdate: pendingUpdate,
                      templateFilter: templateFilter,
                      serverNames: serverNames,
                      tagNameById: tagNameById,
                    );
                    if (filtered.isEmpty) {
                      return _EmptyState(
                        hasFilters: _hasActiveFilters(
                          query: searchQuery,
                          selectedTags: selectedTags,
                          pendingUpdate: pendingUpdate,
                          templateFilter: templateFilter,
                        ),
                        onClearFilters: () {
                          _searchController.clear();
                          ref
                                  .read(stacksSearchQueryProvider.notifier)
                                  .query =
                              '';
                          ref
                              .read(stacksTagFilterProvider.notifier)
                              .clear();
                          ref
                              .read(
                                stacksPendingUpdateFilterProvider.notifier,
                              )
                              .enabled = false;
                          ref
                              .read(
                                stacksTemplateFilterStateProvider.notifier,
                              )
                              .value = StacksTemplateFilter.exclude;
                        },
                        tagOptions: availableTags,
                        onSelectTags: (value) => ref
                            .read(stacksTagFilterProvider.notifier)
                            .selected = value,
                      );
                    }

                    return Column(
                      children: [
                        for (var i = 0; i < filtered.length; i++) ...[
                          AppFadeSlide(
                            delay: AppMotion.stagger(i),
                            play: i < 10,
                            child: StackCard(
                              stack: filtered[i],
                              serverName:
                                  serverNames[filtered[i].info.serverId],
                              displayTags: _displayTags(
                                filtered[i].tags,
                                tagNameById,
                              ),
                              onTap: () => context.push(
                                '${AppRoutes.stacks}/${filtered[i].id}?name=${Uri.encodeComponent(filtered[i].name)}',
                              ),
                              onAction: (action) =>
                                  _handleAction(context, ref, filtered[i].id,
                                      action),
                            ),
                          ),
                          const Gap(12),
                        ],
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                  loading: () => const _StacksSkeletonList(),
                  error: (error, stack) => ErrorStateView(
                    title: 'Failed to load stacks',
                    message: error.toString(),
                    onRetry: () => ref.invalidate(stacksProvider),
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
    StackAction action,
  ) async {
    final actions = ref.read(stackActionsProvider.notifier);
    if (action == StackAction.destroy) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Destroy stack?'),
          content: const Text(
            'This will run docker compose down and remove the stack containers. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Destroy'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final success = await switch (action) {
      StackAction.redeploy => actions.deploy(stackId),
      StackAction.pullImages => actions.pullImages(stackId),
      StackAction.restart => actions.restart(stackId),
      StackAction.pause => actions.pause(stackId),
      StackAction.start => actions.start(stackId),
      StackAction.stop => actions.stop(stackId),
      StackAction.destroy => actions.destroy(stackId),
    };

    if (context.mounted) {
      AppSnackBar.show(
        context,
        success
            ? 'Action completed successfully'
            : 'Action failed. Please try again.',
        tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
      );
    }
  }
}

class _FiltersPanel extends StatelessWidget {
  const _FiltersPanel({
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
          _FilterRow(
            icon: AppIcons.updateAvailable,
            label: 'Pending updates',
            trailing: Switch(
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
  const _StacksSkeletonList();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Skeletonizer(
      enabled: true,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, __) => const Gap(12),
        itemBuilder: (_, __) => AppCardSurface(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(radius: 16),
                    const Gap(10),
                    Expanded(
                      child: Text('Stack name', style: textTheme.titleSmall),
                    ),
                    const Gap(8),
                    const CircleAvatar(radius: 6),
                  ],
                ),
                const Gap(10),
                Text('Source • Server', style: textTheme.bodySmall),
                const Gap(10),
                Row(
                  children: const [
                    Chip(label: Text('Update available')),
                    Gap(8),
                    Chip(label: Text('Tag')),
                  ],
                ),
                const Gap(8),
                Text('Status message', style: textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasFilters,
    required this.onClearFilters,
    required this.tagOptions,
    required this.onSelectTags,
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
        break;
      case StacksTemplateFilter.only:
        if (!stack.template) return false;
        break;
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
    final serverName =
        (serverNames[stack.info.serverId] ?? '').toLowerCase();
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
    for (final tag in tags)
      tagNameById[tag] ?? tag,
  ];
}
