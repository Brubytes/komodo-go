import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';

class StackHeroPanel extends StatelessWidget {
  const StackHeroPanel({
    required this.stack,
    required this.listItem,
    required this.serviceCount,
    required this.updateCount,
    required this.serverName,
    required this.sourceLabel,
    required this.sourceIcon,
    required this.displayTags,
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final config = stack.config;
    final info = stack.info;

    final isRepoDefined =
        !config.filesOnHost &&
        (config.linkedRepo.trim().isNotEmpty || config.repo.trim().isNotEmpty);

    final state = listItem?.info.state;
    final projectMissing = listItem?.info.projectMissing ?? false;

    final missingCount = info.missingFiles.length;
    final hasGitMeta = info.latestHash != null || info.deployedHash != null;
    final upToDate =
        info.latestHash != null && info.deployedHash == info.latestHash;
    final description = stack.description.trim();
    final serverLabel = serverName ?? config.serverId;
    final runDirectory = config.runDirectory.trim();
    final directoryLabel = _formatDirectory(runDirectory);
    final metrics = <DetailMetricTileData>[
      DetailMetricTileData(
        icon: _stateIcon(state),
        label: 'State',
        value: state?.displayName ?? '—',
        tone: _stateTone(state),
      ),
      DetailMetricTileData(
        icon: sourceIcon,
        label: 'Source',
        value: sourceLabel,
        tone: DetailMetricTone.neutral,
      ),
      if (config.serverId.isNotEmpty)
        DetailMetricTileData(
          icon: AppIcons.server,
          label: 'Server',
          value: serverLabel,
          tone: DetailMetricTone.neutral,
        ),
      if (runDirectory.isNotEmpty)
        DetailMetricTileData(
          icon: AppIcons.package,
          label: 'Directory',
          value: directoryLabel,
          tone: DetailMetricTone.neutral,
        ),
      DetailMetricTileData(
        icon: AppIcons.widgets,
        label: 'Services',
        value: serviceCount?.toString() ?? '—',
        tone: DetailMetricTone.neutral,
      ),
      DetailMetricTileData(
        icon: AppIcons.updateAvailable,
        label: 'Updates',
        value: updateCount?.toString() ?? '—',
        tone: (updateCount ?? 0) > 0
            ? DetailMetricTone.tertiary
            : DetailMetricTone.success,
      ),
      DetailMetricTileData(
        icon: AppIcons.warning,
        label: 'Missing',
        value: missingCount.toString(),
        tone: missingCount > 0
            ? DetailMetricTone.tertiary
            : DetailMetricTone.success,
      ),
      if (isRepoDefined)
        DetailMetricTileData(
          icon: !hasGitMeta
              ? AppIcons.widgets
              : (upToDate ? AppIcons.ok : AppIcons.warning),
          label: 'Git',
          value: !hasGitMeta ? '—' : (upToDate ? 'Up to date' : 'Out of date'),
          tone: !hasGitMeta
              ? DetailMetricTone.neutral
              : (upToDate
                    ? DetailMetricTone.success
                    : DetailMetricTone.tertiary),
        ),
    ];

    return DetailHeroPanel(
      tintColor: scheme.surface,
      metrics: metrics,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailPillList(
            items: displayTags,
            showEmptyLabel: false,
            leading: [
              if (projectMissing)
                const StatusPill(
                  label: 'Project missing',
                  icon: AppIcons.warning,
                  tone: PillTone.warning,
                ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const Gap(12),
            Text(
              'Description',
              style: textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(6),
            Text(description, style: textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  IconData _stateIcon(StackState? state) {
    return switch (state) {
      StackState.running => AppIcons.ok,
      StackState.deploying || StackState.restarting => AppIcons.loading,
      StackState.unhealthy => AppIcons.error,
      StackState.stopped ||
      StackState.created ||
      StackState.down ||
      StackState.dead => AppIcons.stopped,
      StackState.paused => AppIcons.paused,
      StackState.removing => AppIcons.warning,
      _ => AppIcons.unknown,
    };
  }

  DetailMetricTone _stateTone(StackState? state) {
    return switch (state) {
      StackState.running => DetailMetricTone.success,
      StackState.deploying || StackState.restarting => DetailMetricTone.primary,
      StackState.unhealthy => DetailMetricTone.alert,
      StackState.stopped ||
      StackState.created ||
      StackState.down ||
      StackState.dead => DetailMetricTone.neutral,
      StackState.paused => DetailMetricTone.secondary,
      _ => DetailMetricTone.neutral,
    };
  }

  String _formatDirectory(String path) {
    if (path.isEmpty) return path;
    final normalized = path.replaceAll(r'\', '/');
    final parts = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (parts.isEmpty) return path;
    if (parts.length <= 2) return normalized;
    final tail = parts.sublist(parts.length - 2).join('/');
    return '…/$tail';
  }
}
