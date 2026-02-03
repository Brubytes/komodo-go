import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/core/widgets/menus/komodo_popup_menu.dart';

import 'package:komodo_go/features/containers/data/models/container.dart';
import 'package:komodo_go/features/containers/presentation/providers/containers_provider.dart';

class ContainerCard extends StatelessWidget {
  const ContainerCard({
    required this.item,
    this.onTap,
    this.onAction,
    super.key,
  });

  final ContainerOverviewItem item;
  final VoidCallback? onTap;
  final void Function(ContainerAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final name = item.container.name.isEmpty ? 'Unnamed' : item.container.name;
    final image = item.container.image ?? '';
    final networks = item.container.networks;
    final stats = item.container.stats;

    final stateColor = _stateColor(item.container.state, scheme);
    final portsLabel = _formatPorts(item.container.ports);

    final pillBg = scheme.surfaceContainerHigh;
    final pillFg = scheme.onSurface;

    final hasActions = _hasActions(item.container.state);
    final keyId =
        (item.container.id?.trim().isNotEmpty ?? false)
            ? item.container.id!.trim()
            : (item.container.name.trim().isNotEmpty
                  ? item.container.name.trim()
                  : 'unknown');

    return AppCardSurface(
      key: ValueKey('container_card_$keyId'),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LeadingIcon(color: stateColor),
                    const Gap(12),
                    Expanded(
                      child: Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Gap(12),
                      _StateChip(
                      state: item.container.state,
                      color: stateColor,
                      showMenu: onAction != null && hasActions,
                      onAction: onAction,
                      itemsBuilder: (context) =>
                          _buildMenuItems(context, item.container.state, keyId),
                      menuKey: ValueKey('container_card_menu_$keyId'),
                    ),
                  ],
                ),
                const Gap(12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InfoPill(
                      icon: AppIcons.server,
                      label: item.serverName,
                      backgroundColor: pillBg,
                      foregroundColor: pillFg,
                    ),
                    if (image.isNotEmpty)
                      _InfoPill(
                        icon: AppIcons.package,
                        label: image,
                        backgroundColor: pillBg,
                        foregroundColor: pillFg,
                      ),
                    if (networks.isNotEmpty)
                      _InfoPill(
                        icon: AppIcons.network,
                        label:
                            '${networks.take(2).join(', ')}${networks.length > 2 ? '…' : ''}',
                        backgroundColor: pillBg,
                        foregroundColor: pillFg,
                      ),
                    if (portsLabel.isNotEmpty)
                      _InfoPill(
                        icon: AppIcons.plug,
                        label: 'Ports: $portsLabel',
                        backgroundColor: pillBg,
                        foregroundColor: pillFg,
                      ),
                  ],
                ),
                if (stats != null) ...[
                  const Gap(14),
                  _UsageRow(
                    icon: AppIcons.cpu,
                    label: 'CPU',
                    value:
                        stats.cpuPerc.trim().isNotEmpty ? stats.cpuPerc : '-',
                    progress: stats.cpuPercentValue != null
                        ? stats.cpuPercentValue! / 100.0
                        : null,
                    accent: scheme.primary,
                  ),
                  const Gap(10),
                  _UsageRow(
                    icon: AppIcons.memory,
                    label: 'Memory',
                    value: stats.memUsage.trim().isNotEmpty
                        ? stats.memUsage
                        : (stats.memPerc.trim().isNotEmpty
                              ? stats.memPerc
                              : '-'),
                    progress: stats.memPercentValue != null
                        ? stats.memPercentValue! / 100.0
                        : null,
                    accent: scheme.secondary,
                  ),
                  const Gap(10),
                  _IoRow(stats: stats),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _hasActions(ContainerState state) {
    final canStop =
        state == ContainerState.running ||
        state == ContainerState.paused ||
        state == ContainerState.restarting;
    final canRestart =
        state == ContainerState.running ||
        state == ContainerState.paused ||
        state == ContainerState.restarting ||
        state == ContainerState.exited ||
        state == ContainerState.created;
    return canStop || canRestart;
  }

  List<PopupMenuEntry<ContainerAction>> _buildMenuItems(
    BuildContext context,
    ContainerState state,
    String keyId,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final items = <PopupMenuEntry<ContainerAction>>[];

    final canStop =
        state == ContainerState.running ||
        state == ContainerState.paused ||
        state == ContainerState.restarting;
    final canRestart =
        state == ContainerState.running ||
        state == ContainerState.paused ||
        state == ContainerState.restarting ||
        state == ContainerState.exited ||
        state == ContainerState.created;

    if (canRestart) {
      items.add(
        komodoPopupMenuItem(
          key: ValueKey('container_card_restart_$keyId'),
          value: ContainerAction.restart,
          icon: AppIcons.refresh,
          label: 'Restart',
          iconColor: scheme.primary,
        ),
      );
    }
    if (canStop) {
      items.add(
        komodoPopupMenuItem(
          key: ValueKey('container_card_stop_$keyId'),
          value: ContainerAction.stop,
          icon: AppIcons.stop,
          label: 'Stop',
          iconColor: scheme.tertiary,
        ),
      );
    }

    return items;
  }
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(AppIcons.containers, color: color),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({
    required this.state,
    required this.color,
    required this.showMenu,
    this.onAction,
    this.itemsBuilder,
    this.menuKey,
  });

  final ContainerState state;
  final Color color;
  final bool showMenu;
  final void Function(ContainerAction action)? onAction;
  final List<PopupMenuEntry<ContainerAction>> Function(BuildContext context)?
  itemsBuilder;
  final Key? menuKey;

  @override
  Widget build(BuildContext context) {
    final label = switch (state) {
      ContainerState.running => 'RUNNING',
      ContainerState.exited => 'EXITED',
      ContainerState.paused => 'PAUSED',
      ContainerState.restarting => 'RESTARTING',
      ContainerState.created => 'CREATED',
      ContainerState.removing => 'REMOVING',
      ContainerState.dead => 'DEAD',
      ContainerState.unknown => 'UNKNOWN',
    };

    final chip = DecoratedBox(
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.18),
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            if (showMenu) ...[
              const Gap(6),
              Icon(AppIcons.moreVertical, size: 14, color: color),
            ],
          ],
        ),
      ),
    );

    if (!showMenu || onAction == null || itemsBuilder == null) {
      return chip;
    }

    return PopupMenuButton<ContainerAction>(
      key: menuKey,
      onSelected: onAction,
      itemBuilder: itemsBuilder!,
      child: chip,
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: foregroundColor,
      fontWeight: FontWeight.w600,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 34, maxWidth: 520),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: backgroundColor,
          shape: const StadiumBorder(),
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
              blurRadius: isDark ? 16 : 12,
              offset: const Offset(0, 6),
              spreadRadius: isDark ? -6 : -7,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: foregroundColor.withValues(alpha: 0.9),
              ),
              const Gap(8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.progress,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final double? progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            const Gap(8),
            Expanded(
              child: Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (progress != null) ...[
          const Gap(6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress!.clamp(0, 1),
              minHeight: 6,
              backgroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
        ],
      ],
    );
  }
}

