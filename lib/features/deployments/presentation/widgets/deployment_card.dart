import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/menus/komodo_popup_menu.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';

/// Card widget displaying deployment information.
class DeploymentCard extends StatelessWidget {
  const DeploymentCard({
    required this.deployment,
    required this.displayTags,
    this.serverName,
    this.onTap,
    this.onAction,
    super.key,
  });

  final Deployment deployment;
  final List<String> displayTags;
  final String? serverName;
  final VoidCallback? onTap;
  final void Function(DeploymentAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final state = deployment.info?.state ?? DeploymentState.unknown;
    final image = _stripHashes(deployment.imageLabel);
    final status = _statusLabel(deployment.info?.status ?? '');
    final description = _stripHashes(deployment.description?.trim() ?? '');
    final serverLabel = (serverName ??
            deployment.info?.serverId ??
            deployment.config?.serverId ??
            '')
        .trim();
    final hasPendingUpdate = deployment.info?.updateAvailable ?? false;
    final tagPills = _buildTagPills(displayTags);

    final cardRadius = BorderRadius.circular(AppTokens.radiusLg);

    return AppCardSurface(
      key: ValueKey('deployment_card_${deployment.id}'),
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
                        deployment.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (image.isNotEmpty) ...[
                        const Gap(4),
                        Text(
                          image,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.7),
                              ),
                        ),
                      ],
                      if (serverLabel.isNotEmpty) ...[
                        const Gap(10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _IconLabel(
                              icon: AppIcons.server,
                              label: serverLabel,
                            ),
                          ],
                        ),
                      ],
                      if (deployment.template ||
                          hasPendingUpdate ||
                          tagPills.isNotEmpty) ...[
                        const Gap(10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (deployment.template)
                              const TextPill(label: 'Template'),
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
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (description.isNotEmpty) ...[
                        const Gap(6),
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
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
                      child: PopupMenuButton<DeploymentAction>(
                        key: ValueKey('deployment_card_menu_${deployment.id}'),
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

  List<PopupMenuEntry<DeploymentAction>> _buildMenuItems(
    BuildContext context,
    DeploymentState state,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final items = <PopupMenuEntry<DeploymentAction>>[];

    final deployLabel =
        (state == DeploymentState.notDeployed ||
            state == DeploymentState.unknown)
        ? 'Deploy'
        : 'Redeploy';

    items.add(
      komodoPopupMenuItem(
        value: DeploymentAction.deploy,
        icon: AppIcons.deployments,
        label: deployLabel,
        iconColor: scheme.primary,
      ),
    );

    final hasImage = deployment.info?.image.isNotEmpty ?? false;
    if (hasImage) {
      items.add(
        komodoPopupMenuItem(
          value: DeploymentAction.pullImages,
          icon: AppIcons.download,
          label: 'Pull image',
          iconColor: scheme.primary,
        ),
      );
    }

    final showStart =
        state == DeploymentState.created || state == DeploymentState.exited;
    final showStop = state.isRunning;
    final showRestart = state.isRunning || state.isPaused;
    final showPause = state.isRunning;
    final showUnpause = state.isPaused;

    final hasLifecycle =
        showStart || showStop || showRestart || showPause || showUnpause;
    if (hasLifecycle) {
      items.add(komodoPopupMenuDivider());
      if (showStart) {
        items.add(
          komodoPopupMenuItem(
            value: DeploymentAction.start,
            icon: AppIcons.play,
            label: 'Start',
            iconColor: scheme.secondary,
          ),
        );
      }
      if (showStop) {
        items.add(
          komodoPopupMenuItem(
            value: DeploymentAction.stop,
            icon: AppIcons.stop,
            label: 'Stop',
            iconColor: scheme.tertiary,
          ),
        );
      }
      if (showRestart) {
        items.add(
          komodoPopupMenuItem(
            value: DeploymentAction.restart,
            icon: AppIcons.refresh,
            label: 'Restart',
            iconColor: scheme.primary,
          ),
        );
      }
      if (showPause) {
        items.add(
          komodoPopupMenuItem(
            value: DeploymentAction.pause,
            icon: AppIcons.pause,
            label: 'Pause',
            iconColor: scheme.tertiary,
          ),
        );
      }
      if (showUnpause) {
        items.add(
          komodoPopupMenuItem(
            value: DeploymentAction.unpause,
            icon: AppIcons.play,
            label: 'Unpause',
            iconColor: scheme.primary,
          ),
        );
      }
    }

    final showDestroy = state != DeploymentState.notDeployed;
    if (showDestroy) {
      items
        ..add(komodoPopupMenuDivider())
        ..add(
          komodoPopupMenuItem(
            value: DeploymentAction.destroy,
            icon: AppIcons.delete,
            label: 'Destroy',
            destructive: true,
            key: ValueKey('deployment_card_destroy_${deployment.id}'),
          ),
        );
    }

    return items;
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state, this.compact = false});

  final DeploymentState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, icon) = switch (state) {
      DeploymentState.deploying => (scheme.primary, AppIcons.loading),
      DeploymentState.running => (scheme.secondary, AppIcons.ok),
      DeploymentState.created => (scheme.onSurfaceVariant, AppIcons.pending),
      DeploymentState.restarting => (scheme.primary, AppIcons.loading),
      DeploymentState.removing => (scheme.onSurfaceVariant, AppIcons.waiting),
      DeploymentState.exited => (scheme.tertiary, AppIcons.stopped),
      DeploymentState.dead => (scheme.error, AppIcons.canceled),
      DeploymentState.paused => (scheme.onSurfaceVariant, AppIcons.paused),
      DeploymentState.notDeployed => (
        scheme.onSurfaceVariant,
        AppIcons.pending,
      ),
      DeploymentState.unknown => (scheme.tertiary, AppIcons.unknown),
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

String _statusLabel(String status) {
  final normalized = _stripHashes(status.trim());
  if (normalized.isEmpty) return '';
  if (_containerCountPattern.hasMatch(normalized.toLowerCase())) {
    return '';
  }
  return normalized;
}

final _hashPattern =
    RegExp(r'\b(?:sha256:)?[a-f0-9]{7,64}\b', caseSensitive: false);

String _stripHashes(String value) {
  final cleaned = value.replaceAll(_hashPattern, '').replaceAll('  ', ' ');
  return cleaned.trim();
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

final _containerCountPattern = RegExp(
  r'^(running|stopped|paused|deploying|restarting|removing|down|dead|unhealthy|exited)\s*\(\d+\)$',
);

/// Actions available for a deployment.
enum DeploymentAction {
  deploy,
  pullImages,
  restart,
  pause,
  unpause,
  start,
  stop,
  destroy,
}
