import 'package:flutter/material.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_action_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card_support.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';

/// Card widget displaying sync information.
class SyncCard extends StatelessWidget {
  const SyncCard({
    required this.sync,
    required this.displayTags,
    this.onTap,
    this.onRun,
    super.key,
  });

  final ResourceSyncListItem sync;
  final List<String> displayTags;
  final VoidCallback? onTap;
  final VoidCallback? onRun;

  @override
  Widget build(BuildContext context) {
    final branch = sync.info.branch;
    final linkedRepo = sync.info.linkedRepo;
    final repoLabel = linkedRepo.isNotEmpty ? linkedRepo : sync.info.repo;
    final resourcePath = sync.info.resourcePath.join('/');
    final onRun = this.onRun;

    return ResourceCard(
      key: ValueKey('sync_card_${sync.id}'),
      menuKey: ValueKey('sync_card_menu_${sync.id}'),
      title: sync.name,
      subtitle: repoLabel.isEmpty
          ? 'No repo'
          : (branch.isEmpty ? repoLabel : '$repoLabel · $branch'),
      status: _status(sync.info.state),
      meta: [
        if (resourcePath.isNotEmpty)
          ResourceIconLabel(icon: AppIcons.package, label: resourcePath),
      ],
      pills: [
        if (sync.template) const TextPill(label: 'Template'),
        ...resourceTagPills(displayTags),
      ],
      menu: onRun == null
          ? const []
          : [
              DetailActionGroup(
                items: [
                  DetailActionItem(
                    label: 'Run sync',
                    icon: AppIcons.play,
                    onSelected: onRun,
                  ),
                ],
              ),
            ],
      onTap: onTap,
    );
  }

  ResourceStatusSpec _status(ResourceSyncState state) {
    final (tone, icon) = switch (state) {
      ResourceSyncState.ok => (PillTone.success, AppIcons.ok),
      ResourceSyncState.failed => (PillTone.alert, AppIcons.error),
      ResourceSyncState.syncing => (PillTone.warning, AppIcons.loading),
      ResourceSyncState.pending => (PillTone.warning, AppIcons.pending),
      ResourceSyncState.unknown => (PillTone.neutral, AppIcons.unknown),
    };
    return ResourceStatusSpec(label: state.displayName, icon: icon, tone: tone);
  }
}
