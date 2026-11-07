import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/builds/build_detail_sections.dart';
import 'package:komodo_go/composition/deployments/deployment_detail_sections.dart';
import 'package:komodo_go/composition/resources/resource_manage_actions.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/router/polling_route_aware_state.dart';
import 'package:komodo_go/core/router/resource_routes.dart';
import 'package:komodo_go/core/router/shell_state_provider.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/async/action_busy_overlay.dart';
import 'package:komodo_go/core/widgets/async/async_content.dart';
import 'package:komodo_go/core/widgets/async/detail_skeletons.dart';
import 'package:komodo_go/core/widgets/async/editor_host.dart';
import 'package:komodo_go/core/widgets/async/refresh_helpers.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/dialogs/confirm_destructive_dialog.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/builds/presentation/providers/builds_provider.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:komodo_go/features/deployments/data/repositories/deployment_repository.dart';
import 'package:komodo_go/features/deployments/presentation/providers/deployments_provider.dart';
import 'package:komodo_go/features/deployments/presentation/widgets/deployment_card.dart';
import 'package:komodo_go/features/providers/presentation/providers/docker_registry_provider.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/shared/logs/server_log_explorer.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_metadata.dart';

/// View displaying detailed deployment information.
class DeploymentDetailView extends ConsumerStatefulWidget {
  const DeploymentDetailView({
    required this.deploymentId,
    required this.deploymentName,
    super.key,
  });

  final String deploymentId;
  final String deploymentName;

  @override
  ConsumerState<DeploymentDetailView> createState() =>
      _DeploymentDetailViewState();
}

