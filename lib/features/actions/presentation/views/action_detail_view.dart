import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';

import '../../data/models/action.dart';
import '../providers/actions_provider.dart';

/// View displaying detailed action information.
class ActionDetailView extends ConsumerWidget {
  const ActionDetailView({
    required this.actionId,
    required this.actionName,
    super.key,
  });

  final String actionId;
  final String actionName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionAsync = ref.watch(actionDetailProvider(actionId));
    final actionsListAsync = ref.watch(actionsProvider);
    final actionsState = ref.watch(actionActionsProvider);
    final scheme = Theme.of(context).colorScheme;

    ActionListItem? listItem;
    final list = actionsListAsync.asData?.value;
    if (list != null) {
      for (final item in list) {
        if (item.id == actionId) {
          listItem = item;
          break;
        }
      }
    }

    return Scaffold(
      appBar: MainAppBar(
        title: actionName,
        icon: AppIcons.actions,
        markColor: AppTokens.resourceActions,
        markUseGradient: true,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(AppIcons.play),
            tooltip: 'Run',
            onPressed: () => _runAction(context, ref, actionId),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(actionDetailProvider(actionId));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                actionAsync.when(
                  data: (action) {
                    if (action == null) {
                      return const _MessageSurface(message: 'Action not found');
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ActionHeroPanel(action: action, listItem: listItem),
                        const Gap(16),
                        DetailSection(
                          title: 'Configuration',
                          icon: AppIcons.settings,
                          child: _ActionConfigContent(
                            action: action,
                            listItem: listItem,
                          ),
                        ),
                        if (action.config.arguments.trim().isNotEmpty ||
                            action.config.fileContents.trim().isNotEmpty) ...[
                          const Gap(16),
                          DetailSection(
                            title: 'Script',
                            icon: AppIcons.package,
                            child: _ActionScriptContent(config: action.config),
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => const _LoadingSurface(),
                  error: (error, _) => _ErrorSurface(error: error.toString()),
                ),
              ],
            ),
          ),
          if (actionsState.isLoading)
            ColoredBox(
              color: scheme.scrim.withValues(alpha: 0.25),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _runAction(
    BuildContext context,
    WidgetRef ref,
    String actionId,
  ) async {
    final actions = ref.read(actionActionsProvider.notifier);
    final success = await actions.run(actionId);

    if (success) {
      ref
        ..invalidate(actionDetailProvider(actionId))
        ..invalidate(actionsProvider);
    }

    if (context.mounted) {
      final scheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Action started' : 'Action failed. Please try again.',
          ),
          backgroundColor: success
              ? scheme.secondaryContainer
              : scheme.errorContainer,
        ),
      );
    }
  }
}

class _ActionHeroPanel extends StatelessWidget {
  const _ActionHeroPanel({required this.action, required this.listItem});

  final KomodoAction action;
  final ActionListItem? listItem;

  @override
  Widget build(BuildContext context) {
    final status = listItem?.info.state;

    return DetailHeroPanel(
      header: _ActionHeader(action: action),
      metrics: [
        if (status != null)
          DetailMetricTileData(
            label: 'Status',
            value: status.displayName,
            icon: switch (status) {
              ActionState.ok => AppIcons.ok,
              ActionState.failed => AppIcons.error,
              ActionState.running => AppIcons.loading,
              ActionState.unknown => AppIcons.unknown,
            },
            tone: switch (status) {
              ActionState.ok => DetailMetricTone.success,
              ActionState.failed => DetailMetricTone.alert,
              ActionState.running => DetailMetricTone.neutral,
              ActionState.unknown => DetailMetricTone.neutral,
            },
          ),
        DetailMetricTileData(
          label: 'Startup',
          value: action.config.runAtStartup ? 'On' : 'Off',
          icon: action.config.runAtStartup ? AppIcons.ok : AppIcons.pause,
          tone: action.config.runAtStartup
              ? DetailMetricTone.success
              : DetailMetricTone.neutral,
        ),
        if (listItem?.info.lastRunAt != null)
          DetailMetricTileData(
            label: 'Last Run',
            value: _formatTimestampSeconds(listItem!.info.lastRunAt!),
            icon: AppIcons.clock,
            tone: DetailMetricTone.neutral,
          ),
        if (action.config.scheduleEnabled)
          DetailMetricTileData(
            label: 'Schedule',
            value: action.config.schedule.isNotEmpty
                ? action.config.schedule
                : 'Enabled',
            icon: AppIcons.clock,
            tone: DetailMetricTone.tertiary,
          )
        else
          const DetailMetricTileData(
            label: 'Schedule',
            value: 'Off',
            icon: AppIcons.pause,
            tone: DetailMetricTone.neutral,
          ),
      ],
    );
  }
}

class _ActionHeader extends StatelessWidget {
  const _ActionHeader({required this.action});

