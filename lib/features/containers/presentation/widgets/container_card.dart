import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/composition/containers/containers_provider.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_action_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card_support.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/containers/data/models/container.dart';
import 'package:komodo_go/features/containers/presentation/widgets/container_card_parts.dart';

/// Card widget displaying container information.
///
/// Header: icon tile, wrapping name and a status pill with the actions menu.
/// Below: tonal chips (server, image, networks, ports), then either a compact
/// 2x2 stats grid (running) or the muted exit status line (exited).
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
    final container = item.container;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final name = container.name.isEmpty ? 'Unnamed' : container.name;
    final image = container.image ?? '';
    final stats = container.stats;
    final keyId = (container.id?.trim().isNotEmpty ?? false)
        ? container.id!.trim()
        : (container.name.trim().isNotEmpty
              ? container.name.trim()
              : 'unknown');
    final onAction = this.onAction;
    final menu = onAction == null || container.state == ContainerState.removing
        ? const <DetailActionGroup>[]
        : containerMenuGroups(container.state, onAction);
    final hasMenu = menu.any((g) => g.items.isNotEmpty);
    final status = containerStatusSpec(container);

    final showMetrics =
        container.state == ContainerState.running &&
        stats != null &&
        ContainerMetricsGrid.hasData(stats);
    final exitInfo = container.state == ContainerState.exited
        ? container.status?.trim()
        : null;

    final networks = container.networks;
    final ports = container.ports.map(formatContainerPort).toSet().toList();
    final shownPorts = ports.take(3).toList();
    final extraPorts = ports.length - shownPorts.length;

    final radius = BorderRadius.circular(AppTokens.radiusLg);

    return AppCardSurface(
      key: ValueKey('container_card_$keyId'),
      padding: EdgeInsets.zero,
      child: GestureDetector(
        onLongPressStart: hasMenu
            ? (details) {
                unawaited(HapticFeedback.selectionClick());
                unawaited(
                  showDetailActionMenu(
                    context,
                    groups: menu,
                    position: details.globalPosition,
                  ),
                );
              }
            : null,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ContainerIconTile(tone: status.tone),
                      const Gap(AppSpacing.md),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const Gap(AppSpacing.md),
                      ContainerStatusPill(
                        status: status,
                        menu: menu,
                        menuKey: ValueKey('container_card_menu_$keyId'),
                      ),
                    ],
                  ),
                  const Gap(AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if (item.serverName.isNotEmpty)
                        ContainerInfoChip(
                          icon: AppIcons.server,
                          label: item.serverName,
                        ),
                      if (image.isNotEmpty)
                        ContainerInfoChip(
                          icon: AppIcons.package,
                          label: formatContainerImage(image),
                          tooltip: image,
                        ),
                      if (networks.isNotEmpty)
                        ContainerInfoChip(
                          icon: AppIcons.network,
                          label:
                              '${networks.take(2).join(', ')}'
                              '${networks.length > 2 ? '…' : ''}',
                        ),
                      for (final p in shownPorts) ContainerInfoChip(label: p),
                      if (extraPorts > 0)
                        ContainerInfoChip(label: '+$extraPorts'),
                    ],
                  ),
                  if (showMetrics) ...[
                    const Gap(AppSpacing.md),
                    ContainerMetricsGrid(stats: stats),
                  ] else if (exitInfo != null && exitInfo.isNotEmpty) ...[
                    const Gap(AppSpacing.sm),
                    Text(
                      exitInfo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Status pill/accent for a container.
///
/// An exited container with a non-zero exit code is treated as failed.
ResourceStatusSpec containerStatusSpec(ContainerListItem container) {
  final state = container.state;
  final (label, tone, icon) = switch (state) {
    ContainerState.running => ('Running', PillTone.success, AppIcons.ok),
    ContainerState.dead => ('Dead', PillTone.alert, AppIcons.canceled),
    ContainerState.restarting => (
      'Restarting',
      PillTone.warning,
      AppIcons.loading,
    ),
    ContainerState.removing => ('Removing', PillTone.warning, AppIcons.waiting),
    ContainerState.exited =>
      _exitedWithError(container.status)
          ? ('Exited', PillTone.alert, AppIcons.error)
          : ('Exited', PillTone.neutral, AppIcons.stopped),
    ContainerState.paused => ('Paused', PillTone.neutral, AppIcons.paused),
    ContainerState.created => ('Created', PillTone.neutral, AppIcons.pending),
    ContainerState.unknown => ('Unknown', PillTone.neutral, AppIcons.unknown),
  };
  return ResourceStatusSpec(label: label, icon: icon, tone: tone);
}

bool _exitedWithError(String? status) {
  final match = RegExp(r'Exited \((\d+)\)').firstMatch(status ?? '');
  return match != null && match.group(1) != '0';
}

/// Menu groups (Lifecycle, Danger) valid for [state].
List<DetailActionGroup> containerMenuGroups(
  ContainerState state,
  void Function(ContainerAction action) onAction,
) {
  VoidCallback call(ContainerAction a) =>
      () => onAction(a);

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
  final canStart =
      state == ContainerState.exited ||
      state == ContainerState.created ||
      state == ContainerState.dead;

  return resourceMenuGroups(
    lifecycle: [
      if (canStart) ResourceMenuItems.start(call(ContainerAction.start)),
      if (state == ContainerState.paused)
        ResourceMenuItems.unpause(call(ContainerAction.unpause)),
      if (state == ContainerState.running)
        ResourceMenuItems.pause(call(ContainerAction.pause)),
      if (canRestart) ResourceMenuItems.restart(call(ContainerAction.restart)),
      if (canStop) ResourceMenuItems.stop(call(ContainerAction.stop)),
    ],
    danger: [
      ResourceMenuItems.destroy(call(ContainerAction.remove), label: 'Remove'),
    ],
  );
}

/// Actions available for a container.
enum ContainerAction { start, restart, pause, unpause, stop, remove }
