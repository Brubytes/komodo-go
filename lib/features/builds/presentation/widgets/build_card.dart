import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../data/models/build.dart';

/// Card widget displaying build information.
class BuildCard extends StatelessWidget {
  const BuildCard({
    required this.buildItem,
    this.onTap,
    this.onAction,
    super.key,
  });

  final BuildListItem buildItem;
  final VoidCallback? onTap;
  final void Function(BuildAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final state = buildItem.info.state;
    final repo = buildItem.info.repo;
    final branch = buildItem.info.branch;
    final version = buildItem.info.version.label;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _StatusBadge(state: state),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      buildItem.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      [
                        if (repo.isNotEmpty)
                          branch.isNotEmpty ? '$repo · $branch' : repo,
                        if (version != '0.0.0') 'v$version',
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              if (onAction != null)
                PopupMenuButton<BuildAction>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: onAction,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: BuildAction.run,
                      child: ListTile(
                        leading: Icon(Icons.play_arrow, color: Colors.green),
                        title: Text('Run build'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (state == BuildState.building)
                      const PopupMenuItem(
                        value: BuildAction.cancel,
                        child: ListTile(
                          leading: Icon(Icons.stop, color: Colors.orange),
                          title: Text('Cancel'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});

  final BuildState state;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      BuildState.building => (Colors.blue, Icons.sync),
      BuildState.ok => (Colors.green, Icons.check_circle),
      BuildState.failed => (Colors.red, Icons.error),
      BuildState.unknown => (Colors.orange, Icons.help),
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

/// Actions available for a build.
enum BuildAction { run, cancel }
