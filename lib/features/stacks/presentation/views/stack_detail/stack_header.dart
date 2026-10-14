import 'package:flutter/material.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/presentation/widgets/stack_card.dart';

/// App bar status line for a stack: state plus service count.
MainAppBarStatus? stackAppBarStatus({
  required StackListItem? listItem,
  required int? serviceCount,
}) {
  final state = listItem?.info.state;
  if (state == null) return null;
  final services = serviceCount == null
      ? ''
      : ' · $serviceCount service${serviceCount == 1 ? '' : 's'}';
  return MainAppBarStatus(
    label: '${state.displayName}$services',
    tone: _stateTone(state),
  );
}

PillTone _stateTone(StackState state) => switch (state) {
  StackState.running => PillTone.success,
  StackState.unhealthy || StackState.dead => PillTone.alert,
  StackState.paused ||
  StackState.restarting ||
  StackState.removing => PillTone.warning,
  _ => PillTone.neutral,
};

class StackHeader extends StatelessWidget {
  const StackHeader({
    required this.stack,
    required this.listItem,
    required this.serviceCount,
    required this.updateCount,
    required this.serverName,
    required this.sourceLabel,
    required this.sourceIcon,
    required this.displayTags,
    required this.onAction,
    this.onServerTap,
    this.onSourceTap,
    super.key,
  });

  final KomodoStack stack;
  final StackListItem? listItem;
  final int? serviceCount;
  final int? updateCount;
  final String? serverName;
  final String sourceLabel;
  final IconData sourceIcon;
  final List<String> displayTags;
  final ValueChanged<StackAction> onAction;
  final VoidCallback? onServerTap;
  final VoidCallback? onSourceTap;

  @override
  Widget build(BuildContext context) {
    final config = stack.config;
    final info = stack.info;

    final isRepoDefined =
        !config.filesOnHost &&
        (config.linkedRepo.trim().isNotEmpty || config.repo.trim().isNotEmpty);
    final projectMissing = listItem?.info.projectMissing ?? false;
    final missingCount = info.missingFiles.length;
    final gitOutOfDate =
        isRepoDefined &&
        info.latestHash != null &&
        info.deployedHash != info.latestHash;
    final updates = updateCount ?? 0;
    final runDirectory = config.runDirectory.trim();

    return DetailResourceHeader(
      banner: _banner(
        state: listItem?.info.state,
        projectMissing: projectMissing,
        missingCount: missingCount,
        gitOutOfDate: gitOutOfDate,
        updates: updates,
      ),
      facts: [
        if (config.serverId.isNotEmpty)
          DetailFact(
            icon: AppIcons.server,
            label: 'Server',
            value: serverName ?? config.serverId,
            onTap: onServerTap,
          ),
        DetailFact(
          icon: sourceIcon,
          label: 'Source',
          value: sourceLabel,
          onTap: onSourceTap,
        ),
        if (runDirectory.isNotEmpty)
          DetailFact(
            icon: AppIcons.package,
            label: 'Directory',
            value: _formatDirectory(runDirectory),
            fullValue: runDirectory,
          ),
      ],
      stats: [
        DetailStat(label: 'Services', value: serviceCount?.toString() ?? '—'),
        DetailStat(
          label: 'Image updates',
          value: updateCount?.toString() ?? '—',
          tone: updates > 0 ? PillTone.warning : null,
        ),
        DetailStat(
          label: 'Missing',
          value: missingCount.toString(),
          tone: missingCount > 0 ? PillTone.warning : null,
        ),
      ],
      tags: displayTags,
      description: stack.description,
    );
  }

  Widget? _banner({
    required StackState? state,
    required bool projectMissing,
    required int missingCount,
    required bool gitOutOfDate,
    required int updates,
  }) {
    if (state == StackState.unhealthy) {
      return DetailAttentionBanner(
        icon: AppIcons.error,
        message: 'Stack is unhealthy',
        tone: PillTone.alert,
        actionLabel: 'Restart',
        onAction: () => onAction(StackAction.restart),
      );
    }
    if (projectMissing) {
      return DetailAttentionBanner(
        icon: AppIcons.warning,
        message: 'Compose project is missing',
        actionLabel: 'Deploy',
        onAction: () => onAction(StackAction.redeploy),
      );
    }
    if (missingCount > 0) {
      return DetailAttentionBanner(
        icon: AppIcons.warning,
        message:
            '$missingCount compose file${missingCount == 1 ? '' : 's'} '
            'missing',
      );
    }
    if (gitOutOfDate) {
      return DetailAttentionBanner(
        icon: AppIcons.warning,
        message: 'Repo has new commits',
        actionLabel: 'Deploy',
        onAction: () => onAction(StackAction.deployIfChanged),
      );
    }
    if (updates > 0) {
      return DetailAttentionBanner(
        icon: AppIcons.updateAvailable,
        message: '$updates image update${updates == 1 ? '' : 's'} available',
        actionLabel: 'Redeploy',
        onAction: () => onAction(StackAction.redeploy),
      );
    }
    return null;
  }

  String _formatDirectory(String path) {
    final normalized = path.replaceAll(r'\', '/');
    final parts = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (parts.length <= 2) return normalized;
    return '…/${parts.sublist(parts.length - 2).join('/')}';
  }
}
