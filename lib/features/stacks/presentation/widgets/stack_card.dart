import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

import 'package:komodo_go/features/stacks/data/models/stack.dart';

/// Card widget displaying stack information.
class StackCard extends StatelessWidget {
  const StackCard({required this.stack, this.onTap, this.onAction, super.key});

  final StackListItem stack;
  final VoidCallback? onTap;
  final void Function(StackAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final state = stack.info.state;
    final repo = stack.info.repo;
    final branch = stack.info.branch;
    final status = stack.info.status ?? '';

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
                  _StatusBadge(state: state),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stack.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (repo.isNotEmpty) ...[
                          const Gap(4),
                          Text(
                            branch.isNotEmpty ? '$repo · $branch' : repo,
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
                  if (onAction != null)
                    PopupMenuButton<StackAction>(
                      icon: const Icon(AppIcons.moreVertical),
                      onSelected: onAction,
                      itemBuilder: (context) => _buildMenuItems(context, state),
                    ),
                ],
              ),
              if (status.isNotEmpty) ...[
                const Gap(8),
                Text(
                  status,
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

  List<PopupMenuEntry<StackAction>> _buildMenuItems(
    BuildContext context,
    StackState state,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return [
      PopupMenuItem(
        value: StackAction.redeploy,
        child: ListTile(
          leading: Icon(AppIcons.deployments, color: scheme.primary),
          title: const Text('Redeploy'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      PopupMenuItem(
        value: StackAction.pullImages,
        child: ListTile(
          leading: Icon(AppIcons.download, color: scheme.primary),
          title: const Text('Pull images'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      if (state.isRunning)
        PopupMenuItem(
          value: StackAction.restart,
          child: ListTile(
            leading: Icon(AppIcons.refresh, color: scheme.primary),
            title: const Text('Restart'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (state.isRunning)
        PopupMenuItem(
          value: StackAction.pause,
          child: ListTile(
            leading: Icon(AppIcons.pause, color: scheme.tertiary),
            title: const Text('Pause'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      const PopupMenuDivider(),
      if (!state.isRunning)
        PopupMenuItem(
          value: StackAction.start,
          child: ListTile(
            leading: Icon(AppIcons.play, color: scheme.secondary),
            title: const Text('Start'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (state.isRunning)
        PopupMenuItem(
          value: StackAction.stop,
          child: ListTile(
            leading: Icon(AppIcons.stop, color: scheme.tertiary),
            title: const Text('Stop'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      PopupMenuItem(
        value: StackAction.destroy,
        child: ListTile(
          leading: Icon(AppIcons.delete, color: scheme.error),
          title: const Text('Destroy'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    ];
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});

  final StackState state;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      StackState.deploying => (Colors.blue, AppIcons.loading),
      StackState.running => (Colors.green, AppIcons.ok),
      StackState.paused => (Colors.grey, AppIcons.paused),
      StackState.stopped => (Colors.orange, AppIcons.stopped),
      StackState.created => (Colors.grey, AppIcons.pending),
      StackState.restarting => (Colors.blue, AppIcons.loading),
      StackState.removing => (Colors.grey, AppIcons.waiting),
      StackState.unhealthy => (Colors.red, AppIcons.error),
      StackState.down => (Colors.grey, AppIcons.pending),
      StackState.dead => (Colors.red, AppIcons.canceled),
      StackState.unknown => (Colors.orange, AppIcons.unknown),
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

/// Actions available for a stack.
enum StackAction { redeploy, pullImages, restart, pause, start, stop, destroy }
