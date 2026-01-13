import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/menus/komodo_popup_menu.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';

import 'package:komodo_go/features/builds/data/models/build.dart';

/// Card widget displaying build information.
class BuildCard extends StatelessWidget {
  const BuildCard({
    required this.buildItem,
    this.onTap,
    this.onAction,
    super.key,
  });

  final BuildListItem buildItem;
  final VoidCallback? onTap;
  final void Function(BuildAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final state = buildItem.info.state;
    final repo = buildItem.info.repo;
    final branch = buildItem.info.branch;
    final version = buildItem.info.version.label;

    final cardRadius = BorderRadius.circular(AppTokens.radiusLg);

    return AppCardSurface(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: cardRadius,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _StatusBadge(state: state),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        buildItem.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const Gap(4),
                      Text(
                        [
                          if (repo.isNotEmpty)
                            branch.isNotEmpty ? '$repo · $branch' : repo,
                          if (version != '0.0.0') 'v$version',
                        ].where((s) => s.isNotEmpty).join(' · '),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onAction != null)
                  PopupMenuButton<BuildAction>(
                    icon: const Icon(AppIcons.moreVertical),
                    onSelected: onAction,
                    itemBuilder: (context) {
                      final scheme = Theme.of(context).colorScheme;
                      return [
                        komodoPopupMenuItem(
                          value: BuildAction.run,
                          icon: AppIcons.play,
                          label: 'Run build',
                          iconColor: scheme.secondary,
                        ),
                        if (state == BuildState.building)
                          komodoPopupMenuItem(
                            value: BuildAction.cancel,
                            icon: AppIcons.stop,
                            label: 'Cancel',
                            destructive: true,
                          ),
                      ];
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});

  final BuildState state;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      BuildState.building => (Colors.blue, AppIcons.loading),
      BuildState.ok => (Colors.green, AppIcons.ok),
      BuildState.failed => (Colors.red, AppIcons.error),
      BuildState.unknown => (Colors.orange, AppIcons.unknown),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const Gap(4),
          Text(
            state.displayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Actions available for a build.
enum BuildAction { run, cancel }
