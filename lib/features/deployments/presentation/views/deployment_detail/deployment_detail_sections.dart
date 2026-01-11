import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';

class DeploymentHeroPanel extends StatelessWidget {
  const DeploymentHeroPanel({required this.deployment, required this.serverName, super.key,
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
      footer: DetailPillList(
        items: deployment.tags,
        emptyLabel: 'No tags',
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

class DeploymentConfigContent extends StatelessWidget {
  const DeploymentConfigContent({required this.deployment, required this.serverName, super.key,
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
            child: DetailPillList(
              items: config.links,
              emptyLabel: 'No links',
            ),
          ),
        ],
        if (config.extraArgs.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Extra Args',
            icon: AppIcons.settings,
            child: DetailPillList(
              items: config.extraArgs,
              emptyLabel: 'No args',
            ),
          ),
        ],
      ],
    );
  }
}

class DeploymentLoadingSurface extends StatelessWidget {
  const DeploymentLoadingSurface({super.key});

  @override
  Widget build(BuildContext context) {
    return const DetailSurface(
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class DeploymentMessageSurface extends StatelessWidget {
  const DeploymentMessageSurface({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DetailSurface(child: Text(message));
  }
}
