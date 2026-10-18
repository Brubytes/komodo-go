import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/resources/resource_manage_actions.dart';
import 'package:komodo_go/composition/stacks/stack_config_editor.dart';
import 'package:komodo_go/composition/stacks/stack_updates_provider.dart';
import 'package:komodo_go/composition/stacks/stack_updates_tab.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/core_info_provider.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/router/polling_route_aware_state.dart';
import 'package:komodo_go/core/router/resource_routes.dart';
import 'package:komodo_go/core/router/shell_state_provider.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/dialogs/confirm_destructive_dialog.dart';
import 'package:komodo_go/core/widgets/empty_state_view.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/providers/presentation/providers/docker_registry_provider.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/data/repositories/stack_repository.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_provider.dart';
import 'package:komodo_go/features/stacks/presentation/views/stack_detail/stack_detail_sections.dart';
import 'package:komodo_go/features/stacks/presentation/widgets/stack_card.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';
import 'package:komodo_go/shared/logs/server_log_explorer.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_metadata.dart';

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
    with DetailDirtySnackBarMixin<StackDetailView> {
  static const _tabServices = 'services';
  static const _tabConfig = 'config';
  static const _tabUpdates = 'updates';
  static const _tabLogs = 'logs';

  final _tabsKey = GlobalKey<DetailTabScaffoldState>();
  final _configEditorKey = GlobalKey<StackConfigEditorContentState>();
  final _infoEditorKey = GlobalKey<StackInfoTabContentState>();

  String _activeTabId = _tabServices;
  var _autoRefreshLogs = true;
  var _saveInFlight = false;
  var _configDirty = false;
  var _infoDirty = false;

  bool get _dirty => _configDirty || _infoDirty;

  KomodoStack? get _currentStack =>
      ref.read(stackDetailProvider(widget.stackId)).asData?.value;

  void _onDirtyChanged({bool? config, bool? info}) {
    final before = _dirty;
    if (config != null) _configDirty = config;
    if (info != null) _infoDirty = info;
    syncDirtySnackBar(
      dirty: _dirty,
      onDiscard: _discardAll,
      onSave: _saveAll,
      saveEnabled: !_saveInFlight,
    );
    if (before != _dirty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isShellActive = ref.watch(mainShellIndexProvider) == 1;
    final logsPolling = shouldPoll(
      isActiveTab: isShellActive && _activeTabId == _tabLogs,
      enabled: _autoRefreshLogs,
    );

    final stackAsync = ref.watch(stackDetailProvider(widget.stackId));
    final coreInfoAsync = ref.watch(coreInfoProvider);
    final servicesAsync = ref.watch(stackServicesProvider(widget.stackId));
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
    final stack = stackAsync.asData?.value;
    final hasInfo = _shouldShowInfo(stack);

    return UnsavedChangesGuard(
      dirty: _dirty,
      onDiscarded: hideDirtySnackBar,
      child: Scaffold(
        appBar: MainAppBar(
          title: widget.stackName,
          icon: AppIcons.stacks,
          markColor: AppTokens.resourceStacks,
          markUseGradient: true,
          centerTitle: true,
          status: stackAppBarStatus(
            listItem: listItem,
            serviceCount: serviceCount,
          ),
        ),
        body: Stack(
          children: [
            DetailTabScaffold(
              key: _tabsKey,
              initialTabId: _tabServices,
              onTabChanged: (id) => setState(() => _activeTabId = id),
              headerSlivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: stackAsync.when(
                      data: (stack) => stack != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                StackHeader(
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
                                  onAction: _handleAction,
                                  onServerTap: stack.config.serverId.isEmpty
                                      ? null
                                      : () => context.push(
                                          resourceDetailRoute(
                                            AppRoutes.servers,
                                            stack.config.serverId,
                                            name: serverNameForId(
                                              stack.config.serverId,
                                            ),
                                          ),
                                        ),
                                  onSourceTap:
                                      stack.config.linkedRepo.trim().isEmpty
                                      ? null
                                      : () => context.push(
                                          resourceDetailRoute(
                                            AppRoutes.repos,
                                            stack.config.linkedRepo.trim(),
                                          ),
                                        ),
                                ),
                                const Gap(AppSpacing.md),
                                StackActionBar(
                                  state: listItem?.info.state,
                                  needsDeploy: stackNeedsDeploy(
                                    stack: stack,
                                    listItem: listItem,
                                    updateCount: updateCount,
                                  ),
                                  onAction: _handleAction,
                                  manageGroup: buildResourceManageGroup(
                                    context: context,
                                    ref: ref,
                                    metadata: ResourceMetadata(
                                      kind: ResourceKind.stacks,
                                      id: stack.id,
                                      name: stack.name,
                                      description: stack.description,
                                      template: stack.template,
                                      tags: stack.tags,
                                    ),
                                    onMutated: () {
                                      ref
                                        ..invalidate(stacksProvider)
                                        ..invalidate(
                                          stackDetailProvider(widget.stackId),
                                        );
                                    },
                                  ),
                                ),
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
              ],
              tabs: [
                DetailTabSpec(
                  id: _tabServices,
                  label: 'Services',
                  icon: AppIcons.toolbox,
                  body: RefreshIndicator(
                    onRefresh: () async {
                      ref
                        ..invalidate(stackServicesProvider(widget.stackId))
                        ..invalidate(stackUpdatesProvider(widget.stackId));
                    },
                    child: DetailTabScrollView.box(
                      scrollKey: PageStorageKey(
                        'stack_${widget.stackId}_services',
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          servicesAsync.when(
                            data: (services) => services.isEmpty
                                ? const EmptyStateView.inline(
                                    icon: AppIcons.containers,
                                    title: 'No services found',
                                    message:
                                        'Services will appear here once '
                                        'the stack is deployed.',
                                  )
                                : Column(
                                    children: [
                                      for (final service in services) ...[
                                        StackServiceCard(service: service),
                                        const Gap(AppSpacing.md),
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
                ),
                DetailTabSpec(
                  id: _tabConfig,
                  label: 'Config',
                  icon: AppIcons.bolt,
                  body: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(stackDetailProvider(widget.stackId));
                    },
                    child: DetailTabScrollView.box(
                      scrollKey: PageStorageKey(
                        'stack_${widget.stackId}_config',
                      ),
                      child: stackAsync.when(
                        data: (stack) => stack != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StackConfigEditorContent(
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
                                    onDirtyChanged: (dirty) =>
                                        _onDirtyChanged(config: dirty),
                                  ),
                                  if (hasInfo) ...[
                                    const Gap(AppSpacing.md),
                                    StackInfoTabContent(
                                      key: _infoEditorKey,
                                      info: stack.info,
                                      onSaveFile:
                                          (
                                            path,
                                            contents, {
                                            showSnackBar = true,
                                          }) => _saveStackFile(
                                            stackId: stack.id,
                                            filePath: path,
                                            contents: contents,
                                            showSnackBar: showSnackBar,
                                          ),
                                      onDirtyChanged: (dirty) =>
                                          _onDirtyChanged(info: dirty),
                                    ),
                                  ],
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
                ),
                DetailTabSpec(
                  id: _tabUpdates,
                  label: 'Updates',
                  icon: AppIcons.history,
                  body: StackUpdatesTab(stackId: widget.stackId),
                ),
                DetailTabSpec(
                  id: _tabLogs,
                  label: 'Logs',
                  icon: AppIcons.logs,
                  body: DetailTabFillBody(
                    child: ServerLogExplorer(
                      key: ValueKey('stack_log_explorer_${widget.stackId}'),
                      fillHeight: true,
                      autoRefresh: logsPolling,
                      onAutoRefreshChanged: (value) =>
                          setState(() => _autoRefreshLogs = value),
                      loader: (request) async {
                        final repository = ref.read(stackRepositoryProvider);
                        if (repository == null) {
                          throw StateError('No active Komodo connection.');
                        }
                        final result = request.isSearch
                            ? await repository.searchServerLog(
                                stackIdOrName: widget.stackId,
                                terms: request.terms,
                                combinator: request.combinator,
                                invert: request.invert,
                                timestamps: request.timestamps,
                              )
                            : await repository.loadServerLog(
                                stackIdOrName: widget.stackId,
                                tail: request.tail,
                                timestamps: request.timestamps,
                              );
                        return result.fold(
                          (failure) => throw StateError(failure.displayMessage),
                          (log) => log,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            if (actionsState.isLoading)
              ColoredBox(
                color: scheme.scrim.withValues(alpha: 0.25),
                child: const Center(child: AppSkeletonCard()),
              ),
          ],
        ),
      ),
    );
  }

  /// Remote files / deployed config only exist for repo or on-host stacks.
  bool _shouldShowInfo(KomodoStack? stack) {
    if (stack == null) return false;
    if (stack.config.filesOnHost) return true;
    return stack.config.linkedRepo.trim().isNotEmpty ||
        stack.config.repo.trim().isNotEmpty;
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
    return [for (final tag in tags) tagNameById[tag] ?? tag];
  }

  Future<void> _handleAction(StackAction action) async {
    final stackId = widget.stackId;
    final name = widget.stackName;
    final actions = ref.read(stackActionsProvider.notifier);
    if (action == StackAction.checkUpdates) {
      final services = await actions.checkForUpdates(stackId);
      if (!mounted) return;
      ref
        ..invalidate(stackDetailProvider(stackId))
        ..invalidate(stackServicesProvider(stackId))
        ..invalidate(stacksProvider);
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
    if (action == StackAction.stop) {
      final confirmed = await confirmDestructive(
        context,
        title: 'Stop $name?',
        message: 'This stops all containers of "$name". Continue?',
        confirmLabel: 'Stop',
      );
      if (!confirmed || !mounted) return;
    }
    if (action == StackAction.destroy) {
      final confirmed = await confirmDestructive(
        context,
        title: 'Destroy $name?',
        message:
            'This runs docker compose down and removes the containers of '
            '"$name". Continue?',
        confirmLabel: 'Destroy',
      );
      if (!confirmed || !mounted) return;
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
    if (!mounted) return;
    final actionError = ref.read(stackActionsProvider).asError?.error;
    final actionErrorMessage = actionError is String
        ? actionError.trim()
        : actionError?.toString().trim();
    final hasActionError =
        actionErrorMessage != null && actionErrorMessage.isNotEmpty;

    if (success) {
      ref
        ..invalidate(stackDetailProvider(stackId))
        ..invalidate(stackServicesProvider(stackId))
        ..invalidate(stacksProvider);
    }

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

  void _discardAll() {
    final stack = _currentStack;
    if (stack != null) _configEditorKey.currentState?.resetTo(stack.config);
    _infoEditorKey.currentState?.resetAll();
    hideDirtySnackBar();
  }

  bool _stillDirty() {
    final config =
        _configEditorKey.currentState?.buildPartialConfigParams().isNotEmpty ??
        false;
    final info = _infoEditorKey.currentState?.isDirty ?? false;
    return config || info;
  }

  /// Saves config changes and edited stack files in one go.
  Future<void> _saveAll() async {
    if (_saveInFlight) return;
    final stack = _currentStack;
    if (stack == null) return;

    setState(() => _saveInFlight = true);
    var ok = true;
    if (_configEditorKey.currentState?.buildPartialConfigParams().isNotEmpty ??
        false) {
      ok = await _saveConfig(stack);
    }
    if (ok && (_infoEditorKey.currentState?.isDirty ?? false)) {
      ok = await _saveInfoChanges();
    }
    if (!mounted) return;
    setState(() => _saveInFlight = false);

    if (ok) {
      hideDirtySnackBar();
      AppSnackBar.show(context, 'Stack updated', tone: AppSnackBarTone.success);
      return;
    }

    reShowDirtySnackBarIfStillDirty(
      isStillDirty: _stillDirty,
      onDiscard: _discardAll,
      onSave: _saveAll,
    );
  }

  Future<bool> _saveConfig(KomodoStack stack) async {
    final draft = _configEditorKey.currentState;
    if (draft == null) {
      AppSnackBar.show(
        context,
        'Editor not ready. Please try again.',
        tone: AppSnackBarTone.error,
      );
      return false;
    }

    final partialConfig = draft.buildPartialConfigParams();
    if (partialConfig.isEmpty) return true;

    final actions = ref.read(stackActionsProvider.notifier);
    final updated = await actions.updateStackConfig(
      stackId: stack.id,
      partialConfig: partialConfig,
    );
    if (!mounted) return false;

    if (updated != null) {
      ref
        ..invalidate(stackDetailProvider(stack.id))
        ..invalidate(stacksProvider);
      _configEditorKey.currentState?.resetTo(updated.config);
      return true;
    }

    final err = ref.read(stackActionsProvider).asError?.error;
    AppSnackBar.show(
      context,
      err != null ? 'Failed: $err' : 'Failed to update stack',
      tone: AppSnackBarTone.error,
    );
    return false;
  }

  Future<bool> _saveInfoChanges() async {
    final editor = _infoEditorKey.currentState;
    if (editor == null) return true;
    final success = await editor.saveAll();
    if (!mounted) return false;
    if (!success) {
      AppSnackBar.show(
        context,
        'Failed to update files',
        tone: AppSnackBarTone.error,
      );
    }
    return success;
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

    if (!mounted) return success;

    if (success) {
      ref.invalidate(stackDetailProvider(stackId));
      if (showSnackBar) {
        AppSnackBar.show(
          context,
          'File updated',
          tone: AppSnackBarTone.success,
        );
      }
      return true;
    }

    final err = ref.read(stackActionsProvider).asError?.error;
    if (showSnackBar) {
      AppSnackBar.show(
        context,
        err != null ? 'Failed: $err' : 'Failed to update file',
        tone: AppSnackBarTone.error,
      );
    }
    return false;
  }
}
