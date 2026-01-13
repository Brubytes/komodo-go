import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/menus/komodo_popup_menu.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';

import 'package:komodo_go/features/stacks/data/models/stack.dart';

/// Card widget displaying stack information.
class StackCard extends StatelessWidget {
  const StackCard({required this.stack, this.onTap, this.onAction, super.key});

  final StackListItem stack;
  final VoidCallback? onTap;
  final void Function(StackAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final state = stack.info.state;
    final repo = stack.info.repo;
    final branch = stack.info.branch;
    final status = stack.info.status ?? '';

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusBadge(state: state),
                    const Gap(12),
                    Expanded(
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
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (onAction != null)
                      PopupMenuButton<StackAction>(
                        key: const ValueKey('stack_card_menu'),
                        icon: const Icon(AppIcons.moreVertical),
                        onSelected: onAction,
                        itemBuilder: (context) =>
                            _buildMenuItems(context, state),
                      ),
                  ],
                ),
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
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});

  final StackState state;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      StackState.deploying => (Colors.blue, AppIcons.loading),
      StackState.running => (Colors.green, AppIcons.ok),
      StackState.paused => (Colors.grey, AppIcons.paused),
      StackState.stopped => (Colors.orange, AppIcons.stopped),
      StackState.created => (Colors.grey, AppIcons.pending),
      StackState.restarting => (Colors.blue, AppIcons.loading),
      StackState.removing => (Colors.grey, AppIcons.waiting),
      StackState.unhealthy => (Colors.red, AppIcons.error),
      StackState.down => (Colors.grey, AppIcons.pending),
      StackState.dead => (Colors.red, AppIcons.canceled),
      StackState.unknown => (Colors.orange, AppIcons.unknown),
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

/// Actions available for a stack.
enum StackAction { redeploy, pullImages, restart, pause, start, stop, destroy }
