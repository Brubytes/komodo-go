import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/menus/komodo_popup_menu.dart';
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

class _DeploymentDetailViewState extends ConsumerState<DeploymentDetailView>
  with DetailDirtySnackBarMixin<DeploymentDetailView> {
  final _configEditorKey = GlobalKey<DeploymentConfigEditorContentState>();
  var _configSaveInFlight = false;

  @override
  Widget build(BuildContext context) {
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
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(deploymentDetailProvider(deploymentId));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                deploymentAsync.when(
                  data: (deployment) => deployment != null
                      ? Column(
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
                            const Gap(16),
                            DetailSection(
                              title: 'Config',
                              icon: AppIcons.settings,
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
                                          onSave: () =>
                                              _saveConfig(deployment: deployment),
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
                            ),
                          ],
                        )
                      : const DeploymentMessageSurface(
                          message: 'Deployment not found',
                        ),
                  loading: () => const DeploymentLoadingSurface(),
                  error: (error, _) =>
                      DeploymentMessageSurface(message: 'Error: $error'),
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
          title: const Text('Destroy deployment?'),
          content: const Text(
            'This will stop and remove the container. Continue?',
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
