import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/empty_error_state.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/notifications/data/models/resource_target.dart';
import 'package:komodo_go/features/notifications/data/models/update_detail.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';
import 'package:komodo_go/features/notifications/presentation/providers/target_display_name_provider.dart';
import 'package:komodo_go/features/notifications/presentation/providers/updates_provider.dart';
import 'package:komodo_go/features/notifications/presentation/utils/alert_navigation_utils.dart';

class UpdateDetailView extends ConsumerWidget {
  const UpdateDetailView({required this.updateId, super.key});

  final String updateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateAsync = ref.watch(updateDetailProvider(updateId));
    return Scaffold(
      appBar: const MainAppBar(
        title: 'Update details',
        icon: AppIcons.history,
        markColor: AppTokens.resourceStacks,
        markUseGradient: true,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(updateDetailProvider(updateId));
          await ref.read(updateDetailProvider(updateId).future);
        },
        child: updateAsync.when(
          data: (update) => update == null
              ? _scrollableMessage('Update not found')
              : _UpdateDetailContent(update: update),
          loading: () => const AppSkeletonList(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
          ),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ErrorStateView(
                title: 'Failed to load update',
                message: error.toString(),
                onRetry: () => ref.invalidate(updateDetailProvider(updateId)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scrollableMessage(String message) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Gap(72),
        const Icon(AppIcons.history, size: 56),
        const Gap(16),
        Center(child: Text(message)),
      ],
    );
  }
}

class _UpdateDetailContent extends ConsumerWidget {
  const _UpdateDetailContent({required this.update});

  final UpdateDetail update;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = update.target;
    final targetRoute = routeForTarget(target);
    final targetName = target == null
        ? 'System'
        : ref
              .watch(targetDisplayNameProvider(target))
              .maybeWhen(
                data: (value) => value,
                orElse: () => target.displayName,
              );

