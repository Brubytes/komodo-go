import 'package:flutter/material.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_action_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card_support.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';

/// Card widget displaying deployment information.
class DeploymentCard extends StatelessWidget {
  const DeploymentCard({
    required this.deployment,
    required this.displayTags,
    this.serverName,
    this.onTap,
    this.onAction,
    super.key,
  });

  final Deployment deployment;
  final List<String> displayTags;
  final String? serverName;
  final VoidCallback? onTap;
  final void Function(DeploymentAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final state = deployment.info?.state ?? DeploymentState.unknown;
    final serverLabel =
        (serverName ??
                deployment.info?.serverId ??
                deployment.config?.serverId ??
                '')
            .trim();
    final onAction = this.onAction;

    return ResourceCard(
      key: ValueKey('deployment_card_${deployment.id}'),
      menuKey: ValueKey('deployment_card_menu_${deployment.id}'),
      title: deployment.name,
      subtitle: stripHashes(deployment.imageLabel),
      status: deploymentStatusSpec(
        state,
        updateAvailable: deployment.info?.updateAvailable ?? false,
      ),
      meta: [
        if (serverLabel.isNotEmpty)
          ResourceIconLabel(icon: AppIcons.server, label: serverLabel),
      ],
      pills: [
        if (deployment.template) const TextPill(label: 'Template'),
        ...resourceTagPills(displayTags),
      ],
      menu: onAction == null
          ? const []
          : deploymentMenuGroups(
              state,
              onAction,
              hasImage: deployment.info?.image.isNotEmpty ?? false,
            ),
      onTap: onTap,
    );
  }
}

/// Status pill/accent for a deployment. A running deployment with a newer
/// image available surfaces the update as the (warning) status.
ResourceStatusSpec deploymentStatusSpec(
  DeploymentState state, {
  bool updateAvailable = false,
}) {
  if (state == DeploymentState.running && updateAvailable) {
    return const ResourceStatusSpec(
      label: 'Update available',
      icon: AppIcons.updateAvailable,
      tone: PillTone.warning,
    );
  }
  final (tone, icon) = switch (state) {
    DeploymentState.running => (PillTone.success, AppIcons.ok),
    DeploymentState.deploying => (PillTone.warning, AppIcons.loading),
    DeploymentState.restarting => (PillTone.warning, AppIcons.loading),
    DeploymentState.removing => (PillTone.warning, AppIcons.waiting),
    DeploymentState.dead => (PillTone.alert, AppIcons.canceled),
    DeploymentState.created => (PillTone.neutral, AppIcons.pending),
    DeploymentState.exited => (PillTone.neutral, AppIcons.stopped),
    DeploymentState.paused => (PillTone.neutral, AppIcons.paused),
    DeploymentState.notDeployed => (PillTone.neutral, AppIcons.pending),
    DeploymentState.unknown => (PillTone.neutral, AppIcons.unknown),
  };
  return ResourceStatusSpec(label: state.displayName, icon: icon, tone: tone);
}

/// Menu groups (Lifecycle, Maintenance, Danger) valid for [state].
List<DetailActionGroup> deploymentMenuGroups(
  DeploymentState state,
  void Function(DeploymentAction action) onAction, {
  bool hasImage = true,
}) {
  VoidCallback call(DeploymentAction a) =>
      () => onAction(a);

  final notDeployed =
      state == DeploymentState.notDeployed || state == DeploymentState.unknown;

  return resourceMenuGroups(
    lifecycle: [
      if (state == DeploymentState.created || state == DeploymentState.exited)
        ResourceMenuItems.start(call(DeploymentAction.start)),
      if (state.isRunning || state.isPaused)
        ResourceMenuItems.restart(call(DeploymentAction.restart)),
      if (state.isRunning)
        ResourceMenuItems.pause(call(DeploymentAction.pause)),
      if (state.isPaused)
        ResourceMenuItems.unpause(call(DeploymentAction.unpause)),
      if (state.isRunning) ResourceMenuItems.stop(call(DeploymentAction.stop)),
    ],
    maintenance: [
      if (hasImage)
        ResourceMenuItems.pullImages(call(DeploymentAction.pullImages)),
      ResourceMenuItems.checkUpdates(call(DeploymentAction.checkUpdates)),
      ResourceMenuItems.redeploy(
        call(DeploymentAction.deploy),
        label: notDeployed ? 'Deploy' : 'Redeploy',
      ),
    ],
    danger: [
      if (state != DeploymentState.notDeployed)
        ResourceMenuItems.destroy(call(DeploymentAction.destroy)),
    ],
  );
}

/// Actions available for a deployment.
enum DeploymentAction {
  checkUpdates,
  deploy,
  pullImages,
  restart,
  pause,
  unpause,
  start,
  stop,
  destroy,
}