class _IoRow extends StatelessWidget {
  const _IoRow({required this.stats});

  final ContainerStats? stats;

  @override
  Widget build(BuildContext context) {
    final netLabel = stats?.netIo.trim() ?? '';
    final blockLabel = stats?.blockIo.trim() ?? '';

    if (netLabel.isEmpty && blockLabel.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppCardSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      radius: AppTokens.radiusMd,
      enableGradientInDark: false,
      child: Row(
        children: [
          Expanded(
            child: _IoMetric(
              icon: AppIcons.network,
              label: 'Net I/O',
              value: netLabel.isNotEmpty ? netLabel : '-',
            ),
          ),
          const Gap(12),
          Expanded(
            child: _IoMetric(
              icon: AppIcons.hardDrive,
              label: 'Drive I/O',
              value: blockLabel.isNotEmpty ? blockLabel : '-',
            ),
          ),
        ],
      ),
    );
  }
}

class _IoMetric extends StatelessWidget {
  const _IoMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            const Gap(6),
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const Gap(4),
        Text(
          value,
          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

Color _stateColor(ContainerState state, ColorScheme scheme) {
  return switch (state) {
    ContainerState.running => AppTokens.statusGreen,
    ContainerState.exited || ContainerState.dead => AppTokens.statusRed,
    ContainerState.paused ||
    ContainerState.restarting ||
    ContainerState.created ||
    ContainerState.removing => AppTokens.statusOrange,
    ContainerState.unknown => scheme.onSurfaceVariant,
  };
}

String _formatPorts(List<ContainerPort> ports) {
  final values =
      ports
          .map((port) => port.publicPort ?? port.privatePort)
          .where((port) => port > 0)
          .toSet()
          .toList()
        ..sort();

  if (values.isEmpty) return '';
  return values.take(6).join(' • ') + (values.length > 6 ? '…' : '');
}

/// Actions available for a container.
enum ContainerAction { restart, stop }
