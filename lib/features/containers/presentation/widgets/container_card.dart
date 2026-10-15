import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/composition/containers/containers_provider.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_action_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card_support.dart';
import 'package:komodo_go/features/containers/data/models/container.dart';
import 'package:komodo_go/features/containers/presentation/widgets/container_card_parts.dart';

/// Card widget displaying container information.
///
/// In lists the card stays compact: server + image, and CPU/memory on a single
/// line.
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

    final scheme = Theme.of(context).colorScheme;
    final showMetrics =
        container.state == ContainerState.running &&
        stats != null &&
        ContainerMetricsGrid.hasData(stats);
    final exitInfo = container.state == ContainerState.exited
        ? container.status?.trim()
        : null;

    final bottom = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (image.isNotEmpty) ContainerImageLine(image: image),
        if (item.serverName.isNotEmpty) ...[
          const Gap(AppSpacing.xs),
          ResourceIconLabel(icon: AppIcons.server, label: item.serverName),
        ],
        if (container.ports.isNotEmpty) ...[
          const Gap(AppSpacing.sm),
          ContainerPortChips(ports: container.ports),
        ],
        if (showMetrics) ...[
          const Gap(AppSpacing.md),
          ContainerMetricsGrid(stats: stats),
        ] else if (exitInfo != null && exitInfo.isNotEmpty) ...[
          const Gap(AppSpacing.xs),
          Text(
            exitInfo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    return ResourceCard(
      key: ValueKey('container_card_$keyId'),
      menuKey: ValueKey('container_card_menu_$keyId'),
      title: name,
      status: containerStatusSpec(container),
      bottom: bottom,
      menu: menu,
      onTap: onTap,
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
