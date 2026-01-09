import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:komodo_go/features/deployments/presentation/providers/deployments_provider.dart';
import 'package:komodo_go/features/deployments/presentation/widgets/deployment_card.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';

/// View displaying detailed deployment information.
class DeploymentDetailView extends ConsumerWidget {
  const DeploymentDetailView({
    required this.deploymentId,
    required this.deploymentName,
    super.key,
  });

  final String deploymentId;
  final String deploymentName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deploymentAsync = ref.watch(deploymentDetailProvider(deploymentId));
    final actionsState = ref.watch(deploymentActionsProvider);
    final serversListAsync = ref.watch(serversProvider);

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
      appBar: AppBar(
        title: Text(deploymentName),
        actions: [
          PopupMenuButton<DeploymentAction>(
            icon: const Icon(AppIcons.moreVertical),
            onSelected: (action) =>
                _handleAction(context, ref, deploymentId, action),
            itemBuilder: (context) {
              final state =
                  deploymentAsync.asData?.value?.info?.state ??
                  DeploymentState.unknown;
              return _buildMenuItems(scheme, state);
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
                            _DeploymentHeroPanel(
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
                              child: _DeploymentConfigContent(
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
                      : const _MessageSurface(message: 'Deployment not found'),
                  loading: () => const _LoadingSurface(),
                  error: (error, _) =>
                      _MessageSurface(message: 'Error: $error'),
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

  List<PopupMenuEntry<DeploymentAction>> _buildMenuItems(
    ColorScheme scheme,
    DeploymentState state,
  ) {
    return [
      PopupMenuItem(
        value: DeploymentAction.deploy,
        child: ListTile(
          leading: Icon(AppIcons.deployments, color: scheme.primary),
          title: const Text('Redeploy'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      PopupMenuItem(
        value: DeploymentAction.pullImages,
        child: ListTile(
          leading: Icon(AppIcons.download, color: scheme.primary),
          title: const Text('Pull image'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuDivider(),
      if (state.isStopped || state == DeploymentState.notDeployed)
        PopupMenuItem(
          value: DeploymentAction.start,
          child: ListTile(
            leading: Icon(AppIcons.play, color: scheme.secondary),
            title: const Text('Start'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (state.isRunning)
        PopupMenuItem(
          value: DeploymentAction.stop,
          child: ListTile(
            leading: Icon(AppIcons.stop, color: scheme.tertiary),
            title: const Text('Stop'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (state.isRunning || state.isPaused)
        PopupMenuItem(
          value: DeploymentAction.restart,
          child: ListTile(
            leading: Icon(AppIcons.refresh, color: scheme.primary),
            title: const Text('Restart'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (state.isRunning)
        PopupMenuItem(
          value: DeploymentAction.pause,
          child: ListTile(
            leading: Icon(AppIcons.pause, color: scheme.tertiary),
            title: const Text('Pause'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (state.isPaused)
        PopupMenuItem(
          value: DeploymentAction.unpause,
          child: ListTile(
            leading: Icon(AppIcons.play, color: scheme.primary),
            title: const Text('Unpause'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: DeploymentAction.destroy,
        child: ListTile(
          leading: Icon(AppIcons.delete, color: scheme.error),
          title: const Text('Destroy'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    ];
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Action completed successfully'
                : 'Action failed. Please try again.',
          ),
          backgroundColor: success
              ? Theme.of(context).colorScheme.secondaryContainer
              : Theme.of(context).colorScheme.errorContainer,
        ),
      );
    }
  }
}

class _DeploymentHeroPanel extends StatelessWidget {
  const _DeploymentHeroPanel({
    required this.deployment,
    required this.serverName,
  });

  final Deployment deployment;
  final String? serverName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = deployment.info?.state ?? DeploymentState.unknown;
    final status = deployment.info?.status;
    final updateAvailable = deployment.info?.updateAvailable ?? false;
    final image = deployment.imageLabel;
    final serverId =
        deployment.config?.serverId ?? deployment.info?.serverId ?? '';

    return DetailHeroPanel(
      tintColor: scheme.primary,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (deployment.description?.trim().isNotEmpty ?? false) ...[
            DetailIconInfoRow(
              icon: AppIcons.tag,
              label: 'Description',
              value: deployment.description!.trim(),
            ),
            const Gap(10),
          ],
          if (image.isNotEmpty) ...[
            DetailIconInfoRow(
              icon: AppIcons.deployments,
              label: 'Image',
              value: image,
            ),
            const Gap(10),
          ],
          if (serverId.isNotEmpty)
            DetailIconInfoRow(
              icon: AppIcons.server,
              label: 'Server',
              value: serverName ?? serverId,
            ),
        ],
      ),
      metrics: [
        DetailMetricTileData(
          icon: _stateIcon(state),
          label: 'State',
          value: state.displayName,
          tone: _stateTone(state),
        ),
        if (status?.trim().isNotEmpty ?? false)
          DetailMetricTileData(
            icon: AppIcons.activity,
            label: 'Status',
            value: status!.trim(),
            tone: DetailMetricTone.neutral,
          ),
        DetailMetricTileData(
          icon: updateAvailable ? AppIcons.updateAvailable : AppIcons.ok,
          label: 'Updates',
          value: updateAvailable ? 'Available' : 'Up to date',
          tone: updateAvailable
              ? DetailMetricTone.tertiary
              : DetailMetricTone.success,
        ),
      ],
      footer: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final tag in deployment.tags) TextPill(label: tag)],
      ),
    );
  }

  IconData _stateIcon(DeploymentState state) {
    return switch (state) {
      DeploymentState.running => AppIcons.ok,
      DeploymentState.deploying ||
      DeploymentState.restarting => AppIcons.loading,
      DeploymentState.paused => AppIcons.paused,
      DeploymentState.exited || DeploymentState.created => AppIcons.stopped,
      DeploymentState.dead || DeploymentState.removing => AppIcons.error,
      DeploymentState.notDeployed => AppIcons.pending,
      _ => AppIcons.unknown,
    };
  }

  DetailMetricTone _stateTone(DeploymentState state) {
    return switch (state) {
      DeploymentState.running => DetailMetricTone.success,
      DeploymentState.deploying ||
      DeploymentState.restarting => DetailMetricTone.primary,
      DeploymentState.paused => DetailMetricTone.secondary,
      DeploymentState.exited ||
      DeploymentState.created => DetailMetricTone.neutral,
      DeploymentState.dead => DetailMetricTone.alert,
      _ => DetailMetricTone.neutral,
    };
  }
}

class _DeploymentConfigContent extends StatelessWidget {
  const _DeploymentConfigContent({
    required this.deployment,
    required this.serverName,
  });

  final Deployment deployment;
  final String? serverName;

  @override
  Widget build(BuildContext context) {
    final config = deployment.config;
    if (config == null) {
      return const Text('Configuration not available');
    }

    final serverId = config.serverId;
    final ports = config.ports.trim();
    final volumes = config.volumes.trim();
    final environment = config.environment.trim();
    final labels = config.labels.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill.onOff(
              isOn: config.autoUpdate,
              onLabel: 'Auto update',
              offLabel: 'Manual update',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.pause,
            ),
            StatusPill.onOff(
              isOn: config.pollForUpdates,
              onLabel: 'Polling on',
              offLabel: 'Polling off',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.pause,
            ),
            StatusPill.onOff(
              isOn: config.sendAlerts,
              onLabel: 'Alerts on',
              offLabel: 'Alerts off',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.notifications,
            ),
            StatusPill.onOff(
              isOn: config.redeployOnBuild,
              onLabel: 'Redeploy on build',
              offLabel: 'Manual redeploy',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.pause,
            ),
          ],
        ),
        const Gap(14),
        DetailSubCard(
          title: 'Image',
          icon: AppIcons.deployments,
          child: Column(
            children: [
              DetailKeyValueRow(
                label: 'Image',
                value: deployment.imageLabel.isNotEmpty
                    ? deployment.imageLabel
                    : '—',
              ),
              DetailKeyValueRow(
                label: 'Registry',
                value: config.imageRegistryAccount.isNotEmpty
                    ? config.imageRegistryAccount
                    : '—',
                bottomPadding: 0,
              ),
            ],
          ),
        ),
        if (serverId.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Server',
            icon: AppIcons.server,
            child: DetailKeyValueRow(
              label: 'Server',
              value: serverName ?? serverId,
              bottomPadding: 0,
            ),
          ),
        ],
        if (config.network.isNotEmpty ||
            config.restart != null ||
            config.terminationTimeout > 0) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Container',
            icon: AppIcons.settings,
            child: Column(
              children: [
                if (config.network.isNotEmpty)
                  DetailKeyValueRow(label: 'Network', value: config.network),
                if (config.restart != null)
                  DetailKeyValueRow(
                    label: 'Restart',
                    value: config.restart.toString(),
                  ),
                if (config.terminationTimeout > 0)
                  DetailKeyValueRow(
                    label: 'Term timeout',
                    value: '${config.terminationTimeout}s',
                    bottomPadding: 0,
                  ),
              ],
            ),
          ),
        ],
        if (config.command.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Command',
            icon: AppIcons.activity,
            child: DetailKeyValueRow(
              label: 'Command',
              value: config.command,
              bottomPadding: 0,
            ),
          ),
        ],
        if (ports.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Ports',
            icon: AppIcons.settings,
            child: DetailCodeBlock(code: ports),
          ),
        ],
        if (volumes.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Volumes',
            icon: AppIcons.package,
            child: DetailCodeBlock(code: volumes),
          ),
        ],
        if (environment.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Environment',
            icon: AppIcons.settings,
            child: DetailCodeBlock(code: environment),
          ),
        ],
        if (labels.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Labels',
            icon: AppIcons.tag,
            child: DetailCodeBlock(code: labels),
          ),
        ],
        if (config.links.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Links',
            icon: AppIcons.network,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final link in config.links) TextPill(label: link),
              ],
            ),
          ),
        ],
        if (config.extraArgs.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Extra Args',
            icon: AppIcons.settings,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final arg in config.extraArgs) TextPill(label: arg),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _LoadingSurface extends StatelessWidget {
  const _LoadingSurface();

  @override
  Widget build(BuildContext context) {
    return const DetailSurface(
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _MessageSurface extends StatelessWidget {
  const _MessageSurface({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DetailSurface(child: Text(message));
  }
}
