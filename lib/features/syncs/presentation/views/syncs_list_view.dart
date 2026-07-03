import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';
import 'package:komodo_go/features/syncs/presentation/providers/syncs_provider.dart';
import 'package:komodo_go/features/syncs/presentation/widgets/sync_card.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_list_config.dart';

/// View displaying the list of all syncs.
class SyncsListView extends StatelessWidget {
  const SyncsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ResourceListView<ResourceSyncListItem>(config: _syncsListConfig);
  }
}

final _syncsListConfig = ResourceListConfig<ResourceSyncListItem>(
  kind: ResourceKind.syncs,
  title: 'Syncs',
  resourceName: 'syncs',
  icon: AppIcons.syncs,
  markColor: AppTokens.resourceSyncs,
  searchFieldKey: const ValueKey('syncs_search'),
  skeletonTitle: 'Sync name',
  skeletonSubtitle: 'Repo - Server - Schedule',
  skeletonChipLeft: 'Idle',
  skeletonChipRight: 'Last run 2m',
  watchList: (ref) => ref.watch(syncsProvider),
  refreshList: (ref) => ref.read(syncsProvider.notifier).refresh(),
  invalidateList: (ref) => ref.invalidate(syncsProvider),
  watchActionsState: (ref) => ref.watch(syncActionsProvider),
  isTemplate: (item) => item.template,
  tagsOf: (item) => item.tags,
  searchFieldsOf: (item) => [
    item.name,
    item.info.repo,
    item.info.branch,
    item.info.linkedRepo,
    item.info.gitProvider,
    item.info.resourcePath.join(' '),
    item.info.state.name,
  ],
  cardBuilder: (context, ref, item, displayTags) => SyncCard(
    sync: item,
    displayTags: displayTags,
    onTap: () => context.push(
      '${AppRoutes.syncs}/${item.id}?name=${Uri.encodeComponent(item.name)}',
    ),
    onRun: () => _runSync(context, ref, item.id),
  ),
);

Future<void> _runSync(
  BuildContext context,
  WidgetRef ref,
  String syncId,
) async {
  final actions = ref.read(syncActionsProvider.notifier);
  final success = await actions.run(syncId);

  if (context.mounted) {
    AppSnackBar.show(
      context,
      success ? 'Sync started' : 'Action failed. Please try again.',
      tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }
}
