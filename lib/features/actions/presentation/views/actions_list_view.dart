import 'package:flutter/material.dart' hide Actions;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/resources/resource_tag_options_provider.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/layout/list_detail_layout.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/actions/presentation/providers/actions_provider.dart';
import 'package:komodo_go/features/actions/presentation/widgets/action_card.dart';
import 'package:komodo_go/shared/resources/models/resource_batch.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_list_config.dart';
import 'package:komodo_go/shared/resources/resource_sorting.dart';

/// View displaying the list of all actions.
class ActionsListView extends StatelessWidget {
  const ActionsListView({this.selectedId, super.key});

  /// Id of the item open in the detail pane, highlighted in the list.
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return ResourceListView<ActionListItem>(
      config: _actionsListConfig,
      selectedId: selectedId,
    );
  }
}

final _actionsListConfig = ResourceListConfig<ActionListItem>(
  kind: ResourceKind.actions,
  title: 'Actions',
  resourceName: 'actions',
  icon: AppIcons.actions,
  markColor: AppTokens.resourceActions,
  searchFieldKey: const ValueKey('actions_search'),
  skeletonTitle: 'Action name',
  skeletonSubtitle: 'Owner - Trigger - Resource',
  skeletonChipLeft: 'Idle',
  skeletonChipRight: 'Last run 1h',
  watchList: (ref) => ref.watch(actionsProvider),
  watchTagOptions: (ref) => ref.watch(resourceTagOptionsProvider),
  refreshList: (ref) => ref.read(actionsProvider.notifier).refresh(),
  invalidateList: (ref) => ref.invalidate(actionsProvider),
  watchActionsState: (ref) => ref.watch(actionActionsProvider),
  isTemplate: (item) => item.template,
  tagsOf: (item) => item.tags,
  searchFieldsOf: (item) => [
    item.name,
    item.info.state.name,
  ],
  batchItemOf: (item) => ResourceBatchItem(id: item.id, name: item.name),
  onCreate: (context) => context.openDetail('${AppRoutes.actions}/new'),
  nameOf: (item) => item.name,
  idOf: (item) => item.id,
  severityOf: _severityOf,
  stateLabelOf: (item) => resourceStateLabel(item.info.state),
  updatedAtOf: (item) => item.info.lastRunAt ?? 0,
  cardBuilder: (context, ref, item, displayTags) => ActionCard(
    action: item,
    displayTags: displayTags,
    onTap: () => context.openDetail(
      '${AppRoutes.actions}/${item.id}?name=${Uri.encodeComponent(item.name)}',
    ),
    onRun: () => _runAction(context, ref, item.id),
  ),
);

Future<void> _runAction(
  BuildContext context,
  WidgetRef ref,
  String actionId,
) async {
  final actions = ref.read(actionActionsProvider.notifier);
  final success = await actions.run(actionId);

  if (context.mounted) {
    AppSnackBar.show(
      context,
      success ? 'Action started' : 'Action failed. Please try again.',
      tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }
}

int _severityOf(ActionListItem item) => switch (item.info.state) {
  ActionState.failed => ResourceSeverity.attention,
  ActionState.running => ResourceSeverity.warning,
  ActionState.ok => ResourceSeverity.healthy,
  ActionState.unknown => ResourceSeverity.inactive,
};
