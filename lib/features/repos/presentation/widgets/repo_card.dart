import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

import '../../data/models/repo.dart';

/// Card widget displaying repo information.
class RepoCard extends StatelessWidget {
  const RepoCard({
    required this.repo,
    this.onTap,
    this.onAction,
    super.key,
  });

  final RepoListItem repo;
  final VoidCallback? onTap;
  final void Function(RepoAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final state = repo.info.state;
    final repoPath = repo.info.repo;
    final branch = repo.info.branch;

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
                      repo.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      repoPath.isNotEmpty
                          ? (branch.isNotEmpty ? '$repoPath · $branch' : repoPath)
                          : 'No repo',
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
                PopupMenuButton<RepoAction>(
                  icon: const Icon(AppIcons.moreVertical),
                  onSelected: onAction,
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: RepoAction.clone,
                      child: ListTile(
                        leading: Icon(AppIcons.download, color: Colors.blue),
                        title: Text('Clone'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: RepoAction.pull,
                      child: ListTile(
                        leading: Icon(AppIcons.refresh, color: Colors.green),
                        title: Text('Pull'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: RepoAction.build,
                      child: ListTile(
                        leading: Icon(AppIcons.builds, color: Colors.orange),
                        title: Text('Build'),
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

  final RepoState state;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      RepoState.ok => (Colors.green, AppIcons.ok),
      RepoState.failed => (Colors.red, AppIcons.error),
      RepoState.cloning => (Colors.blue, AppIcons.loading),
      RepoState.pulling => (Colors.blue, AppIcons.loading),
      RepoState.building => (Colors.orange, AppIcons.loading),
      RepoState.unknown => (Colors.orange, AppIcons.unknown),
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

/// Actions available for a repo.
enum RepoAction { clone, pull, build }
