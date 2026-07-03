import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/repos/presentation/widgets/repo_card.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_list_config.dart';

/// View displaying the list of all repos.
class ReposListView extends StatelessWidget {
  const ReposListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ResourceListView<RepoListItem>(config: _reposListConfig);
  }
}

final _reposListConfig = ResourceListConfig<RepoListItem>(
  kind: ResourceKind.repos,
  title: 'Repos',
  resourceName: 'repos',
  icon: AppIcons.repos,
  markColor: AppTokens.resourceRepos,
  searchFieldKey: const ValueKey('repos_search'),
  skeletonTitle: 'Repo name',
  skeletonSubtitle: 'Provider - Branch - Server',
  skeletonChipLeft: 'Synced',
  skeletonChipRight: 'Builds 12',
  watchList: (ref) => ref.watch(reposProvider),
  refreshList: (ref) => ref.read(reposProvider.notifier).refresh(),
  invalidateList: (ref) => ref.invalidate(reposProvider),
  watchActionsState: (ref) => ref.watch(repoActionsProvider),
  isTemplate: (item) => item.template,
  tagsOf: (item) => item.tags,
  searchFieldsOf: (item) => [
    item.name,
    item.info.repo,
    item.info.branch,
    item.info.gitProvider,
    item.info.repoLink,
    item.info.state.displayName,
  ],
  cardBuilder: (context, ref, item, displayTags) => RepoCard(
    repo: item,
    displayTags: displayTags,
    onTap: () => context.push(
      '${AppRoutes.repos}/${item.id}?name=${Uri.encodeComponent(item.name)}',
    ),
    onAction: (action) => _handleAction(context, ref, item.id, action),
  ),
);

Future<void> _handleAction(
  BuildContext context,
  WidgetRef ref,
  String repoId,
  RepoAction action,
) async {
  final actions = ref.read(repoActionsProvider.notifier);
  final success = await switch (action) {
    RepoAction.clone => actions.clone(repoId),
    RepoAction.pull => actions.pull(repoId),
    RepoAction.build => actions.buildRepo(repoId),
  };

  if (context.mounted) {
    AppSnackBar.show(
      context,
      success
          ? 'Action completed successfully'
          : 'Action failed. Please try again.',
      tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }
}
