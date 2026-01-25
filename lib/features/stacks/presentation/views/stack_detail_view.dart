import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/polling_route_aware_state.dart';
import 'package:komodo_go/core/router/shell_state_provider.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/providers/core_info_provider.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/menus/komodo_popup_menu.dart';
import 'package:komodo_go/features/notifications/presentation/providers/stack_updates_provider.dart';
import 'package:komodo_go/features/notifications/presentation/views/notifications/notifications_sections.dart'
  show
    NotificationsEmptyState,
    NotificationsErrorState,
    PaginationFooter,
    UpdateTile;
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_provider.dart';
import 'package:komodo_go/features/stacks/presentation/views/stack_detail/stack_detail_sections.dart';
import 'package:komodo_go/features/stacks/presentation/widgets/stack_card.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';
import 'package:komodo_go/features/providers/presentation/providers/docker_registry_provider.dart';

/// View displaying detailed stack information.
class StackDetailView extends ConsumerStatefulWidget {
  const StackDetailView({
    required this.stackId,
    required this.stackName,
    super.key,
  });

  final String stackId;
  final String stackName;

  @override
  ConsumerState<StackDetailView> createState() => _StackDetailViewState();
}

class _StackDetailViewState extends PollingRouteAwareState<StackDetailView>
    with
        TickerProviderStateMixin,
        DetailDirtySnackBarMixin<StackDetailView> {
  late TabController _tabController;

  Timer? _logRefreshTimer;
  var _autoRefreshLogs = true;
  final _configEditorKey = GlobalKey<StackConfigEditorContentState>();
  final _infoEditorKey = GlobalKey<StackInfoTabContentState>();

  var _configSaveInFlight = false;
  var _infoSaveInFlight = false;
  var _hasInfoTab = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onInnerTabChanged);
  }

  @override
  void dispose() {
    _logRefreshTimer?.cancel();
    _logRefreshTimer = null;
    _tabController
      ..removeListener(_onInnerTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void onVisibilityChanged() {
    if (!mounted) return;
    _syncLogPolling(isShellTabActive: ref.read(mainShellIndexProvider) == 1);
    super.onVisibilityChanged();
  }

  void _onInnerTabChanged() {
    if (!mounted) return;
    _syncLogPolling(isShellTabActive: ref.read(mainShellIndexProvider) == 1);
  }

  void _startLogPolling() {
    _logRefreshTimer?.cancel();
    _logRefreshTimer = null;
    if (!_autoRefreshLogs) return;

    _logRefreshTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      ref.invalidate(stackLogProvider(widget.stackId));
    });
  }

  void _stopLogPolling() {
    _logRefreshTimer?.cancel();
    _logRefreshTimer = null;
  }

  void _syncLogPolling({required bool isShellTabActive}) {
    final isLogsTabActive = _tabController.index == _logsTabIndex;
    final isActiveTab = isShellTabActive && isLogsTabActive;
    if (shouldPoll(isActiveTab: isActiveTab, enabled: _autoRefreshLogs)) {
      _startLogPolling();
    } else {
      _stopLogPolling();
    }
  }

  int get _logsTabIndex => _hasInfoTab ? 4 : 3;

  bool _shouldShowInfoTab(KomodoStack? stack) {
    if (stack == null) return false;
    if (stack.config.filesOnHost) return true;
    return stack.config.linkedRepo.trim().isNotEmpty ||
        stack.config.repo.trim().isNotEmpty;
  }

  int _mapTabIndex({
    required int oldIndex,
    required bool oldHasInfoTab,
    required bool newHasInfoTab,
  }) {
    if (oldHasInfoTab == newHasInfoTab) return oldIndex;
    if (!oldHasInfoTab && newHasInfoTab) {
      return switch (oldIndex) {
        0 => 0,
        1 => 2,
        2 => 3,
        _ => 4,
      };
    }
    return switch (oldIndex) {
      0 => 0,
      1 => 1,
      2 => 1,
      3 => 2,
      _ => 3,
    };
  }

  void _updateTabController({required bool hasInfoTab}) {
    if (_hasInfoTab == hasInfoTab) return;
    final oldIndex = _tabController.index;
    final oldHasInfoTab = _hasInfoTab;
    final nextLength = hasInfoTab ? 5 : 4;
    final nextIndex = _mapTabIndex(
      oldIndex: oldIndex,
      oldHasInfoTab: oldHasInfoTab,
      newHasInfoTab: hasInfoTab,
    ).clamp(0, nextLength - 1);

    _tabController
      ..removeListener(_onInnerTabChanged)
      ..dispose();
    _hasInfoTab = hasInfoTab;
    _tabController = TabController(length: nextLength, vsync: this)
      ..index = nextIndex
      ..addListener(_onInnerTabChanged);

    if (mounted) {
      setState(() {});
      _syncLogPolling(isShellTabActive: ref.read(mainShellIndexProvider) == 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActiveTab = ref.watch(mainShellIndexProvider) == 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncLogPolling(isShellTabActive: isActiveTab);
    });

    final stackAsync = ref.watch(stackDetailProvider(widget.stackId));
    final coreInfoAsync = ref.watch(coreInfoProvider);
    final servicesAsync = ref.watch(stackServicesProvider(widget.stackId));
    final logAsync = ref.watch(stackLogProvider(widget.stackId));
    final stackUpdatesAsync = ref.watch(stackUpdatesProvider(widget.stackId));
    final stacksListAsync = ref.watch(stacksProvider);
    final serversListAsync = ref.watch(serversProvider);
    final reposListAsync = ref.watch(reposProvider);
    final registryAccountsAsync = ref.watch(dockerRegistryAccountsProvider);
    final tagsAsync = ref.watch(tagsProvider);
    final actionsState = ref.watch(stackActionsProvider);

    final scheme = Theme.of(context).colorScheme;

    StackListItem? listItem;
    final stacks = stacksListAsync.asData?.value;
    if (stacks != null) {
      for (final s in stacks) {
        if (s.id == widget.stackId) {
          listItem = s;
          break;
        }
      }
    }

    final services = servicesAsync.asData?.value;
    final serviceCount = services?.length;
    final updateCount = services?.where((e) => e.updateAvailable).length;

    String? serverNameForId(String serverId) {
      final servers = serversListAsync.asData?.value;
      if (servers == null || serverId.isEmpty) return null;
      for (final s in servers) {
        if (s.id == serverId) return s.name;
      }
      return null;
    }

    final servers = serversListAsync.asData?.value ?? const [];
    final repos = reposListAsync.asData?.value ?? const [];
    final registryAccounts = registryAccountsAsync.asData?.value ?? const [];
    final tagNameById = tagsAsync.maybeWhen(
      data: (tags) => {
        for (final tag in tags)
          if (tag.name.trim().isNotEmpty) tag.id: tag.name.trim(),
      },
      orElse: () => <String, String>{},
    );
    final hasInfoTab = _hasInfoTab;
    final desiredHasInfoTab = _shouldShowInfoTab(stackAsync.asData?.value);
    if (desiredHasInfoTab != _hasInfoTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updateTabController(hasInfoTab: desiredHasInfoTab);
      });
    }

    return Scaffold(
      appBar: MainAppBar(
        title: widget.stackName,
        icon: AppIcons.stacks,
        markColor: AppTokens.resourceStacks,
        markUseGradient: true,
        centerTitle: true,
        actions: [
          PopupMenuButton<StackAction>(
            icon: const Icon(AppIcons.moreVertical),
            onSelected: (action) =>
                _handleAction(context, widget.stackId, action),
            itemBuilder: (context) => [
              komodoPopupMenuItem(
                value: StackAction.redeploy,
                icon: AppIcons.deployments,
                label: 'Redeploy',
                iconColor: scheme.primary,
              ),
              komodoPopupMenuItem(
                value: StackAction.pullImages,
                icon: AppIcons.download,
                label: 'Pull images',
                iconColor: scheme.primary,
              ),
              komodoPopupMenuItem(
                value: StackAction.restart,
                icon: AppIcons.refresh,
                label: 'Restart',
                iconColor: scheme.primary,
              ),
              komodoPopupMenuItem(
                value: StackAction.pause,
                icon: AppIcons.pause,
                label: 'Pause',
                iconColor: scheme.tertiary,
              ),
              komodoPopupMenuDivider(),
              komodoPopupMenuItem(
                value: StackAction.start,
                icon: AppIcons.play,
                label: 'Start',
                iconColor: scheme.secondary,
              ),
              komodoPopupMenuItem(
                value: StackAction.stop,
                icon: AppIcons.stop,
                label: 'Stop',
                iconColor: scheme.tertiary,
              ),
              komodoPopupMenuItem(
                value: StackAction.destroy,
                icon: AppIcons.delete,
                label: 'Destroy',
                destructive: true,
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: stackAsync.when(
                      data: (stack) => stack != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                StackHeroPanel(
                                  stack: stack,
                                  listItem: listItem,
                                  serviceCount: serviceCount,
                                  updateCount: updateCount,
                                  serverName: serverNameForId(
                                    stack.config.serverId,
                                  ),
                                  sourceIcon: _sourceIcon(
                                    stack: stack,
                                    listItem: listItem,
                                    repos: repos,
                                  ),
                                  sourceLabel: _sourceLabel(
                                    stack: stack,
                                    listItem: listItem,
                                    repos: repos,
                                  ),
                                  displayTags: _displayTags(
                                    stack.tags,
                                    tagNameById,
                                  ),
                                ),
                                const Gap(12),
                              ],
                            )
                          : const StackMessageSurface(
                              message: 'Stack not found',
                            ),
                      loading: () => const StackLoadingSurface(),
                      error: (error, _) =>
                          StackMessageSurface(message: 'Error: $error'),
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedTabBarHeaderDelegate(
                    backgroundColor: scheme.surface,
                    tabBar: buildDetailTabBar(
                      context: context,
                      controller: _tabController,
                      tabs: [
                        const Tab(
                          icon: Icon(AppIcons.bolt),
                          text: 'Config',
                        ),
                        if (hasInfoTab)
                          const Tab(
                            icon: Icon(AppIcons.info),
                            text: 'Info',
                          ),
                        const Tab(
                          icon: Icon(AppIcons.toolbox),
                          text: 'Services',
                        ),
                        const Tab(
                          icon: Icon(AppIcons.history),
                          text: 'Updates',
                        ),
                        const Tab(
                          icon: Icon(AppIcons.logs),
                          text: 'Logs',
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _KeepAlive(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(stackDetailProvider(widget.stackId));
                    },
                    child: ListView(
                      key: PageStorageKey('stack_${widget.stackId}_config'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      children: [
                        stackAsync.when(
                          data: (stack) => stack != null
                              ? StackConfigEditorContent(
                                  key: _configEditorKey,
                                  stackIdOrName: widget.stackId,
                                  initialConfig: stack.config,
                                  webhookBaseUrl: coreInfoAsync.maybeWhen(
                                    data: (info) => info.webhookBaseUrl,
                                    orElse: () => '',
                                  ),
                                  servers: servers,
                                  repos: repos,
                                  registryAccounts: registryAccounts,
                                  onDirtyChanged: (dirty) {
                                    syncDirtySnackBar(
                                      dirty: dirty,
                                      onDiscard: () => _discardConfig(stack),
                                      onSave: () => _saveConfig(stack: stack),
                                      saveEnabled: !_configSaveInFlight,
                                    );
                                  },
                                )
                              : const StackMessageSurface(
                                  message: 'Stack not found',
                                ),
                          loading: () => const StackLoadingSurface(),
                          error: (error, _) =>
                              StackMessageSurface(message: 'Error: $error'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (hasInfoTab)
                  _KeepAlive(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(stackDetailProvider(widget.stackId));
                      },
                      child: ListView(
                        key: PageStorageKey('stack_${widget.stackId}_info'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        children: [
                          stackAsync.when(
                            data: (stack) => stack != null
                                ? StackInfoTabContent(
                                    key: _infoEditorKey,
                                    info: stack.info,
                                    onSaveFile:
                                        (
                                          path,
                                          contents, {
                                          bool showSnackBar = true,
                                        }) =>
                                        _saveStackFile(
                                          stackId: stack.id,
                                          filePath: path,
                                          contents: contents,
                                          showSnackBar: showSnackBar,
                                        ),
                                    onDirtyChanged: (dirty) {
                                      syncDirtySnackBar(
                                        dirty: dirty,
                                        onDiscard: _discardInfoChanges,
                                        onSave: _saveInfoChanges,
                                        saveEnabled: !_infoSaveInFlight,
                                      );
                                    },
                                  )
                                : const StackMessageSurface(
                                    message: 'Stack not found',
                                  ),
                            loading: () => const StackLoadingSurface(),
                            error: (error, _) => StackMessageSurface(
                              message: 'Error: $error',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                _KeepAlive(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(stackServicesProvider(widget.stackId));
                    },
                    child: ListView(
                      key: PageStorageKey('stack_${widget.stackId}_services'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      children: [
                        servicesAsync.when(
                          data: (services) => services.isEmpty
                              ? const Text('No services found')
                              : Column(
                                  children: [
                                    for (final service in services) ...[
                                      StackServiceCard(service: service),
                                      const Gap(12),
                                    ],
                                  ],
                                ),
                          loading: () => const StackLoadingSurface(),
                          error: (error, _) => StackMessageSurface(
                            message: 'Services unavailable: $error',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _KeepAlive(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await ref
                          .read(stackUpdatesProvider(widget.stackId).notifier)
                          .refresh();
                    },
                    child: stackUpdatesAsync.when(
                      data: (state) {
                        if (state.items.isEmpty) {
                          return const NotificationsEmptyState(
                            icon: AppIcons.updateAvailable,
                            title: 'No updates',
                            description: 'No recent activity for this stack.',
                          );
                        }

                        return NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification.metrics.pixels >=
                                notification.metrics.maxScrollExtent - 200) {
                              ref
                                  .read(
                                    stackUpdatesProvider(widget.stackId)
                                        .notifier,
                                  )
                                  .fetchNextPage();
                            }
                            return false;
                          },
                          child: ListView.separated(
                            key: PageStorageKey(
                              'stack_${widget.stackId}_updates',
                            ),
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            itemCount:
                                state.items.length +
                                (state.nextPage == null ? 0 : 1),
                            separatorBuilder: (_, __) => const Gap(12),
                            itemBuilder: (context, index) {
                              final isFooter = index >= state.items.length;
                              if (isFooter) {
                                return PaginationFooter(
                                  isLoading: state.isLoadingMore,
                                  onLoadMore: () => ref
                                      .read(
                                        stackUpdatesProvider(widget.stackId)
                                            .notifier,
                                      )
                                      .fetchNextPage(),
                                );
                              }

                              final update = state.items[index];
                              return UpdateTile(update: update);
                            },
                          ),
                        );
                      },
                      loading: () => const AppSkeletonList(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                      ),
                      error: (error, _) => NotificationsErrorState(
                        title: 'Failed to load updates',
                        message: error.toString(),
                        onRetry: () => ref.invalidate(
                          stackUpdatesProvider(widget.stackId),
                        ),
                      ),
                    ),
                  ),
                ),
                _KeepAlive(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(stackLogProvider(widget.stackId));
                    },
                    child: ListView(
                      key: PageStorageKey('stack_${widget.stackId}_logs'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      children: [
                        Text(
                          'Auto refresh logs',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const Gap(4),
                        Text(
                          'When enabled, logs refresh every 2.5 seconds while this tab is visible. Pull down to refresh once.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const Gap(10),
                        Row(
                          children: [
                            Tooltip(
                              message:
                                  'When enabled, logs refresh every 2.5 seconds while this tab is visible.',
                              child: Icon(
                                AppIcons.refresh,
                                size: 16,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const Gap(8),
                            Expanded(
                              child: Text(
                                _autoRefreshLogs ? 'Enabled' : 'Disabled',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                            Switch(
                              value: _autoRefreshLogs,
                              onChanged: (value) {
                                setState(() => _autoRefreshLogs = value);
                                _syncLogPolling(
                                  isShellTabActive:
                                      ref.read(mainShellIndexProvider) == 1,
                                );
                              },
                            ),
                          ],
                        ),
                        const Gap(12),
                        logAsync.when(
                          data: (log) => StackLogContent(log: log),
                          loading: () => const StackLoadingSurface(),
                          error: (error, _) => StackMessageSurface(
                            message: 'Logs unavailable: $error',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (actionsState.isLoading)
            ColoredBox(
              color: scheme.scrim.withValues(alpha: 0.25),
              child: const Center(child: AppSkeletonCard()),
            ),
        ],
      ),
    );
  }

  IconData _sourceIcon({
    required KomodoStack stack,
    required StackListItem? listItem,
    required List<RepoListItem> repos,
  }) {
    if (stack.config.filesOnHost) return AppIcons.server;
    final repoName = _resolveRepoName(
      stack: stack,
      listItem: listItem,
      repos: repos,
    );
    return repoName.isNotEmpty ? AppIcons.repos : AppIcons.notepadText;
  }

  String _sourceLabel({
    required KomodoStack stack,
    required StackListItem? listItem,
    required List<RepoListItem> repos,
  }) {
    if (stack.config.filesOnHost) return 'Files on server';

    final repoName = _resolveRepoName(
      stack: stack,
      listItem: listItem,
      repos: repos,
    );

    if (repoName.isEmpty) return 'UI Defined';

    final branch = stack.config.branch.trim().isNotEmpty
        ? stack.config.branch.trim()
        : (listItem?.info.branch.trim() ?? '');

    return branch.isNotEmpty ? '$repoName · $branch' : repoName;
  }

  String _resolveRepoName({
    required KomodoStack stack,
    required StackListItem? listItem,
    required List<RepoListItem> repos,
  }) {
    // 1) linked_repo id -> RepoListItem.name
    final linkedRepoId = stack.config.linkedRepo.trim();
    if (linkedRepoId.isNotEmpty) {
      for (final repo in repos) {
        if (repo.id == linkedRepoId) {
          return repo.name.trim();
        }
      }
    }

    // 2) Try to map repo path (namespace/repo) -> RepoListItem by info.repo
    final repoPath = (listItem?.info.repo.trim().isNotEmpty ?? false)
        ? listItem!.info.repo.trim()
        : stack.config.repo.trim();

    if (repoPath.isNotEmpty) {
      for (final repo in repos) {
        if (repo.info.repo.trim() == repoPath) {
          return repo.name.trim();
        }
      }
      // Fallback: if we can't resolve to a resource name, at least show the path.
      return repoPath;
    }

    return '';
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

  Future<void> _handleAction(
    BuildContext context,
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

    if (success) {
      ref
        ..invalidate(stackDetailProvider(stackId))
        ..invalidate(stackServicesProvider(stackId))
        ..invalidate(stackLogProvider(stackId));
    }

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

  void _discardConfig(KomodoStack stack) {
    _configEditorKey.currentState?.resetTo(stack.config);
    hideDirtySnackBar();
  }

  void _discardInfoChanges() {
    _infoEditorKey.currentState?.resetAll();
    hideDirtySnackBar();
  }

  Future<void> _saveConfig({required KomodoStack stack}) async {
    if (_configSaveInFlight) return;

    final draft = _configEditorKey.currentState;
    if (draft == null) {
      AppSnackBar.show(
        context,
        'Editor not ready. Please try again.',
        tone: AppSnackBarTone.error,
      );
      return;
    }

    final partialConfig = draft.buildPartialConfigParams();
    if (partialConfig.isEmpty) {
      hideDirtySnackBar();
      return;
    }

    final actions = ref.read(stackActionsProvider.notifier);
    setState(() => _configSaveInFlight = true);
    final updated = await actions.updateStackConfig(
      stackId: stack.id,
      partialConfig: partialConfig,
    );
    if (!mounted) return;
    setState(() => _configSaveInFlight = false);

    if (updated != null) {
      ref
        ..invalidate(stackDetailProvider(stack.id))
        ..invalidate(stacksProvider);

      _configEditorKey.currentState?.resetTo(updated.config);
      hideDirtySnackBar();
      AppSnackBar.show(context, 'Stack updated', tone: AppSnackBarTone.success);
      return;
    }

    final err = ref.read(stackActionsProvider).asError?.error;
    AppSnackBar.show(
      context,
      err != null ? 'Failed: $err' : 'Failed to update stack',
      tone: AppSnackBarTone.error,
    );

    reShowDirtySnackBarIfStillDirty(
      isStillDirty: () {
        return _configEditorKey.currentState
                ?.buildPartialConfigParams()
                .isNotEmpty ??
            false;
      },
      onDiscard: () => _discardConfig(stack),
      onSave: () => _saveConfig(stack: stack),
      saveEnabled: !_configSaveInFlight,
    );
  }

  Future<void> _saveInfoChanges() async {
    if (_infoSaveInFlight) return;
    final editor = _infoEditorKey.currentState;
    if (editor == null) return;

    setState(() => _infoSaveInFlight = true);
    final success = await editor.saveAll();
    if (!mounted) return;
    setState(() => _infoSaveInFlight = false);

    if (success) {
      hideDirtySnackBar();
      AppSnackBar.show(
        context,
        'Files updated',
        tone: AppSnackBarTone.success,
      );
      return;
    }

    AppSnackBar.show(
      context,
      'Failed to update files',
      tone: AppSnackBarTone.error,
    );

    reShowDirtySnackBarIfStillDirty(
      isStillDirty: () {
        return _infoEditorKey.currentState?.isDirty ?? false;
      },
      onDiscard: _discardInfoChanges,
      onSave: _saveInfoChanges,
      saveEnabled: !_infoSaveInFlight,
    );
  }

  Future<bool> _saveStackFile({
    required String stackId,
    required String filePath,
    required String contents,
    bool showSnackBar = true,
  }) async {
    final trimmedPath = filePath.trim();
    if (trimmedPath.isEmpty) {
      if (showSnackBar) {
        AppSnackBar.show(
          context,
          'File path is required.',
          tone: AppSnackBarTone.error,
        );
      }
      return false;
    }

    final actions = ref.read(stackActionsProvider.notifier);
    final success = await actions.writeStackFileContents(
      stackIdOrName: stackId,
      filePath: trimmedPath,
      contents: contents,
    );

    if (success) {
      ref.invalidate(stackDetailProvider(stackId));
      if (context.mounted && showSnackBar) {
        AppSnackBar.show(
          context,
          'File updated',
          tone: AppSnackBarTone.success,
        );
      }
      return true;
    }

    final err = ref.read(stackActionsProvider).asError?.error;
    if (context.mounted && showSnackBar) {
      AppSnackBar.show(
        context,
        err != null ? 'Failed: $err' : 'Failed to update file',
        tone: AppSnackBarTone.error,
      );
    }
    return false;
  }
}

class _PinnedTabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  _PinnedTabBarHeaderDelegate({
    required this.tabBar,
    required this.backgroundColor,
  });

  final TabBar tabBar;
  final Color backgroundColor;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: backgroundColor,
      elevation: overlapsContent ? 1 : 0,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedTabBarHeaderDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin<_KeepAlive> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