class _DeploymentDetailViewState
    extends PollingRouteAwareState<DeploymentDetailView>
    with DetailDirtySnackBarMixin<DeploymentDetailView> {
  static const _tabConfig = 'config';
  static const _tabLogs = 'logs';
  static const _tabBuild = 'build';

  final _tabsKey = GlobalKey<DetailTabScaffoldState>();
  final _configEditorKey = GlobalKey<DeploymentConfigEditorContentState>();

  Timer? _buildRefreshTimer;
  String _activeTabId = _tabConfig;
  var _autoRefreshLogs = true;
  var _configSaveInFlight = false;
  var _dirty = false;
  var _pulling = false;

  @override
  void dispose() {
    _buildRefreshTimer?.cancel();
    _buildRefreshTimer = null;
    super.dispose();
  }

  @override
  void onVisibilityChanged() {
    if (!mounted) return;
    _syncBuildPolling(isShellTabActive: ref.read(mainShellIndexProvider) == 1);
    super.onVisibilityChanged();
  }

  void _startBuildPolling() {
    _buildRefreshTimer?.cancel();
    _buildRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!shouldRunPollTick()) return;
      final current = ref
          .read(deploymentDetailProvider(widget.deploymentId))
          .value;
      final buildId = current?.info?.buildId?.trim() ?? '';
      if (buildId.isEmpty) return;
      unawaited(ref.read(buildDetailProvider(buildId).notifier).pollRefresh());
    });
  }

  void _stopBuildPolling() {
    _buildRefreshTimer?.cancel();
    _buildRefreshTimer = null;
  }

  void _syncBuildPolling({required bool isShellTabActive}) {
    final active = isShellTabActive && _activeTabId == _tabBuild;
    if (shouldPoll(isActiveTab: active, enabled: _autoRefreshLogs)) {
      if (_buildRefreshTimer == null) _startBuildPolling();
    } else {
      _stopBuildPolling();
    }
  }

  void _onDirtyChanged(Deployment deployment, {required bool dirty}) {
    final before = _dirty;
    _dirty = dirty;
    syncDirtySnackBar(
      dirty: dirty,
      onDiscard: () => _discardConfig(deployment),
      onSave: () => _saveConfig(deployment: deployment),
      saveEnabled: !_configSaveInFlight,
    );
    if (before != dirty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(mainShellIndexProvider, (previous, next) {
      _syncBuildPolling(isShellTabActive: next == 1);
    });

    final deploymentId = widget.deploymentId;
    final deploymentAsync = ref.watch(deploymentDetailProvider(deploymentId));
    final actionsState = ref.watch(deploymentActionsProvider);
    final serversListAsync = ref.watch(serversProvider);
    final registryAccountsAsync = ref.watch(dockerRegistryAccountsProvider);
    final deployment = deploymentAsync.value;
    final isShellActive = ref.watch(mainShellIndexProvider) == 1;
    final logsPolling = shouldPoll(
      isActiveTab: isShellActive && _activeTabId == _tabLogs,
      enabled: _autoRefreshLogs,
    );

    String? serverNameForId(String serverId) {
      final servers = serversListAsync.value;
      if (servers == null || serverId.isEmpty) return null;
      for (final s in servers) {
        if (s.id == serverId) return s.name;
      }
      return null;
    }

    final buildsList = ref.watch(buildsProvider).value;
    String? buildNameForId(String buildId) {
      if (buildsList == null || buildId.isEmpty) return null;
      for (final b in buildsList) {
        if (b.id == buildId) return b.name;
      }
      return null;
    }

    final hasBuild = (deployment?.info?.buildId?.trim() ?? '').isNotEmpty;

    return UnsavedChangesGuard(
      dirty: _dirty,
      onDiscarded: hideDirtySnackBar,
      child: Scaffold(
        appBar: MainAppBar(
          title: widget.deploymentName,
          icon: AppIcons.deployments,
          markColor: AppTokens.resourceDeployments,
          markUseGradient: true,
          centerTitle: true,
          status: deployment == null
              ? null
              : deploymentAppBarStatus(deployment),
        ),
        body: Stack(
          children: [
            DetailTabScaffold(
              key: _tabsKey,
              initialTabId: _tabConfig,
              onTabChanged: (id) {
                setState(() => _activeTabId = id);
                _syncBuildPolling(isShellTabActive: isShellActive);
              },
              headerSlivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: AsyncContent<Deployment?>(
                      value: deploymentAsync,
                      errorTitle: 'Failed to load deployment',
                      onRetry: _reloadDeployment,
                      showProgress: !_pulling,
                      bannerPadding: const EdgeInsets.only(
                        bottom: AppSpacing.sm,
                      ),
                      skeletonBuilder: (_) => const DetailHeaderSkeleton(),
                      builder: (context, deployment) {
                        if (deployment == null) {
                          return const DeploymentMessageSurface(
                            message: 'Deployment not found',
                          );
                        }

                        final serverId =
                            deployment.config?.serverId ??
                            deployment.info?.serverId ??
                            '';
                        final buildId = deployment.info?.buildId?.trim() ?? '';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DeploymentHeader(
                              deployment: deployment,
                              serverName: serverNameForId(serverId),
                              buildName: buildNameForId(buildId),
                              onAction: _handleAction,
                              onServerTap: serverId.isEmpty
                                  ? null
                                  : () => context.push(
                                      resourceDetailRoute(
                                        AppRoutes.servers,
                                        serverId,
                                        name: serverNameForId(serverId),
                                      ),
                                    ),
                              onBuildTap: buildId.isEmpty
                                  ? null
                                  : () => context.push(
                                      resourceDetailRoute(
                                        AppRoutes.builds,
                                        buildId,
                                        name: buildNameForId(buildId),
                                      ),
                                    ),
                            ),
                            const Gap(AppSpacing.md),
                            DeploymentActionBar(
                              deployment: deployment,
                              onAction: _handleAction,
                              manageGroup: buildResourceManageGroup(
                                context: context,
                                ref: ref,
                                metadata: ResourceMetadata(
                                  kind: ResourceKind.deployments,
                                  id: deployment.id,
                                  name: deployment.name,
                                  description: deployment.description ?? '',
                                  template: deployment.template,
                                  tags: deployment.tags,
                                ),
                                onMutated: () {
                                  ref
                                    ..invalidate(deploymentsProvider)
                                    ..invalidate(
                                      deploymentDetailProvider(deploymentId),
                                    );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
              tabs: [
                DetailTabSpec(
                  id: _tabConfig,
                  label: 'Config',
                  icon: AppIcons.bolt,
                  body: RefreshIndicator(
                    onRefresh: _pull,
                    child: DetailTabScrollView.box(
                      scrollKey: PageStorageKey(
                        'deployment_${widget.deploymentId}_config',
                      ),
                      child: EditorHost<Deployment>(
                        value: deploymentAsync,
                        isDirty: () => _dirty,
                        errorTitle: 'Failed to load deployment',
                        onRetry: _reloadDeployment,
                        showProgress: false,
                        showStaleBanner: false,
                        skeletonBuilder: (_) => const DetailTabSkeleton(),
                        emptyBuilder: (_) => const DeploymentMessageSurface(
                          message: 'Deployment not found',
                        ),
                        builder: (context, deployment) {
                          return deployment.config != null
                              ? DeploymentConfigEditorContent(
                                  key: _configEditorKey,
                                  initialConfig: deployment.config!,
                                  imageLabel: deployment.imageLabel,
                                  servers: serversListAsync.value ?? const [],
                                  registryAccounts:
                                      registryAccountsAsync.value ?? const [],
                                  onDirtyChanged: (dirty) => _onDirtyChanged(
                                    deployment,
                                    dirty: dirty,
                                  ),
                                )
                              : DeploymentConfigContent(
                                  deployment: deployment,
                                  serverName: serverNameForId(
                                    deployment.config?.serverId ??
                                        deployment.info?.serverId ??
                                        '',
                                  ),
                                );
                        },
                      ),
                    ),
                  ),
                ),
                DetailTabSpec(
                  id: _tabLogs,
                  label: 'Logs',
                  icon: AppIcons.logs,
                  body: DetailTabFillBody(
                    child: ServerLogExplorer(
                      key: ValueKey(
                        'deployment_log_explorer_${widget.deploymentId}',
                      ),
                      fillHeight: true,
                      autoRefresh: logsPolling,
                      onAutoRefreshChanged: (value) {
                        setState(() => _autoRefreshLogs = value);
                        _syncBuildPolling(isShellTabActive: isShellActive);
                      },
                      loader: (request) async {
                        final repository = ref.read(
                          deploymentRepositoryProvider,
                        );
                        if (repository == null) {
                          throw StateError('No active Komodo connection.');
                        }
                        final result = request.isSearch
                            ? await repository.searchServerLog(
                                deploymentIdOrName: widget.deploymentId,
                                terms: request.terms,
                                combinator: request.combinator,
                                invert: request.invert,
                                timestamps: request.timestamps,
                              )
                            : await repository.loadServerLog(
                                deploymentIdOrName: widget.deploymentId,
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
                if (hasBuild)
                  DetailTabSpec(
                    id: _tabBuild,
                    label: 'Build',
                    icon: AppIcons.builds,
                    body: RefreshIndicator(
                      onRefresh: _pull,
                      child: DetailTabScrollView.box(
                        scrollKey: PageStorageKey(
                          'deployment_${widget.deploymentId}_build',
                        ),
                        child: _buildOutput(deployment),
                      ),
                    ),
                  ),
              ],
            ),
            ActionBusyOverlay(busy: actionsState.isLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildOutput(Deployment? deployment) {
    final buildId = deployment?.info?.buildId?.trim() ?? '';
    if (buildId.isEmpty) {
      return const DeploymentMessageSurface(
        message: 'No build output available for this deployment',
      );
    }

    final buildAsync = ref.watch(buildDetailProvider(buildId));
    return AsyncContent<KomodoBuild?>(
      value: buildAsync,
      errorTitle: 'Logs unavailable',
      onRetry: () => ref.invalidate(buildDetailProvider(buildId)),
      showProgress: !_pulling,
      skeletonBuilder: (_) => const DetailTabSkeleton(count: 1),
      builder: (context, build) {
        if (build == null) {
          return const DeploymentMessageSurface(message: 'Build not found');
        }

        final hasAnyLogs =
            (build.info.remoteError?.trim().isNotEmpty ?? false) ||
            (build.info.remoteContents?.trim().isNotEmpty ?? false) ||
            (build.info.builtContents?.trim().isNotEmpty ?? false);

        if (!hasAnyLogs) {
          return const DeploymentMessageSurface(message: 'No log output');
        }

        return DetailSection(
          title: 'Build output',
          icon: AppIcons.package,
          child: BuildLogsContent(buildResource: build),
        );
      },
    );
  }

  /// Pull-to-refresh for every tab: awaits the real data so the indicator
  /// stays until it arrived.
  Future<void> _pull() async {
    setState(() => _pulling = true);
    try {
      final buildId =
          ref
              .read(deploymentDetailProvider(widget.deploymentId))
              .value
              ?.info
              ?.buildId
              ?.trim() ??
          '';
      await refreshProviders(ref, [
        deploymentDetailProvider(widget.deploymentId).future,
        deploymentsProvider.future,
        if (buildId.isNotEmpty) buildDetailProvider(buildId).future,
      ]);
    } finally {
      if (mounted) setState(() => _pulling = false);
    }
  }

  void _reloadDeployment() {
    ref.invalidate(deploymentDetailProvider(widget.deploymentId));
  }

  void _discardConfig(Deployment deployment) {
    final latest =
        ref.read(deploymentDetailProvider(widget.deploymentId)).value ??
        deployment;
    final config = latest.config ?? deployment.config;
    if (config == null) return;
    _configEditorKey.currentState?.resetTo(config);
    hideDirtySnackBar();
  }

  Future<void> _saveConfig({required Deployment deployment}) async {
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

    final validationError = draft.validateDraft();
    if (validationError != null) {
      AppSnackBar.show(context, validationError, tone: AppSnackBarTone.error);
      return;
    }

    final partialConfig = draft.buildPartialConfigParams();
    if (partialConfig.isEmpty) {
      hideDirtySnackBar();
      return;
    }

    final actions = ref.read(deploymentActionsProvider.notifier);
    setState(() => _configSaveInFlight = true);
    final updated = await actions.updateDeploymentConfig(
      deploymentId: deployment.id,
      partialConfig: partialConfig,
    );
    if (!mounted) return;
    setState(() => _configSaveInFlight = false);

    if (updated != null) {
      ref.invalidate(deploymentDetailProvider(deployment.id));
      final updatedConfig = updated.config;
      if (updatedConfig != null) {
        _configEditorKey.currentState?.resetTo(updatedConfig);
      }
      hideDirtySnackBar();
      AppSnackBar.show(
        context,
        'Deployment updated',
        tone: AppSnackBarTone.success,
      );
      return;
    }

    final err = ref.read(deploymentActionsProvider).asError?.error;
    AppSnackBar.show(
      context,
      err != null ? 'Failed: $err' : 'Failed to update deployment',
      tone: AppSnackBarTone.error,
    );

    reShowDirtySnackBarIfStillDirty(
      isStillDirty: () {
        return _configEditorKey.currentState
                ?.buildPartialConfigParams()
                .isNotEmpty ??
            false;
      },
      onDiscard: () => _discardConfig(deployment),
      onSave: () => _saveConfig(deployment: deployment),
      saveEnabled: !_configSaveInFlight,
    );
  }

  Future<void> _handleAction(DeploymentAction action) async {
    final deploymentId = widget.deploymentId;
    final name = widget.deploymentName;
    final actions = ref.read(deploymentActionsProvider.notifier);

    if (action == DeploymentAction.checkUpdates) {
      final available = await actions.checkForUpdate(deploymentId);
      if (!mounted) return;
      ref
        ..invalidate(deploymentDetailProvider(deploymentId))
        ..invalidate(deploymentsProvider);
      AppSnackBar.show(
        context,
        available == null
            ? 'Image check failed. Please try again.'
            : available
            ? 'A newer image is available.'
            : 'The deployed image is up to date.',
        tone: available == null
            ? AppSnackBarTone.error
            : available
            ? AppSnackBarTone.warning
            : AppSnackBarTone.success,
      );
      return;
    }

    if (action == DeploymentAction.stop) {
      final confirmed = await confirmDestructive(
        context,
        title: 'Stop $name?',
        message: 'This stops the container of "$name". Continue?',
        confirmLabel: 'Stop',
      );
      if (!confirmed || !mounted) return;
    }

    if (action == DeploymentAction.destroy) {
      final confirmed = await confirmDestructive(
        context,
        title: 'Destroy $name?',
        message: 'This stops and removes the container of "$name". Continue?',
        confirmLabel: 'Destroy',
      );
      if (!confirmed || !mounted) return;
    }

    final success = await switch (action) {
      DeploymentAction.start => actions.start(deploymentId),
      DeploymentAction.stop => actions.stop(deploymentId),
      DeploymentAction.restart => actions.restart(deploymentId),
      DeploymentAction.pause => actions.pause(deploymentId),
      DeploymentAction.unpause => actions.unpause(deploymentId),
      DeploymentAction.destroy => actions.destroy(deploymentId),
      DeploymentAction.deploy => actions.deploy(deploymentId),
      DeploymentAction.pullImages => actions.pullImages(deploymentId),
      DeploymentAction.checkUpdates => Future<bool>.value(false),
    };

    if (!mounted) return;

    if (success) {
      ref.invalidate(deploymentDetailProvider(deploymentId));
    }

    AppSnackBar.show(
      context,
      success
          ? 'Action submitted. Check updates for the result.'
          : 'Action failed. Please try again.',
      tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }
}
