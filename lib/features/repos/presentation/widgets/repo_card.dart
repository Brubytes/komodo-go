import 'package:flutter/material.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_action_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card_support.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';

/// Card widget displaying repo information.
class RepoCard extends StatelessWidget {
  const RepoCard({
    required this.repo,
    required this.displayTags,
    this.onTap,
    this.onAction,
    super.key,
  });

  final RepoListItem repo;
  final List<String> displayTags;
  final VoidCallback? onTap;
  final void Function(RepoAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final repoPath = repo.info.repo;
    final branch = repo.info.branch;
    final gitProvider = repo.info.gitProvider.trim();
    final onAction = this.onAction;

    return ResourceCard(
      key: ValueKey('repo_card_${repo.id}'),
      menuKey: ValueKey('repo_card_menu_${repo.id}'),
      title: repo.name,
      subtitle: repoPath.isEmpty
          ? 'No repo'
          : (branch.isEmpty ? repoPath : '$repoPath · $branch'),
      status: _status(repo.info.state),
      meta: [
        if (gitProvider.isNotEmpty)
          ResourceIconLabel(icon: AppIcons.repos, label: gitProvider),
      ],
      pills: [
        if (repo.template) const TextPill(label: 'Template'),
        ...resourceTagPills(displayTags),
      ],
      menu: onAction == null
          ? const []
          : [
              DetailActionGroup(
                items: [
                  DetailActionItem(
                    label: 'Pull',
                    icon: AppIcons.refresh,
                    onSelected: () => onAction(RepoAction.pull),
                  ),
                  DetailActionItem(
                    label: 'Clone',
                    icon: AppIcons.download,
                    onSelected: () => onAction(RepoAction.clone),
                  ),
                  DetailActionItem(
                    label: 'Build',
                    icon: AppIcons.builds,
                    onSelected: () => onAction(RepoAction.build),
                  ),
                ],
              ),
            ],
      onTap: onTap,
    );
  }

  ResourceStatusSpec _status(RepoState state) {
    final (tone, icon) = switch (state) {
      RepoState.ok => (PillTone.success, AppIcons.ok),
      RepoState.failed => (PillTone.alert, AppIcons.error),
      RepoState.cloning ||
      RepoState.pulling ||
      RepoState.building => (PillTone.warning, AppIcons.loading),
      RepoState.unknown => (PillTone.neutral, AppIcons.unknown),
    };
    return ResourceStatusSpec(label: state.displayName, icon: icon, tone: tone);
  }
}

/// Actions available for a repo.
enum RepoAction { clone, pull, build }