    return ListView(
      key: const ValueKey('update_detail_content'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        DetailHeroPanel(
          metrics: [
            DetailMetricTileData(
              icon: _statusIcon(update.status),
              label: 'Status',
              value: _statusLabel(update.status, update.success),
              tone: _statusTone(update.status, update.success),
            ),
            DetailMetricTileData(
              icon: _targetIcon(target?.type),
              label: 'Target',
              value: targetName,
              tone: DetailMetricTone.neutral,
            ),
            DetailMetricTileData(
              icon: AppIcons.clock,
              label: 'Started',
              value: _formatDateTime(update.startedAt),
              tone: DetailMetricTone.neutral,
            ),
            DetailMetricTileData(
              icon: AppIcons.activity,
              label: 'Duration',
              value: _formatDuration(update.duration),
              tone: DetailMetricTone.neutral,
            ),
          ],
          footer: targetRoute == null
              ? null
              : Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('open_update_target'),
                    onPressed: () => context.push(targetRoute),
                    icon: const Icon(AppIcons.externalLink),
                    label: const Text('Open resource'),
                  ),
                ),
        ),
        const Gap(16),
        DetailSection(
          title: 'Summary',
          icon: AppIcons.info,
          child: Column(
            children: [
              DetailKeyValueRow(
                label: 'Operation',
                value: _humanize(update.operation),
              ),
              DetailKeyValueRow(
                label: 'Operator',
                value: update.operatorName.trim().isEmpty
                    ? '—'
                    : update.operatorName,
              ),
              DetailKeyValueRow(
                label: 'Version',
                value: update.version.label,
              ),
              DetailKeyValueRow(
                label: 'Update ID',
                value: update.id,
              ),
              if (update.commitHash.trim().isNotEmpty)
                DetailKeyValueRow(
                  label: 'Commit',
                  value: update.commitHash,
                ),
              if (update.endedAt case final endedAt?)
                DetailKeyValueRow(
                  label: 'Ended',
                  value: _formatDateTime(endedAt),
                  bottomPadding: 0,
                ),
            ],
          ),
        ),
        const Gap(16),
        DetailSection(
          title: 'Execution logs',
          icon: AppIcons.logs,
          child: update.logs.isEmpty
              ? const Text('No execution logs were recorded.')
              : Column(
                  children: [
                    for (
                      var index = 0;
                      index < update.logs.length;
                      index++
                    ) ...[
                      _UpdateLogCard(log: update.logs[index], index: index),
                      if (index < update.logs.length - 1) const Gap(12),
                    ],
                  ],
                ),
        ),
        if (update.otherData.trim().isNotEmpty) ...[
          const Gap(16),
          DetailSection(
            title: 'Additional data',
            icon: AppIcons.notepadText,
            child: DetailCodeBlock(code: update.otherData),
          ),
        ],
        if (update.previousToml.trim().isNotEmpty ||
            update.currentToml.trim().isNotEmpty) ...[
          const Gap(16),
          DetailSection(
            title: 'Configuration change',
            icon: AppIcons.code,
            child: Column(
              children: [
                if (update.previousToml.trim().isNotEmpty)
                  DetailSubCard(
                    title: 'Previous TOML',
                    icon: AppIcons.history,
                    child: DetailCodeBlock(code: update.previousToml),
                  ),
                if (update.previousToml.trim().isNotEmpty &&
                    update.currentToml.trim().isNotEmpty)
                  const Gap(12),
                if (update.currentToml.trim().isNotEmpty)
                  DetailSubCard(
                    title: 'Current TOML',
                    icon: AppIcons.check,
                    child: DetailCodeBlock(code: update.currentToml),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _UpdateLogCard extends StatelessWidget {
  const _UpdateLogCard({required this.log, required this.index});

  final UpdateLog log;
  final int index;

  @override
  Widget build(BuildContext context) {
    final title = log.stage.trim().isEmpty ? 'Stage ${index + 1}' : log.stage;
    return DetailSubCard(
      title: title,
      icon: log.success ? AppIcons.ok : AppIcons.error,
      tintColor: log.success
          ? Theme.of(context).colorScheme.secondary
          : Theme.of(context).colorScheme.error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailKeyValueRow(
            label: 'Result',
            value: log.success ? 'Success' : 'Failed',
          ),
          DetailKeyValueRow(
            label: 'Duration',
            value: _formatDuration(log.duration),
          ),
          if (log.command.trim().isNotEmpty) ...[
            const Text('Command'),
            const Gap(6),
            DetailCodeBlock(code: log.command, maxHeight: 160),
          ],
          if (log.stdout.trim().isNotEmpty) ...[
            const Gap(12),
            const Text('Standard output'),
            const Gap(6),
            DetailCodeBlock(code: log.stdout),
          ],
          if (log.stderr.trim().isNotEmpty) ...[
            const Gap(12),
            Text(
              'Standard error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const Gap(6),
            DetailCodeBlock(code: log.stderr),
          ],
        ],
      ),
    );
  }
}

String _humanize(String value) {
  final spaced = value.replaceAllMapped(
    RegExp('(?<=[a-z0-9])(?=[A-Z])'),
    (_) => ' ',
  );
  return spaced.isEmpty ? 'Update' : spaced;
}

String _statusLabel(UpdateStatus status, bool success) {
  return switch (status) {
    UpdateStatus.queued => 'Queued',
    UpdateStatus.running => 'Running',
    UpdateStatus.success => 'Success',
    UpdateStatus.failed => 'Failed',
    UpdateStatus.canceled => 'Canceled',
    UpdateStatus.unknown => success ? 'Success' : 'Unknown',
  };
}

IconData _statusIcon(UpdateStatus status) {
  return switch (status) {
    UpdateStatus.queued => AppIcons.waiting,
    UpdateStatus.running => AppIcons.loading,
    UpdateStatus.success => AppIcons.ok,
    UpdateStatus.failed => AppIcons.error,
    UpdateStatus.canceled => AppIcons.canceled,
    UpdateStatus.unknown => AppIcons.unknown,
  };
}

DetailMetricTone _statusTone(UpdateStatus status, bool success) {
  return switch (status) {
    UpdateStatus.success => DetailMetricTone.success,
    UpdateStatus.failed => DetailMetricTone.alert,
    UpdateStatus.queued || UpdateStatus.running => DetailMetricTone.tertiary,
    UpdateStatus.canceled => DetailMetricTone.neutral,
    UpdateStatus.unknown =>
      success ? DetailMetricTone.success : DetailMetricTone.neutral,
  };
}

IconData _targetIcon(ResourceTargetType? type) {
  return switch (type) {
    ResourceTargetType.server => AppIcons.server,
    ResourceTargetType.stack => AppIcons.stacks,
    ResourceTargetType.deployment => AppIcons.deployments,
    ResourceTargetType.build => AppIcons.builds,
    ResourceTargetType.repo => AppIcons.repos,
    ResourceTargetType.procedure => AppIcons.procedures,
    ResourceTargetType.action => AppIcons.actions,
    ResourceTargetType.resourceSync => AppIcons.syncs,
    ResourceTargetType.builder => AppIcons.factory,
    ResourceTargetType.alerter => AppIcons.notifications,
    ResourceTargetType.system ||
    ResourceTargetType.unknown ||
    null => AppIcons.widgets,
  };
}

String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final date =
      '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}:'
      '${local.second.toString().padLeft(2, '0')}';
  return '$date $time';
}

String _formatDuration(Duration? duration) {
  if (duration == null) return 'In progress';
  if (duration.inMinutes > 0) {
    final seconds = duration.inSeconds.remainder(60);
    return '${duration.inMinutes}m ${seconds}s';
  }
  if (duration.inSeconds > 0) {
    return '${duration.inSeconds}.${duration.inMilliseconds.remainder(1000).toString().padLeft(3, '0')}s';
  }
  return '${duration.inMilliseconds}ms';
}
