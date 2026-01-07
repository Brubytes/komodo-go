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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(AppIcons.containers, color: stateColor),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  const Gap(4),
                  Text(
                    item.serverName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (image.isNotEmpty) ...[
                    const Gap(4),
                    Text(
                      image,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (networks.isNotEmpty) ...[
                    const Gap(6),
                    Text(
                      'Networks: ${networks.take(3).join(', ')}${networks.length > 3 ? '…' : ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Gap(12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StateChip(state: item.container.state, color: stateColor),
                const Gap(8),
                if (portsLabel.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.dot,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                      const Gap(4),
                      Text(
                        portsLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
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
  final publicPorts =
      ports.map((port) => port.publicPort).whereType<int>().toSet().toList()
        ..sort();

  if (publicPorts.isEmpty) return '';
  return publicPorts.take(4).join(' | ') + (publicPorts.length > 4 ? '…' : '');
}
