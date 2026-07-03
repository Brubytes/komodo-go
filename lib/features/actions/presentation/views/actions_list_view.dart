import 'package:flutter/material.dart' hide Actions;
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/resources/resource_tag_options_provider.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/actions/presentation/providers/actions_provider.dart';
import 'package:komodo_go/features/actions/presentation/widgets/action_card.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_list_config.dart';

/// View displaying the list of all actions.
class ActionsListView extends StatelessWidget {
  const ActionsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ResourceListView<ActionListItem>(config: _actionsListConfig);
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
  cardBuilder: (context, ref, item, displayTags) => ActionCard(
    action: item,
    displayTags: displayTags,
    onTap: () => context.push(
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
