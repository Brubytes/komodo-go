import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/resources/resource_tag_options_provider.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/features/procedures/presentation/providers/procedures_provider.dart';
import 'package:komodo_go/features/procedures/presentation/widgets/procedure_card.dart';
import 'package:komodo_go/shared/resources/models/resource_batch.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_list_config.dart';

/// View displaying the list of all procedures.
class ProceduresListView extends StatelessWidget {
  const ProceduresListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ResourceListView<ProcedureListItem>(
      config: _proceduresListConfig,
    );
  }
}

final _proceduresListConfig = ResourceListConfig<ProcedureListItem>(
  kind: ResourceKind.procedures,
  title: 'Procedures',
  resourceName: 'procedures',
  icon: AppIcons.procedures,
  markColor: AppTokens.resourceProcedures,
  searchFieldKey: const ValueKey('procedures_search'),
  skeletonTitle: 'Procedure name',
  skeletonSubtitle: 'Owner - Last run - Duration',
  skeletonChipLeft: 'Idle',
  skeletonChipRight: 'Steps 5',
  watchList: (ref) => ref.watch(proceduresProvider),
  watchTagOptions: (ref) => ref.watch(resourceTagOptionsProvider),
  refreshList: (ref) => ref.read(proceduresProvider.notifier).refresh(),
  invalidateList: (ref) => ref.invalidate(proceduresProvider),
  watchActionsState: (ref) => ref.watch(procedureActionsProvider),
  isTemplate: (item) => item.template,
  tagsOf: (item) => item.tags,
  searchFieldsOf: (item) => [
    item.name,
    item.info.state.name,
    item.info.stages.toString(),
  ],
  batchItemOf: (item) => ResourceBatchItem(id: item.id, name: item.name),
  onCreate: (context) => context.push('${AppRoutes.procedures}/new'),
  cardBuilder: (context, ref, item, displayTags) => ProcedureCard(
    procedure: item,
    displayTags: displayTags,
    onTap: () => context.push(
      '${AppRoutes.procedures}/${item.id}?name=${Uri.encodeComponent(item.name)}',
    ),
    onRun: () => _runProcedure(context, ref, item.id),
  ),
);

Future<void> _runProcedure(
  BuildContext context,
  WidgetRef ref,
  String procedureId,
) async {
  final actions = ref.read(procedureActionsProvider.notifier);
  final success = await actions.run(procedureId);

  if (context.mounted) {
    AppSnackBar.show(
      context,
      success ? 'Procedure started' : 'Action failed. Please try again.',
      tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }
}
