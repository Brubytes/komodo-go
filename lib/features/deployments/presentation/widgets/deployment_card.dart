import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../data/models/deployment.dart';

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
    final image = deployment.config.image;

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
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        if (image != null) ...[
                          const Gap(4),
                          Text(
                            image.fullName,
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
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
                      icon: const Icon(Icons.more_vert),
                      onSelected: onAction,
                      itemBuilder: (context) => _buildMenuItems(state),
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
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
    DeploymentState state,
  ) {
    return [
      if (state.isStopped || state == DeploymentState.notDeployed)
        const PopupMenuItem(
          value: DeploymentAction.start,
          child: ListTile(
            leading: Icon(Icons.play_arrow, color: Colors.green),
            title: Text('Start'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (state.isRunning)
        const PopupMenuItem(
          value: DeploymentAction.stop,
          child: ListTile(
            leading: Icon(Icons.stop, color: Colors.orange),
            title: Text('Stop'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (state.isRunning || state.isPaused)
        const PopupMenuItem(
          value: DeploymentAction.restart,
          child: ListTile(
            leading: Icon(Icons.refresh, color: Colors.blue),
            title: Text('Restart'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (state.isRunning)
        const PopupMenuItem(
          value: DeploymentAction.pause,
          child: ListTile(
            leading: Icon(Icons.pause, color: Colors.grey),
            title: Text('Pause'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (state.isPaused)
        const PopupMenuItem(
          value: DeploymentAction.unpause,
          child: ListTile(
            leading: Icon(Icons.play_arrow, color: Colors.blue),
            title: Text('Unpause'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: DeploymentAction.destroy,
        child: ListTile(
          leading: Icon(Icons.delete, color: Colors.red),
          title: Text('Destroy'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    ];
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});

  final DeploymentState state;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      DeploymentState.running => (Colors.green, Icons.check_circle),
      DeploymentState.restarting => (Colors.blue, Icons.sync),
      DeploymentState.exited => (Colors.orange, Icons.stop_circle),
      DeploymentState.paused => (Colors.grey, Icons.pause_circle),
      DeploymentState.notDeployed => (Colors.grey, Icons.circle_outlined),
      DeploymentState.unknown => (Colors.orange, Icons.help),
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
  start,
  stop,
  restart,
  pause,
  unpause,
  destroy,
  deploy,
}
