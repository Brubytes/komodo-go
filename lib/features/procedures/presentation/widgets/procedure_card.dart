import 'package:flutter/material.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_action_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card_support.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';

/// Card widget displaying procedure information.
class ProcedureCard extends StatelessWidget {
  const ProcedureCard({
    required this.procedure,
    required this.displayTags,
    this.onTap,
    this.onRun,
    super.key,
  });

  final ProcedureListItem procedure;
  final List<String> displayTags;
  final VoidCallback? onTap;
  final VoidCallback? onRun;

  @override
  Widget build(BuildContext context) {
    final stages = procedure.info.stages;
    final scheduleError = procedure.info.scheduleError ?? '';
    final onRun = this.onRun;
    final scheme = Theme.of(context).colorScheme;

    return ResourceCard(
      key: ValueKey('procedure_card_${procedure.id}'),
      menuKey: ValueKey('procedure_card_menu_${procedure.id}'),
      title: procedure.name,
      subtitle: '$stages stages',
      status: _status(procedure.info.state),
      pills: [
        if (procedure.template) const TextPill(label: 'Template'),
        ...resourceTagPills(displayTags),
      ],
      bottom: scheduleError.isEmpty
          ? null
          : Text(
              scheduleError,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
      menuBuilder: onRun == null
          ? null
          : () => [
              DetailActionGroup(
                items: [
                  DetailActionItem(
                    label: 'Run',
                    icon: AppIcons.play,
                    onSelected: onRun,
                  ),
                ],
              ),
            ],
      onTap: onTap,
    );
  }

  ResourceStatusSpec _status(ProcedureState state) {
    final (tone, icon) = switch (state) {
      ProcedureState.ok => (PillTone.success, AppIcons.ok),
      ProcedureState.failed => (PillTone.alert, AppIcons.error),
      ProcedureState.running => (PillTone.warning, AppIcons.loading),
      ProcedureState.unknown => (PillTone.neutral, AppIcons.unknown),
    };
    return ResourceStatusSpec(label: state.displayName, icon: icon, tone: tone);
  }
}
