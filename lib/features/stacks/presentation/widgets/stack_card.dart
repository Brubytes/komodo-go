import 'package:flutter/material.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_action_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card_support.dart';
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
    final serverLabel = (serverName ?? stack.info.serverId).trim();
    final serviceCount = stack.info.services.length;
    final onAction = this.onAction;

    return ResourceCard(
      key: ValueKey('stack_card_${stack.id}'),
      menuKey: ValueKey('stack_card_menu_${stack.id}'),
      title: stack.name,
      subtitle: _subtitle(stack),
      status: stackStatusSpec(stack),
      meta: [
        if (serverLabel.isNotEmpty)
          ResourceIconLabel(icon: AppIcons.server, label: serverLabel),
        if (serviceCount > 0)
          ResourceIconLabel(
            icon: AppIcons.stacks,
            label: '$serviceCount service${serviceCount == 1 ? '' : 's'}',
          ),
      ],
      pills: [
        if (stack.template) const TextPill(label: 'Template'),
        ...resourceTagPills(displayTags),
      ],
      menu: onAction == null
          ? const []
          : stackMenuGroups(stack.info.state, onAction),
      onTap: onTap,
    );
  }
}

/// Status pill/accent for a stack. A running stack with pending image updates
/// surfaces the update as the (warning) status.
ResourceStatusSpec stackStatusSpec(StackListItem stack) {
  final state = stack.info.state;
  if (state == StackState.running && stack.hasPendingUpdate) {
    return const ResourceStatusSpec(
      label: 'Update available',
      icon: AppIcons.updateAvailable,
      tone: PillTone.warning,
    );
  }
  final (tone, icon) = switch (state) {
    StackState.running => (PillTone.success, AppIcons.ok),
    StackState.deploying => (PillTone.warning, AppIcons.loading),
    StackState.restarting => (PillTone.warning, AppIcons.loading),
    StackState.removing => (PillTone.warning, AppIcons.waiting),
    StackState.unhealthy => (PillTone.alert, AppIcons.error),
    StackState.dead => (PillTone.alert, AppIcons.canceled),
    StackState.paused => (PillTone.neutral, AppIcons.paused),
    StackState.stopped => (PillTone.neutral, AppIcons.stopped),
    StackState.created => (PillTone.neutral, AppIcons.pending),
    StackState.down => (PillTone.neutral, AppIcons.pending),
    StackState.unknown => (PillTone.neutral, AppIcons.unknown),
  };
  return ResourceStatusSpec(label: state.displayName, icon: icon, tone: tone);
}

/// Menu groups (Lifecycle, Maintenance, Danger) valid for [state].
List<DetailActionGroup> stackMenuGroups(
  StackState state,
  void Function(StackAction action) onAction,
) {
  VoidCallback call(StackAction a) =>
      () => onAction(a);

  final transient =
      state == StackState.deploying ||
      state == StackState.restarting ||
      state == StackState.removing;
  final running = state == StackState.running;
  final unhealthy = state == StackState.unhealthy;

  return resourceMenuGroups(
    lifecycle: [
      if (!transient && !running && !unhealthy)
        ResourceMenuItems.start(call(StackAction.start)),
      if (running || unhealthy)
        ResourceMenuItems.restart(call(StackAction.restart)),
      if (running) ResourceMenuItems.pause(call(StackAction.pause)),
      if (running || unhealthy) ResourceMenuItems.stop(call(StackAction.stop)),
    ],
    maintenance: [
      ResourceMenuItems.pullImages(call(StackAction.pullImages)),
      ResourceMenuItems.checkUpdates(call(StackAction.checkUpdates)),
      ResourceMenuItems.deployIfChanged(call(StackAction.deployIfChanged)),
      ResourceMenuItems.redeploy(call(StackAction.redeploy)),
    ],
    danger: [ResourceMenuItems.destroy(call(StackAction.destroy))],
  );
}

String _subtitle(StackListItem stack) {
  if (stack.sourceLabel == 'Git') {
    final repo = stack.info.linkedRepo.trim().isNotEmpty
        ? stack.info.linkedRepo.trim()
        : stack.info.repo.trim();
    final branch = stack.info.branch.trim();
    if (repo.isNotEmpty) return branch.isNotEmpty ? '$repo · $branch' : repo;
    final provider = stack.info.gitProvider.trim();
    if (provider.isNotEmpty) return provider;
  }
  return stack.sourceLabel;
}

/// Actions available for a stack.
enum StackAction {
  checkUpdates,
  deployIfChanged,
  redeploy,
  pullImages,
  restart,
  pause,
  start,
  stop,
  destroy,
}
