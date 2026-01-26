import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/menus/komodo_popup_menu.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';

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
    final tagPills = _buildTagPills(displayTags);
    final showVersion = version != '0.0.0';

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
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: SizedBox(
              width: double.infinity,
              child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 76, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        buildItem.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (repo.isNotEmpty) ...[
                        const Gap(4),
                        Text(
                          branch.isNotEmpty ? '$repo · $branch' : repo,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.7),
                              ),
                        ),
                      ],
                      if (buildItem.template ||
                          showVersion ||
                          tagPills.isNotEmpty) ...[
                        const Gap(10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (buildItem.template)
                              const TextPill(label: 'Template'),
                            if (showVersion)
                              ValuePill(label: 'Version', value: 'v$version'),
                            ...tagPills,
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 12,
                  child: _StatusBadge(state: state, compact: true),
                ),
                if (onAction != null)
                  Positioned(
                    right: 6,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: PopupMenuButton<BuildAction>(
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
                    ),
                  ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state, this.compact = false});

  final BuildState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      BuildState.building => (Colors.blue, AppIcons.loading),
      BuildState.ok => (Colors.green, AppIcons.ok),
      BuildState.failed => (Colors.red, AppIcons.error),
      BuildState.unknown => (Colors.orange, AppIcons.unknown),
    };

    final padding =
        compact
            ? const EdgeInsets.symmetric(horizontal: 5, vertical: 1)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    final iconSize = compact ? 11.0 : 14.0;
    final fontSize = compact ? 10.0 : 12.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          Gap(compact ? 2 : 4),
          Text(
            state.displayName,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

List<Widget> _buildTagPills(List<String> tags) {
  if (tags.isEmpty) return [];
  final capped = tags.take(3).toList();
  final remaining = tags.length - capped.length;
  return [
    for (final tag in capped) TextPill(label: tag),
    if (remaining > 0) ValuePill(label: 'More', value: '+$remaining'),
  ];
}

/// Actions available for a build.
enum BuildAction { run, cancel }
