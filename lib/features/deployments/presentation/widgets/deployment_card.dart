import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';

/// Card widget displaying deployment information.
class DeploymentCard extends StatelessWidget {
  const DeploymentCard({
    required this.deployment,
    this.onTap,
    this.onAction,
    super.key,
  });

  final Deployment deployment;
  final VoidCallback? onTap;
  final void Function(DeploymentAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final state = deployment.info?.state ?? DeploymentState.unknown;
    final image = deployment.info?.image;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status badge
                  _StatusBadge(state: state),
                  const Gap(12),

                  // Deployment info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deployment.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (image != null && image.isNotEmpty) ...[
                          const Gap(4),
                          Text(
                            image,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Quick actions
                  if (onAction != null)
                    PopupMenuButton<DeploymentAction>(
                      icon: const Icon(AppIcons.moreVertical),
                      onSelected: onAction,
                      itemBuilder: (context) => _buildMenuItems(context, state),
                    ),
                ],
              ),

              // Description
              if (deployment.description != null &&
                  deployment.description!.isNotEmpty) ...[
                const Gap(8),
                Text(
                  deployment.description!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<DeploymentAction>> _buildMenuItems(
    BuildContext context,
    DeploymentState state,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final items = <PopupMenuEntry<DeploymentAction>>[];

    final deployLabel =
        (state == DeploymentState.notDeployed ||
            state == DeploymentState.unknown)
        ? 'Deploy'
        : 'Redeploy';

    items.add(
      PopupMenuItem(
        value: DeploymentAction.deploy,
        child: ListTile(
          leading: Icon(AppIcons.deployments, color: scheme.primary),
          title: Text(deployLabel),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );

    final hasImage = deployment.info?.image.isNotEmpty ?? false;
    if (hasImage) {
      items.add(
        PopupMenuItem(
          value: DeploymentAction.pullImages,
          child: ListTile(
            leading: Icon(AppIcons.download, color: scheme.primary),
            title: const Text('Pull image'),
            contentPadding: EdgeInsets.zero,
          ),
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
      items.add(const PopupMenuDivider());
      if (showStart) {
        items.add(
          PopupMenuItem(
            value: DeploymentAction.start,
            child: ListTile(
              leading: Icon(AppIcons.play, color: scheme.secondary),
              title: const Text('Start'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        );
      }
      if (showStop) {
        items.add(
          PopupMenuItem(
            value: DeploymentAction.stop,
            child: ListTile(
              leading: Icon(AppIcons.stop, color: scheme.tertiary),
              title: const Text('Stop'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        );
      }
      if (showRestart) {
        items.add(
          PopupMenuItem(
            value: DeploymentAction.restart,
            child: ListTile(
              leading: Icon(AppIcons.refresh, color: scheme.primary),
              title: const Text('Restart'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        );
      }
      if (showPause) {
        items.add(
          PopupMenuItem(
            value: DeploymentAction.pause,
            child: ListTile(
              leading: Icon(AppIcons.pause, color: scheme.tertiary),
              title: const Text('Pause'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        );
      }
      if (showUnpause) {
        items.add(
          PopupMenuItem(
            value: DeploymentAction.unpause,
            child: ListTile(
              leading: Icon(AppIcons.play, color: scheme.primary),
              title: const Text('Unpause'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        );
      }
    }

    final showDestroy = state != DeploymentState.notDeployed;
    if (showDestroy) {
      items
        ..add(const PopupMenuDivider())
        ..add(
          PopupMenuItem(
            value: DeploymentAction.destroy,
            child: ListTile(
              leading: Icon(AppIcons.delete, color: scheme.error),
              title: const Text('Destroy'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        );
    }

    return items;
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});

  final DeploymentState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, icon) = switch (state) {
      DeploymentState.deploying => (scheme.primary, AppIcons.loading),
      DeploymentState.running => (scheme.secondary, AppIcons.ok),
      DeploymentState.created => (scheme.onSurfaceVariant, AppIcons.pending),
      DeploymentState.restarting => (scheme.primary, AppIcons.loading),
      DeploymentState.removing => (scheme.onSurfaceVariant, AppIcons.waiting),
      DeploymentState.exited => (scheme.tertiary, AppIcons.stopped),
      DeploymentState.dead => (scheme.error, AppIcons.canceled),
      DeploymentState.paused => (scheme.onSurfaceVariant, AppIcons.paused),
      DeploymentState.notDeployed => (
        scheme.onSurfaceVariant,
        AppIcons.pending,
      ),
      DeploymentState.unknown => (scheme.tertiary, AppIcons.unknown),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const Gap(4),
          Text(
            state.displayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Actions available for a deployment.
enum DeploymentAction {
  deploy,
  pullImages,
  restart,
  pause,
  unpause,
  start,
  stop,
  destroy,
}
