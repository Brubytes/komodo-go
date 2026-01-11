import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

import 'package:komodo_go/features/syncs/data/models/sync.dart';

/// Card widget displaying sync information.
class SyncCard extends StatelessWidget {
  const SyncCard({required this.sync, this.onTap, this.onRun, super.key});

  final ResourceSyncListItem sync;
  final VoidCallback? onTap;
  final VoidCallback? onRun;

  @override
  Widget build(BuildContext context) {
    final state = sync.info.state;
    final repo = sync.info.repo;
    final branch = sync.info.branch;
    final subtitleParts = <String>[
      if (repo.isNotEmpty) branch.isNotEmpty ? '$repo · $branch' : repo,
      if (sync.info.resourcePath.isNotEmpty)
        'path: ${sync.info.resourcePath.join('/')}',
    ];

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
                      sync.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      subtitleParts.isEmpty
                          ? 'No repo'
                          : subtitleParts.join(' · '),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              if (onRun != null)
                IconButton(
                  icon: const Icon(AppIcons.play),
                  onPressed: onRun,
                  tooltip: 'Run',
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

  final ResourceSyncState state;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      ResourceSyncState.syncing => (Colors.blue, AppIcons.loading),
      ResourceSyncState.pending => (Colors.orange, AppIcons.pending),
      ResourceSyncState.ok => (Colors.green, AppIcons.ok),
      ResourceSyncState.failed => (Colors.red, AppIcons.error),
      ResourceSyncState.unknown => (Colors.orange, AppIcons.unknown),
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
