import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

import '../../data/models/container.dart';
import '../providers/containers_provider.dart';

class ContainerCard extends StatelessWidget {
  const ContainerCard({required this.item, super.key});

  final ContainerOverviewItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final name = item.container.name.isEmpty ? 'Unnamed' : item.container.name;
    final image = item.container.image ?? '';
    final networks = item.container.networks;

    final stateColor = _stateColor(item.container.state, scheme);
    final portsLabel = _formatPorts(item.container.ports);

    return Card(
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Gap(12),
                _StateChip(state: item.container.state, color: stateColor),
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
                  backgroundColor: scheme.secondaryContainer.withValues(
                    alpha: 0.35,
                  ),
                  foregroundColor: scheme.onSecondaryContainer,
                ),
                if (image.isNotEmpty)
                  _InfoPill(
                    icon: AppIcons.package,
                    label: image,
                    backgroundColor: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
                    foregroundColor: scheme.onSurface,
                  ),
                if (networks.isNotEmpty)
                  _InfoPill(
                    icon: AppIcons.network,
                    label:
                        '${networks.take(2).join(', ')}${networks.length > 2 ? '…' : ''}',
                    backgroundColor: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
                    foregroundColor: scheme.onSurface,
                  ),
                if (portsLabel.isNotEmpty)
                  _InfoPill(
                    icon: AppIcons.plug,
                    label: portsLabel,
                    backgroundColor: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
                    foregroundColor: scheme.onSurface,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
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
  const _StateChip({required this.state, required this.color});

  final ContainerState state;
  final Color color;

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

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.18),
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
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
