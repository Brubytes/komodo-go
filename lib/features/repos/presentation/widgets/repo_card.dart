import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/menus/komodo_popup_menu.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';

/// Card widget displaying repo information.
class RepoCard extends StatelessWidget {
  const RepoCard({required this.repo, this.onTap, this.onAction, super.key});

  final RepoListItem repo;
  final VoidCallback? onTap;
  final void Function(RepoAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final state = repo.info.state;
    final repoPath = repo.info.repo;
    final branch = repo.info.branch;

    final cardRadius = BorderRadius.circular(AppTokens.radiusLg);

    return AppCardSurface(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: cardRadius,
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const Gap(4),
                      Text(
                        repoPath.isNotEmpty
                            ? (branch.isNotEmpty
                                  ? '$repoPath · $branch'
                                  : repoPath)
                            : 'No repo',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onAction != null)
                  PopupMenuButton<RepoAction>(
                    icon: const Icon(AppIcons.moreVertical),
                    onSelected: onAction,
                    itemBuilder: (context) {
                      final scheme = Theme.of(context).colorScheme;
                      return [
                        komodoPopupMenuItem(
                          value: RepoAction.clone,
                          icon: AppIcons.download,
                          label: 'Clone',
                          iconColor: scheme.primary,
                        ),
                        komodoPopupMenuItem(
                          value: RepoAction.pull,
                          icon: AppIcons.refresh,
                          label: 'Pull',
                          iconColor: scheme.secondary,
                        ),
                        komodoPopupMenuItem(
                          value: RepoAction.build,
                          icon: AppIcons.builds,
                          label: 'Build',
                          iconColor: scheme.tertiary,
                        ),
                      ];
                    },
                  ),
              ],
            ),
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
    final scheme = Theme.of(context).colorScheme;
    final (color, icon) = switch (state) {
      RepoState.ok => (scheme.secondary, AppIcons.ok),
      RepoState.failed => (scheme.error, AppIcons.error),
      RepoState.cloning => (scheme.primary, AppIcons.loading),
      RepoState.pulling => (scheme.primary, AppIcons.loading),
      RepoState.building => (scheme.tertiary, AppIcons.loading),
      RepoState.unknown => (scheme.tertiary, AppIcons.unknown),
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
