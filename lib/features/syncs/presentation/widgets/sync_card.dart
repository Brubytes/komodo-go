import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';

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
    final state = sync.info.state;
    final repo = sync.info.repo;
    final branch = sync.info.branch;
    final linkedRepo = sync.info.linkedRepo;
    final repoLabel = linkedRepo.isNotEmpty ? linkedRepo : repo;
    final resourcePath = sync.info.resourcePath.join('/');
    final tagPills = _buildTagPills(displayTags);

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
                        sync.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Gap(4),
                      Text(
                        repoLabel.isNotEmpty
                            ? (branch.isNotEmpty
                                  ? '$repoLabel · $branch'
                                  : repoLabel)
                            : 'No repo',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                            ),
                      ),
                      if (resourcePath.isNotEmpty) ...[
                        const Gap(10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _IconLabel(
                              icon: AppIcons.package,
                              label: 'path: $resourcePath',
                            ),
                          ],
                        ),
                      ],
                      if (sync.template || tagPills.isNotEmpty) ...[
                        const Gap(10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (sync.template)
                              const TextPill(label: 'Template'),
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
                if (onRun != null)
                  Positioned(
                    right: 6,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(AppIcons.play),
                        onPressed: onRun,
                        tooltip: 'Run',
                      ),
                    ),
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
  const _StatusBadge({required this.state, this.compact = false});

  final ResourceSyncState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      ResourceSyncState.syncing => (Colors.blue, AppIcons.loading),
      ResourceSyncState.pending => (Colors.orange, AppIcons.pending),
      ResourceSyncState.ok => (Colors.green, AppIcons.ok),
      ResourceSyncState.failed => (Colors.red, AppIcons.error),
      ResourceSyncState.unknown => (Colors.orange, AppIcons.unknown),
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

class _IconLabel extends StatelessWidget {
  const _IconLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const Gap(6),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
