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
import 'package:komodo_go/core/widgets/filters/tag_filter_sheet.dart';
import 'package:komodo_go/core/widgets/filters/template_filter.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_filters_provider.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/repos/presentation/widgets/repo_card.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// View displaying the list of all repos.
class ReposListView extends ConsumerStatefulWidget {
  const ReposListView({super.key});

  @override
  ConsumerState<ReposListView> createState() => _ReposListViewState();
}

class _ReposListViewState extends ConsumerState<ReposListView> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  ProviderSubscription<String>? _searchQuerySubscription;
  bool _isSearchVisible = false;
  bool _isFiltersVisible = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(reposSearchQueryProvider),
    );
    _searchFocusNode = FocusNode();
    _searchQuerySubscription = ref.listenManual<String>(
      reposSearchQueryProvider,
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
    final reposAsync = ref.watch(reposProvider);
    final actionsState = ref.watch(repoActionsProvider);
    final tagsAsync = ref.watch(tagsProvider);
    final searchQuery = ref.watch(reposSearchQueryProvider);
    final selectedTags = ref.watch(reposTagFilterProvider);
    final templateFilter = ref.watch(reposTemplateFilterStateProvider);

    final tagOptions = tagsAsync.maybeWhen(
      data: (tags) => [
        for (final tag in tags)
          if (tag.name.trim().isNotEmpty)
            TagOption(id: tag.id, name: tag.name.trim()),
      ],
      orElse: () => <TagOption>[],
    );
    final fallbackTags = reposAsync.maybeWhen(
      data: (repos) => _collectTags(repos)
          .map((name) => TagOption(id: name, name: name))
          .toList(),
      orElse: () => <TagOption>[],
    );
    final availableTags = tagOptions.isNotEmpty ? tagOptions : fallbackTags;
    final tagNameById = {
      for (final tag in availableTags) tag.id: tag.name,
    };

    return Scaffold(
      appBar: MainAppBar(
        title: 'Repos',
        icon: AppIcons.repos,
        markColor: AppTokens.resourceRepos,
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
            onRefresh: () => ref.read(reposProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AnimatedSwitcher(
                  duration: AppMotion.base,
                  switchInCurve: AppMotion.enterCurve,
                  switchOutCurve: AppMotion.exitCurve,
                  child: _isFiltersVisible
                      ? _FiltersPanel(
                          templateFilter: templateFilter,
                          selectedTags: selectedTags,
                          availableTags: availableTags,
                          tagNameById: tagNameById,
                          onTemplateFilterChanged: (value) => ref
                              .read(reposTemplateFilterStateProvider.notifier)
                              .value = value,
                          onSelectTags: (value) => ref
                              .read(reposTagFilterProvider.notifier)
                              .selected = value,
                          onClearTags: () =>
                              ref.read(reposTagFilterProvider.notifier).clear(),
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
                            onChanged: (value) => ref
                                .read(reposSearchQueryProvider.notifier)
                                .query = value,
                            onClear: () {
                              _searchController.clear();
                              ref.read(reposSearchQueryProvider.notifier).query =
                                  '';
                            },
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const Gap(12),
                reposAsync.when(
                  skipLoadingOnRefresh: true,
                  skipLoadingOnReload: true,
                  data: (repos) {
                    final filtered = _applyFilters(
                      repos,
                      query: searchQuery,
                      selectedTags: selectedTags,
                      templateFilter: templateFilter,
                      tagNameById: tagNameById,
                    );
                    if (filtered.isEmpty) {
                      return _EmptyState(
                        hasFilters: _hasActiveFilters(
                          query: searchQuery,
                          selectedTags: selectedTags,
                          templateFilter: templateFilter,
                        ),
                        onClearFilters: () {
                          _searchController.clear();
                          ref.read(reposSearchQueryProvider.notifier).query = '';
                          ref.read(reposTagFilterProvider.notifier).clear();
                          ref
                              .read(reposTemplateFilterStateProvider.notifier)
                              .value = TemplateFilter.exclude;
                        },
                        tagOptions: availableTags,
                        onSelectTags: (value) => ref
                            .read(reposTagFilterProvider.notifier)
                            .selected = value,
                      );
                    }

                    return Column(
                      children: [
                        for (var i = 0; i < filtered.length; i++) ...[
                          AppFadeSlide(
                            delay: AppMotion.stagger(i),
                            play: i < 10,
                            child: RepoCard(
                              repo: filtered[i],
                              onTap: () => context.push(
                                '${AppRoutes.repos}/${filtered[i].id}?name=${Uri.encodeComponent(filtered[i].name)}',
                              ),
                              onAction: (action) => _handleAction(
                                context,
                                ref,
                                filtered[i].id,
                                action,
                              ),
                            ),
                          ),
                          const Gap(12),
                        ],
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                  loading: () => const _ReposSkeletonList(),
                  error: (error, stack) => ErrorStateView(
                    title: 'Failed to load repos',
                    message: error.toString(),
                    onRetry: () => ref.invalidate(reposProvider),
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

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String repoId,
    RepoAction action,
  ) async {
    final actions = ref.read(repoActionsProvider.notifier);
    final success = await switch (action) {
      RepoAction.clone => actions.clone(repoId),
      RepoAction.pull => actions.pull(repoId),
      RepoAction.build => actions.buildRepo(repoId),
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
    required this.templateFilter,
    required this.selectedTags,
    required this.availableTags,
    required this.tagNameById,
    required this.onTemplateFilterChanged,
    required this.onSelectTags,
    required this.onClearTags,
  });

  final TemplateFilter templateFilter;
  final Set<String> selectedTags;
  final List<TagOption> availableTags;
  final Map<String, String> tagNameById;
  final ValueChanged<TemplateFilter> onTemplateFilterChanged;
  final ValueChanged<Set<String>> onSelectTags;
  final VoidCallback onClearTags;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tagLabel =
        selectedTags.isEmpty ? 'Tags' : 'Tags (${selectedTags.length})';
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
                      resourceName: 'repos',
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
    final bg =
        isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerHighest;

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
      key: const ValueKey('repos_search'),
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

class _ReposSkeletonList extends StatelessWidget {
  const _ReposSkeletonList();

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
                      child: Text('Repo name', style: textTheme.titleSmall),
                    ),
                    const Gap(8),
                    const CircleAvatar(radius: 6),
                  ],
                ),
                const Gap(10),
                Text('Provider - Branch - Server',
                    style: textTheme.bodySmall),
                const Gap(10),
                Row(
                  children: const [
                    Chip(label: Text('Synced')),
                    Gap(8),
                    Chip(label: Text('Builds 12')),
                  ],
                ),
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
  final List<TagOption> tagOptions;
  final ValueChanged<Set<String>> onSelectTags;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final message = hasFilters
        ? 'No repos match your filters.'
        : 'Create repos in the Komodo web interface.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.repos,
              size: 64,
              color: scheme.primary.withValues(alpha: 0.5),
            ),
            const Gap(16),
            Text('No repos found', style: textTheme.titleMedium),
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
                    resourceName: 'repos',
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

List<RepoListItem> _applyFilters(
  List<RepoListItem> repos, {
  required String query,
  required Set<String> selectedTags,
  required TemplateFilter templateFilter,
  required Map<String, String> tagNameById,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final normalizedTags = selectedTags
      .map((tag) => tag.trim().toLowerCase())
      .where((tag) => tag.isNotEmpty)
      .toSet();

  return repos.where((repo) {
    switch (templateFilter) {
      case TemplateFilter.exclude:
        if (repo.template) return false;
      case TemplateFilter.only:
        if (!repo.template) return false;
      case TemplateFilter.include:
        break;
    }

    if (normalizedTags.isNotEmpty) {
      final tagMatches = repo.tags.any(
        (tag) => normalizedTags.contains(tag.trim().toLowerCase()),
      );
      if (!tagMatches) return false;
    }

    if (normalizedQuery.isEmpty) return true;

    final name = repo.name.toLowerCase();
    final repoPath = repo.info.repo.toLowerCase();
    final branch = repo.info.branch.toLowerCase();
    final provider = repo.info.gitProvider.toLowerCase();
    final link = repo.info.repoLink.toLowerCase();
    final state = repo.info.state.displayName.toLowerCase();
    final displayTags = _displayTags(repo.tags, tagNameById);
    final tagMatch = displayTags.any(
      (tag) => tag.trim().toLowerCase().contains(normalizedQuery),
    );

    return name.contains(normalizedQuery) ||
        repoPath.contains(normalizedQuery) ||
        branch.contains(normalizedQuery) ||
        provider.contains(normalizedQuery) ||
        link.contains(normalizedQuery) ||
        state.contains(normalizedQuery) ||
        tagMatch;
  }).toList();
}

bool _hasActiveFilters({
  required String query,
  required Set<String> selectedTags,
  required TemplateFilter templateFilter,
}) {
  return query.trim().isNotEmpty ||
      selectedTags.isNotEmpty ||
      templateFilter != TemplateFilter.exclude;
}

List<String> _collectTags(List<RepoListItem> repos) {
  final tags = <String>{};
  for (final repo in repos) {
    for (final tag in repo.tags) {
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