  final KomodoAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = action.description.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          action.name,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (description.isNotEmpty) ...[
          const Gap(4),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionConfigContent extends StatelessWidget {
  const _ActionConfigContent({required this.action, required this.listItem});

  final KomodoAction action;
  final ActionListItem? listItem;

  @override
  Widget build(BuildContext context) {
    final config = action.config;
    final scheduleError = listItem?.info.scheduleError?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill.onOff(
              isOn: config.runAtStartup,
              onLabel: 'Startup on',
              offLabel: 'Startup off',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.pause,
            ),
            StatusPill.onOff(
              isOn: config.scheduleEnabled,
              onLabel: 'Schedule on',
              offLabel: 'Schedule off',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.pause,
            ),
            StatusPill.onOff(
              isOn: config.webhookEnabled,
              onLabel: 'Webhook on',
              offLabel: 'Webhook off',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.pause,
            ),
            StatusPill.onOff(
              isOn: config.reloadDenoDeps,
              onLabel: 'Reload deps',
              offLabel: 'No reload',
              onIcon: AppIcons.refresh,
              offIcon: AppIcons.pause,
            ),
            StatusPill.onOff(
              isOn: config.scheduleAlert,
              onLabel: 'Schedule alerts',
              offLabel: 'No schedule alerts',
              onIcon: AppIcons.notifications,
              offIcon: AppIcons.notifications,
            ),
            StatusPill.onOff(
              isOn: config.failureAlert,
              onLabel: 'Failure alerts',
              offLabel: 'No failure alerts',
              onIcon: AppIcons.warning,
              offIcon: AppIcons.ok,
            ),
          ],
        ),
        const Gap(14),
        DetailSubCard(
          title: 'Schedule',
          icon: AppIcons.clock,
          child: Column(
            children: [
              DetailKeyValueRow(
                label: 'Enabled',
                value: config.scheduleEnabled ? 'Yes' : 'No',
              ),
              DetailKeyValueRow(
                label: 'Format',
                value: config.scheduleFormat.name.toUpperCase(),
              ),
              DetailKeyValueRow(
                label: 'Timezone',
                value: config.scheduleTimezone.isNotEmpty
                    ? config.scheduleTimezone
                    : '—',
              ),
              DetailKeyValueRow(
                label: 'Expression',
                value: config.schedule.isNotEmpty ? config.schedule : '—',
              ),
              if (listItem?.info.nextScheduledRun != null)
                DetailKeyValueRow(
                  label: 'Next run',
                  value: _formatTimestampSeconds(
                    listItem!.info.nextScheduledRun!,
                  ),
                ),
              if (scheduleError.isNotEmpty)
                DetailKeyValueRow(
                  label: 'Schedule error',
                  value: scheduleError,
                  bottomPadding: 0,
                )
              else
                const DetailKeyValueRow(
                  label: 'Schedule error',
                  value: '—',
                  bottomPadding: 0,
                ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Webhook',
          icon: AppIcons.network,
          child: Column(
            children: [
              DetailKeyValueRow(
                label: 'Enabled',
                value: config.webhookEnabled ? 'Yes' : 'No',
              ),
              DetailKeyValueRow(
                label: 'Secret',
                value: config.webhookSecret.isNotEmpty ? 'Configured' : '—',
                bottomPadding: 0,
              ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Arguments',
          icon: AppIcons.tag,
          child: Column(
            children: [
              DetailKeyValueRow(
                label: 'Format',
                value: config.argumentsFormat.displayName,
                bottomPadding: 0,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionScriptContent extends StatelessWidget {
  const _ActionScriptContent({required this.config});

  final ActionConfig config;

  @override
  Widget build(BuildContext context) {
    final args = config.arguments.trim();
    final file = config.fileContents.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (args.isNotEmpty) ...[
          Text(
            'Arguments',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Gap(8),
          DetailCodeBlock(code: args, maxHeight: 220),
        ],
        if (args.isNotEmpty && file.isNotEmpty) const Gap(16),
        if (file.isNotEmpty) ...[
          Text(
            'File contents',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Gap(8),
          DetailCodeBlock(
            code: file,
            language: DetailCodeLanguage.typescript,
            maxHeight: 420,
          ),
        ],
      ],
    );
  }
}

String _formatTimestampSeconds(int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
  return 'Just now';
}

class _MessageSurface extends StatelessWidget {
  const _MessageSurface({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DetailSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(child: Text(message)),
      ),
    );
  }
}

class _LoadingSurface extends StatelessWidget {
  const _LoadingSurface();

  @override
  Widget build(BuildContext context) {
    return const DetailSurface(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorSurface extends StatelessWidget {
  const _ErrorSurface({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return DetailSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $error'),
      ),
    );
  }
}
