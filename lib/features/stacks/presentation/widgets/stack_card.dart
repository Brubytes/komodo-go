import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/menus/komodo_popup_menu.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';

import 'package:komodo_go/features/stacks/data/models/stack.dart';

/// Card widget displaying stack information.
class StackCard extends StatelessWidget {
  const StackCard({
    required this.stack,
    required this.serverName,
    required this.displayTags,
    this.onTap,
    this.onAction,
    super.key,
  });

  final StackListItem stack;
  final String? serverName;
  final List<String> displayTags;
  final VoidCallback? onTap;
  final void Function(StackAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final state = stack.info.state;
    final repo = stack.info.repo;
    final branch = stack.info.branch;
    final status = _statusLabel(stack.info.status ?? '');
    final sourceLabel = _sourceLabel(stack);
    final sourceIcon = _sourceIcon(stack);
    final serverLabel = (serverName ?? stack.info.serverId).trim();
    final hasPendingUpdate = stack.hasPendingUpdate;
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
                      stack.name,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
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
                    if (sourceLabel.isNotEmpty || serverLabel.isNotEmpty) ...[
                      const Gap(10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          if (sourceLabel.isNotEmpty)
                            _IconLabel(icon: sourceIcon, label: sourceLabel),
                          if (serverLabel.isNotEmpty)
                            _IconLabel(
                              icon: AppIcons.server,
                              label: serverLabel,
                            ),
                        ],
                      ),
                    ],
                    if (hasPendingUpdate ||
                        stack.template ||
                        tagPills.isNotEmpty) ...[
                      const Gap(10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (stack.template) const TextPill(label: 'Template'),
                          if (hasPendingUpdate)
                            const TextPill(
                              label: 'Update available',
                              icon: AppIcons.updateAvailable,
                              tone: PillTone.warning,
                            ),
                          ...tagPills,
                        ],
                      ),
                    ],
                    if (status.isNotEmpty) ...[
                      const Gap(8),
                      Text(
                        status,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                      child: PopupMenuButton<StackAction>(
                        key: const ValueKey('stack_card_menu'),
                        icon: const Icon(AppIcons.moreVertical),
                        onSelected: onAction,
                        itemBuilder: (context) =>
                            _buildMenuItems(context, state),
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

  List<PopupMenuEntry<StackAction>> _buildMenuItems(
    BuildContext context,
    StackState state,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return [
      komodoPopupMenuItem(
        value: StackAction.redeploy,
        icon: AppIcons.deployments,
        label: 'Redeploy',
        iconColor: scheme.primary,
      ),
      komodoPopupMenuItem(
        value: StackAction.pullImages,
        icon: AppIcons.download,
        label: 'Pull images',
        iconColor: scheme.primary,
      ),
      if (state.isRunning)
        komodoPopupMenuItem(
          value: StackAction.restart,
          icon: AppIcons.refresh,
          label: 'Restart',
          iconColor: scheme.primary,
        ),
      if (state.isRunning)
        komodoPopupMenuItem(
          value: StackAction.pause,
          icon: AppIcons.pause,
          label: 'Pause',
          iconColor: scheme.tertiary,
        ),
      komodoPopupMenuDivider(),
      if (!state.isRunning)
        komodoPopupMenuItem(
          value: StackAction.start,
          icon: AppIcons.play,
          label: 'Start',
          iconColor: scheme.secondary,
        ),
      if (state.isRunning)
        komodoPopupMenuItem(
          value: StackAction.stop,
          icon: AppIcons.stop,
          label: 'Stop',
          iconColor: scheme.tertiary,
        ),
      komodoPopupMenuItem(
        value: StackAction.destroy,
        icon: AppIcons.delete,
        label: 'Destroy',
        destructive: true,
      ),
    ];
  }

  String _statusLabel(String status) {
    final normalized = status.trim();
    if (normalized.isEmpty) return '';
    if (_containerCountPattern.hasMatch(normalized.toLowerCase())) {
      return '';
    }
    return normalized;
  }

  String _sourceLabel(StackListItem stack) {
    if (stack.sourceLabel == 'Git') {
      if (stack.info.linkedRepo.trim().isNotEmpty) {
        return stack.info.linkedRepo.trim();
      }
      if (stack.info.repo.trim().isNotEmpty) {
        return stack.info.repo.trim();
      }
      if (stack.info.gitProvider.trim().isNotEmpty) {
        return stack.info.gitProvider.trim();
      }
    }
    return stack.sourceLabel;
  }

  IconData _sourceIcon(StackListItem stack) {
    if (stack.info.fileContents) return AppIcons.notepadText;
    if (stack.info.filesOnHost) return AppIcons.server;
    if (stack.info.linkedRepo.isNotEmpty || stack.info.repo.isNotEmpty) {
      return AppIcons.repos;
    }
    return AppIcons.package;
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
}

final _containerCountPattern = RegExp(
  r'^(running|stopped|paused|deploying|restarting|removing|down|dead|unhealthy|exited)\s*\(\d+\)$',
);

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state, this.compact = false});

  final StackState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      StackState.deploying => (Colors.blue, AppIcons.loading),
      StackState.running => (Colors.green, AppIcons.ok),
      StackState.paused => (Colors.grey, AppIcons.paused),
      StackState.stopped => (Colors.red, AppIcons.stopped),
      StackState.created => (Colors.grey, AppIcons.pending),
      StackState.restarting => (Colors.blue, AppIcons.loading),
      StackState.removing => (Colors.grey, AppIcons.waiting),
      StackState.unhealthy => (Colors.red, AppIcons.error),
      StackState.down => (Colors.grey, AppIcons.pending),
      StackState.dead => (Colors.red, AppIcons.canceled),
      StackState.unknown => (Colors.orange, AppIcons.unknown),
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
        border: Border.all(color: color.withValues(alpha: 0.3)),
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

/// Actions available for a stack.
enum StackAction { redeploy, pullImages, restart, pause, start, stop, destroy }
