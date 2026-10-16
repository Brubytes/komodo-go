import 'package:flutter/material.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_action_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card_support.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';

/// Card widget displaying action information.
class ActionCard extends StatelessWidget {
  const ActionCard({
    required this.action,
    required this.displayTags,
    this.onTap,
    this.onRun,
    super.key,
  });

  final ActionListItem action;
  final List<String> displayTags;
  final VoidCallback? onTap;
  final VoidCallback? onRun;

  @override
  Widget build(BuildContext context) {
    final scheduleError = action.info.scheduleError ?? '';
    final hasSchedule = action.info.nextScheduledRun != null;
    final onRun = this.onRun;
    final scheme = Theme.of(context).colorScheme;

    return ResourceCard(
      key: ValueKey('action_card_${action.id}'),
      menuKey: ValueKey('action_card_menu_${action.id}'),
      title: action.name,
      subtitle: hasSchedule ? 'Scheduled' : 'No schedule',
      status: _status(action.info.state),
      pills: [
        if (action.template) const TextPill(label: 'Template'),
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

  ResourceStatusSpec _status(ActionState state) {
    final (tone, icon) = switch (state) {
      ActionState.ok => (PillTone.success, AppIcons.ok),
      ActionState.failed => (PillTone.alert, AppIcons.error),
      ActionState.running => (PillTone.warning, AppIcons.loading),
      ActionState.unknown => (PillTone.neutral, AppIcons.unknown),
    };
    return ResourceStatusSpec(label: state.displayName, icon: icon, tone: tone);
  }
}
