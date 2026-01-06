import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../data/models/stack.dart';

/// Card widget displaying stack information.
class StackCard extends StatelessWidget {
  const StackCard({
    required this.stack,
    this.onTap,
    this.onAction,
    super.key,
  });

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
                      icon: const Icon(Icons.more_vert),
                      onSelected: onAction,
                      itemBuilder: (context) => _buildMenuItems(state),
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

  List<PopupMenuEntry<StackAction>> _buildMenuItems(StackState state) {
    return [
      const PopupMenuItem(
        value: StackAction.deploy,
        child: ListTile(
          leading: Icon(Icons.rocket_launch, color: Colors.blue),
          title: Text('Deploy'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      if (!state.isRunning)
        const PopupMenuItem(
          value: StackAction.start,
          child: ListTile(
            leading: Icon(Icons.play_arrow, color: Colors.green),
            title: Text('Start'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (state.isRunning)
        const PopupMenuItem(
          value: StackAction.stop,
          child: ListTile(
            leading: Icon(Icons.stop, color: Colors.orange),
            title: Text('Stop'),
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
      StackState.deploying => (Colors.blue, Icons.sync),
      StackState.running => (Colors.green, Icons.check_circle),
      StackState.paused => (Colors.grey, Icons.pause_circle),
      StackState.stopped => (Colors.orange, Icons.stop_circle),
      StackState.created => (Colors.grey, Icons.circle_outlined),
      StackState.restarting => (Colors.blue, Icons.sync),
      StackState.removing => (Colors.grey, Icons.hourglass_bottom),
      StackState.unhealthy => (Colors.red, Icons.error),
      StackState.down => (Colors.grey, Icons.circle_outlined),
      StackState.dead => (Colors.red, Icons.cancel),
      StackState.unknown => (Colors.orange, Icons.help),
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
enum StackAction { deploy, start, stop }

