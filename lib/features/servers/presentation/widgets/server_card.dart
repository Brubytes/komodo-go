import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

import '../../data/models/server.dart';

/// Card widget displaying server information.
class ServerCard extends StatelessWidget {
  const ServerCard({required this.server, this.onTap, super.key});

  final Server server;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final state = server.info?.state ?? ServerState.unknown;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Status indicator
              _StatusIndicator(state: state),
              const Gap(16),

              // Server info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      server.address,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    if (server.description != null &&
                        server.description!.isNotEmpty) ...[
                      const Gap(4),
                      Text(
                        server.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow
              Icon(
                AppIcons.chevron,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.state});

  final ServerState state;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      ServerState.ok => (Colors.green, AppIcons.ok),
      ServerState.notOk => (Colors.red, AppIcons.error),
      ServerState.disabled => (Colors.grey, AppIcons.paused),
      ServerState.unknown => (Colors.orange, AppIcons.unknown),
    };

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}
