import 'package:flutter/material.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_action_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card_support.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';

/// Card widget displaying build information.
class BuildCard extends StatelessWidget {
  const BuildCard({
    required this.buildItem,
    required this.displayTags,
    this.onTap,
    this.onAction,
    super.key,
  });

  final BuildListItem buildItem;
  final List<String> displayTags;
  final VoidCallback? onTap;
  final void Function(BuildAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final state = buildItem.info.state;
    final repo = buildItem.info.linkedRepo.isNotEmpty
        ? buildItem.info.linkedRepo
        : buildItem.info.repo;
    final branch = buildItem.info.branch;
    final version = buildItem.info.version.label;
    final onAction = this.onAction;

    return ResourceCard(
      key: ValueKey('build_card_${buildItem.id}'),
      menuKey: ValueKey('build_card_menu_${buildItem.id}'),
      title: buildItem.name,
      subtitle: repo.isEmpty
          ? null
          : (branch.isEmpty ? repo : '$repo · $branch'),
      status: _status(state),
      meta: [
        if (version != '0.0.0')
          ResourceIconLabel(icon: AppIcons.package, label: 'v$version'),
      ],
      pills: [
        if (buildItem.template) const TextPill(label: 'Template'),
        ...resourceTagPills(displayTags),
      ],
      menu: onAction == null
          ? const []
          : [
              DetailActionGroup(
                items: [
                  DetailActionItem(
                    label: 'Run build',
                    icon: AppIcons.play,
                    onSelected: () => onAction(BuildAction.run),
                  ),
                  if (state == BuildState.building)
                    DetailActionItem(
                      label: 'Cancel build',
                      icon: AppIcons.stop,
                      destructive: true,
                      onSelected: () => onAction(BuildAction.cancel),
                    ),
                ],
              ),
            ],
      onTap: onTap,
    );
  }

  ResourceStatusSpec _status(BuildState state) {
    final (tone, icon) = switch (state) {
      BuildState.building => (PillTone.warning, AppIcons.loading),
      BuildState.ok => (PillTone.success, AppIcons.ok),
      BuildState.failed => (PillTone.alert, AppIcons.error),
      BuildState.unknown => (PillTone.neutral, AppIcons.unknown),
    };
    return ResourceStatusSpec(label: state.displayName, icon: icon, tone: tone);
  }
}

/// Actions available for a build.
enum BuildAction { run, cancel }
