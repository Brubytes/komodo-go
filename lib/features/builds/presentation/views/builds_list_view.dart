import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/builds/presentation/providers/builds_provider.dart';
import 'package:komodo_go/features/builds/presentation/widgets/build_card.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_list_config.dart';

/// View displaying the list of all builds.
class BuildsListView extends StatelessWidget {
  const BuildsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ResourceListView<BuildListItem>(config: _buildsListConfig);
  }
}

final _buildsListConfig = ResourceListConfig<BuildListItem>(
  kind: ResourceKind.builds,
  title: 'Builds',
  resourceName: 'builds',
  icon: AppIcons.builds,
  markColor: AppTokens.resourceBuilds,
  searchFieldKey: const ValueKey('builds_search'),
  skeletonTitle: 'Build name',
  skeletonSubtitle: 'Repo • Commit • Builder',
  skeletonChipLeft: 'Queued',
  skeletonChipRight: 'Duration 3m',
  watchList: (ref) => ref.watch(buildsProvider),
  refreshList: (ref) => ref.read(buildsProvider.notifier).refresh(),
  invalidateList: (ref) => ref.invalidate(buildsProvider),
  watchActionsState: (ref) => ref.watch(buildActionsProvider),
  isTemplate: (item) => item.template,
  tagsOf: (item) => item.tags,
  searchFieldsOf: (item) => [item.name],
  cardBuilder: (context, ref, item, displayTags) => BuildCard(
    buildItem: item,
    displayTags: displayTags,
    onTap: () => context.push(
      '${AppRoutes.builds}/${item.id}?name=${Uri.encodeComponent(item.name)}',
    ),
    onAction: (action) => _handleAction(context, ref, item.id, action),
  ),
);

Future<void> _handleAction(
  BuildContext context,
  WidgetRef ref,
  String buildId,
  BuildAction action,
) async {
  final actions = ref.read(buildActionsProvider.notifier);
  final success = await switch (action) {
    BuildAction.run => actions.run(buildId),
    BuildAction.cancel => actions.cancel(buildId),
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
