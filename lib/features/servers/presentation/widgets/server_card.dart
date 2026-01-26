import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';

import 'package:komodo_go/features/servers/data/models/server.dart';

/// Card widget displaying server information.
class ServerCard extends StatelessWidget {
  const ServerCard({
    required this.server,
    required this.displayTags,
    this.onTap,
    super.key,
  });

  final Server server;
  final List<String> displayTags;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final state = server.info?.state ?? ServerState.unknown;
    final region = (server.info?.region ?? server.config?.region ?? '').trim();
    final version = (server.info?.version ?? '').trim();
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 40, 16),
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                            ),
                      ),
                      if (region.isNotEmpty || version.isNotEmpty) ...[
                        const Gap(10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (region.isNotEmpty)
                              _IconLabel(
                                icon: AppIcons.network,
                                label: region,
                              ),
                            if (version.isNotEmpty)
                              _IconLabel(
                                icon: AppIcons.package,
                                label: version,
                              ),
                          ],
                        ),
                      ],
                      if (server.template || tagPills.isNotEmpty) ...[
                        const Gap(10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (server.template)
                              const TextPill(label: 'Template'),
                            ...tagPills,
                          ],
                        ),
                      ],
                      if (server.description != null &&
                          server.description!.isNotEmpty) ...[
                        const Gap(8),
                        Text(
                          server.description!,
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
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      AppIcons.chevron,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.3),
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

  final ServerState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      ServerState.ok => (Colors.green, AppIcons.ok),
      ServerState.notOk => (Colors.red, AppIcons.error),
      ServerState.disabled => (Colors.grey, AppIcons.paused),
      ServerState.unknown => (Colors.orange, AppIcons.unknown),
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
            _serverStateLabel(state),
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

String _serverStateLabel(ServerState state) {
  return switch (state) {
    ServerState.ok => 'Ok',
    ServerState.notOk => 'Not ok',
    ServerState.disabled => 'Disabled',
    ServerState.unknown => 'Unknown',
  };
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
