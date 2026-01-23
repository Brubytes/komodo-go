import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/polling_route_aware_state.dart';
import 'package:komodo_go/core/router/shell_state_provider.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/menus/komodo_popup_menu.dart';
import 'package:komodo_go/features/builds/presentation/providers/builds_provider.dart';
import 'package:komodo_go/features/builds/presentation/views/build_detail/build_detail_sections.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:komodo_go/features/deployments/presentation/providers/deployments_provider.dart';
import 'package:komodo_go/features/deployments/presentation/views/deployment_detail/deployment_detail_sections.dart';
import 'package:komodo_go/features/deployments/presentation/widgets/deployment_card.dart';
import 'package:komodo_go/features/providers/presentation/providers/docker_registry_provider.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';

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
    with
        SingleTickerProviderStateMixin,
        DetailDirtySnackBarMixin<DeploymentDetailView> {
  static const int _tabLogs = 1;

  late final TabController _tabController;
  Timer? _logRefreshTimer;
  var _autoRefreshLogs = true;

  final _configEditorKey = GlobalKey<DeploymentConfigEditorContentState>();
  var _configSaveInFlight = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      final current = ref
          .read(deploymentDetailProvider(widget.deploymentId))
          .asData
          ?.value;
      final buildId = current?.info?.buildId?.trim() ?? '';
      if (buildId.isEmpty) return;
      ref.invalidate(buildDetailProvider(buildId));
    });
  }

  void _stopLogPolling() {
    _logRefreshTimer?.cancel();
    _logRefreshTimer = null;
  }

  void _syncLogPolling({required bool isShellTabActive}) {
    final isLogsTabActive = _tabController.index == _tabLogs;
    final isActiveTab = isShellTabActive && isLogsTabActive;
    if (shouldPoll(isActiveTab: isActiveTab, enabled: _autoRefreshLogs)) {
      _startLogPolling();
    } else {
      _stopLogPolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActiveTab = ref.watch(mainShellIndexProvider) == 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncLogPolling(isShellTabActive: isActiveTab);
    });

    final deploymentId = widget.deploymentId;
    final deploymentAsync = ref.watch(deploymentDetailProvider(deploymentId));
    final actionsState = ref.watch(deploymentActionsProvider);
    final serversListAsync = ref.watch(serversProvider);
    final registryAccountsAsync = ref.watch(dockerRegistryAccountsProvider);
    final scheme = Theme.of(context).colorScheme;

    String? serverNameForId(String serverId) {
      final servers = serversListAsync.asData?.value;
      if (servers == null || serverId.isEmpty) return null;
      for (final s in servers) {
        if (s.id == serverId) return s.name;
      }
      return null;
    }

    return Scaffold(
      appBar: MainAppBar(
        title: widget.deploymentName,
        icon: AppIcons.deployments,
        markColor: AppTokens.resourceDeployments,
        markUseGradient: true,
        centerTitle: true,
        actions: [
          PopupMenuButton<DeploymentAction>(
            icon: const Icon(AppIcons.moreVertical),
            onSelected: (action) =>
                _handleAction(context, deploymentId, action),
            itemBuilder: (context) {
              final deployment = deploymentAsync.asData?.value;
              final state = deployment?.info?.state ?? DeploymentState.unknown;
              final hasImage = deployment?.imageLabel.isNotEmpty ?? false;
              return _buildMenuItems(scheme, state, hasImage: hasImage);
            },
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
                    child: deploymentAsync.when(
                      data: (deployment) {
                        if (deployment == null) {
                          return const DeploymentMessageSurface(
                            message: 'Deployment not found',
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DeploymentHeroPanel(
                              deployment: deployment,
                              serverName: serverNameForId(
                                deployment.config?.serverId ??
                                    deployment.info?.serverId ??
                                    '',
                              ),
                            ),
                            const Gap(12),
                          ],
                        );
                      },
                      loading: () => const DeploymentLoadingSurface(),
                      error: (error, _) =>
                          DeploymentMessageSurface(message: 'Error: $error'),
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedTabBarHeaderDelegate(
                    backgroundColor: scheme.surface,
                    tabBar: TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Config'),
                        Tab(text: 'Logs'),
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
                      ref.invalidate(deploymentDetailProvider(deploymentId));
                    },
                    child: ListView(
                      key: PageStorageKey(
                        'deployment_${widget.deploymentId}_config',
                      ),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      children: [
                        deploymentAsync.when(
                          data: (deployment) {
                            if (deployment == null) {
                              return const DeploymentMessageSurface(
                                message: 'Deployment not found',
                              );
                            }

                            return DetailSurface(
                              child: deployment.config != null
                                  ? DeploymentConfigEditorContent(
                                      key: _configEditorKey,
                                      initialConfig: deployment.config!,
                                      imageLabel: deployment.imageLabel,
                                      servers:
                                          serversListAsync.asData?.value ??
                                          const [],
                                      registryAccounts:
                                          registryAccountsAsync.asData?.value ??
                                          const [],
                                      onDirtyChanged: (dirty) {
                                        syncDirtySnackBar(
                                          dirty: dirty,
                                          onDiscard: () =>
                                              _discardConfig(deployment),
                                          onSave: () => _saveConfig(
                                            deployment: deployment,
                                          ),
                                          saveEnabled: !_configSaveInFlight,
                                        );
                                      },
                                    )
                                  : DeploymentConfigContent(
                                      deployment: deployment,
                                      serverName: serverNameForId(
                                        deployment.config?.serverId ??
                                            deployment.info?.serverId ??
                                            '',
                                      ),
                                    ),
                            );
                          },
                          loading: () => const DeploymentLoadingSurface(),
                          error: (error, _) => DeploymentMessageSurface(
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
                      final deployment = deploymentAsync.asData?.value;
                      final buildId = deployment?.info?.buildId?.trim() ?? '';
                      ref.invalidate(deploymentDetailProvider(deploymentId));
                      if (buildId.isNotEmpty) {
                        ref.invalidate(buildDetailProvider(buildId));
                      }
                    },
                    child: ListView(
                      key: PageStorageKey(
                        'deployment_${widget.deploymentId}_logs',
                      ),
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
                        deploymentAsync.when(
                          data: (deployment) {
                            final buildId =
                                deployment?.info?.buildId?.trim() ?? '';
                            if (buildId.isEmpty) {
                              return const DeploymentMessageSurface(
                                message:
                                    'No build logs available for this deployment',
                              );
                            }

                            final buildAsync = ref.watch(
                              buildDetailProvider(buildId),
                            );
                            return buildAsync.when(
                              data: (build) {
                                if (build == null) {
                                  return const DeploymentMessageSurface(
                                    message: 'Build not found',
                                  );
                                }

                                final hasAnyLogs =
                                    (build.info.remoteError
                                            ?.trim()
                                            .isNotEmpty ??
                                        false) ||
                                    (build.info.remoteContents
                                            ?.trim()
                                            .isNotEmpty ??
                                        false) ||
                                    (build.info.builtContents
                                            ?.trim()
                                            .isNotEmpty ??
                                        false);

                                if (!hasAnyLogs) {
                                  return const DeploymentMessageSurface(
                                    message: 'No log output',
                                  );
                                }

                                return DetailSection(
                                  title: 'Logs',
                                  icon: AppIcons.package,
                                  child: BuildLogsContent(buildResource: build),
                                );
                              },
                              loading: () => const DeploymentLoadingSurface(),
                              error: (error, _) => DeploymentMessageSurface(
                                message: 'Logs unavailable: $error',
                              ),
                            );
                          },
                          loading: () => const DeploymentLoadingSurface(),
                          error: (error, _) => DeploymentMessageSurface(
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
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _discardConfig(Deployment deployment) {
    final config = deployment.config;
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

  List<PopupMenuEntry<DeploymentAction>> _buildMenuItems(
    ColorScheme scheme,
    DeploymentState state, {
    required bool hasImage,
  }) {
    final items = <PopupMenuEntry<DeploymentAction>>[];

    final deployLabel =
        (state == DeploymentState.notDeployed ||
            state == DeploymentState.unknown)
        ? 'Deploy'
        : 'Redeploy';

    items.add(
      komodoPopupMenuItem(
        value: DeploymentAction.deploy,
        icon: AppIcons.deployments,
        label: deployLabel,
        iconColor: scheme.primary,
      ),
    );

    if (hasImage) {
      items.add(
        komodoPopupMenuItem(
          value: DeploymentAction.pullImages,
          icon: AppIcons.download,
          label: 'Pull image',
          iconColor: scheme.primary,
        ),
      );
    }

    final showStart =
        state == DeploymentState.created || state == DeploymentState.exited;
    final showStop = state.isRunning;
    final showRestart = state.isRunning || state.isPaused;
    final showPause = state.isRunning;
    final showUnpause = state.isPaused;

    final hasLifecycle =
        showStart || showStop || showRestart || showPause || showUnpause;
    if (hasLifecycle) {
      items.add(komodoPopupMenuDivider());
      if (showStart) {
        items.add(
          komodoPopupMenuItem(
            value: DeploymentAction.start,
            icon: AppIcons.play,
            label: 'Start',
            iconColor: scheme.secondary,
          ),
        );
      }
      if (showStop) {
        items.add(
          komodoPopupMenuItem(
            value: DeploymentAction.stop,
            icon: AppIcons.stop,
            label: 'Stop',
            iconColor: scheme.tertiary,
          ),
        );
      }
      if (showRestart) {
        items.add(
          komodoPopupMenuItem(
            value: DeploymentAction.restart,
            icon: AppIcons.refresh,
            label: 'Restart',
            iconColor: scheme.primary,
          ),
        );
      }
      if (showPause) {
        items.add(
          komodoPopupMenuItem(
            value: DeploymentAction.pause,
            icon: AppIcons.pause,
            label: 'Pause',
            iconColor: scheme.tertiary,
          ),
        );
      }
      if (showUnpause) {
        items.add(
          komodoPopupMenuItem(
            value: DeploymentAction.unpause,
            icon: AppIcons.play,
            label: 'Unpause',
            iconColor: scheme.primary,
          ),
        );
      }
    }

    final showDestroy = state != DeploymentState.notDeployed;
    if (showDestroy) {
      items
        ..add(komodoPopupMenuDivider())
        ..add(
          komodoPopupMenuItem(
            value: DeploymentAction.destroy,
            icon: AppIcons.delete,
            label: 'Destroy',
            destructive: true,
          ),
        );
    }

    return items;
  }

  Future<void> _handleAction(
    BuildContext context,
    String deploymentId,
    DeploymentAction action,
  ) async {
    final actions = ref.read(deploymentActionsProvider.notifier);

    if (action == DeploymentAction.destroy) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: ValueKey('deployment_destroy_dialog_$deploymentId'),
          title: const Text('Destroy deployment?'),
          content: const Text(
            'This will stop and remove the container. Continue?',
          ),
          actions: [
            TextButton(
              key: ValueKey('deployment_destroy_cancel_$deploymentId'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: ValueKey('deployment_destroy_confirm_$deploymentId'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Destroy'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
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
    };

    if (success) {
      ref.invalidate(deploymentDetailProvider(deploymentId));
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
