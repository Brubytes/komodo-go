import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';

import '../../data/models/procedure.dart';
import '../providers/procedures_provider.dart';

/// View displaying detailed procedure information.
class ProcedureDetailView extends ConsumerWidget {
  const ProcedureDetailView({
    required this.procedureId,
    required this.procedureName,
    super.key,
  });

  final String procedureId;
  final String procedureName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final procedureAsync = ref.watch(procedureDetailProvider(procedureId));
    final proceduresListAsync = ref.watch(proceduresProvider);
    final actionsState = ref.watch(procedureActionsProvider);
    final scheme = Theme.of(context).colorScheme;

    ProcedureListItem? listItem;
    final list = proceduresListAsync.asData?.value;
    if (list != null) {
      for (final item in list) {
        if (item.id == procedureId) {
          listItem = item;
          break;
        }
      }
    }

    return Scaffold(
      appBar: MainAppBar(
        title: procedureName,
        icon: AppIcons.procedures,
        markColor: AppTokens.resourceProcedures,
        markUseGradient: true,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(AppIcons.play),
            tooltip: 'Run',
            onPressed: () => _runProcedure(context, ref, procedureId),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(procedureDetailProvider(procedureId));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                procedureAsync.when(
                  data: (procedure) {
                    if (procedure == null) {
                      return const _MessageSurface(
                        message: 'Procedure not found',
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ProcedureHeroPanel(
                          procedure: procedure,
                          listItem: listItem,
                        ),
                        const Gap(16),
                        DetailSection(
                          title: 'Configuration',
                          icon: AppIcons.settings,
                          child: _ProcedureConfigContent(
                            procedure: procedure,
                            listItem: listItem,
                          ),
                        ),
                        const Gap(16),
                        DetailSection(
                          title: 'Stages',
                          icon: AppIcons.stacks,
                          child: _ProcedureStagesContent(
                            config: procedure.config,
                          ),
                        ),
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

  Future<void> _runProcedure(
    BuildContext context,
    WidgetRef ref,
    String procedureId,
  ) async {
    final actions = ref.read(procedureActionsProvider.notifier);
    final success = await actions.run(procedureId);

    if (success) {
      ref
        ..invalidate(procedureDetailProvider(procedureId))
        ..invalidate(proceduresProvider);
    }

    if (context.mounted) {
      AppSnackBar.show(
        context,
        success ? 'Procedure started' : 'Action failed. Please try again.',
        tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
      );
    }
  }
}

class _ProcedureHeroPanel extends StatelessWidget {
  const _ProcedureHeroPanel({required this.procedure, required this.listItem});

  final KomodoProcedure procedure;
  final ProcedureListItem? listItem;

  @override
  Widget build(BuildContext context) {
    final status = listItem?.info.state;
    final stagesCount = procedure.config.stages.length;

    return DetailHeroPanel(
      header: _ProcedureHeader(procedure: procedure),
      metrics: [
        if (status != null)
          DetailMetricTileData(
            label: 'Status',
            value: status.displayName,
            icon: switch (status) {
              ProcedureState.ok => AppIcons.ok,
              ProcedureState.failed => AppIcons.error,
              ProcedureState.running => AppIcons.loading,
              ProcedureState.unknown => AppIcons.unknown,
            },
            tone: switch (status) {
              ProcedureState.ok => DetailMetricTone.success,
              ProcedureState.failed => DetailMetricTone.alert,
              ProcedureState.running => DetailMetricTone.neutral,
              ProcedureState.unknown => DetailMetricTone.neutral,
            },
          ),
        DetailMetricTileData(
          label: 'Stages',
          value: stagesCount.toString(),
          icon: AppIcons.stacks,
          tone: DetailMetricTone.neutral,
        ),
        if (listItem?.info.lastRunAt != null)
          DetailMetricTileData(
            label: 'Last Run',
            value: _formatTimestampSeconds(listItem!.info.lastRunAt!),
            icon: AppIcons.clock,
            tone: DetailMetricTone.neutral,
          ),
        if (procedure.config.scheduleEnabled)
          DetailMetricTileData(
            label: 'Schedule',
            value: procedure.config.schedule.isNotEmpty
                ? procedure.config.schedule
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

class _ProcedureHeader extends StatelessWidget {
  const _ProcedureHeader({required this.procedure});

  final KomodoProcedure procedure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = procedure.description.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          procedure.name,
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

class _ProcedureConfigContent extends StatelessWidget {
  const _ProcedureConfigContent({
    required this.procedure,
    required this.listItem,
  });

  final KomodoProcedure procedure;
  final ProcedureListItem? listItem;

  @override
  Widget build(BuildContext context) {
    final config = procedure.config;
    final scheduleError = listItem?.info.scheduleError?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
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
      ],
    );
  }
}

class _ProcedureStagesContent extends StatelessWidget {
  const _ProcedureStagesContent({required this.config});

  final ProcedureConfig config;

  @override
  Widget build(BuildContext context) {
    if (config.stages.isEmpty) {
      return const Text('No stages configured');
    }

    return Column(
      children: [
        for (final stage in config.stages) ...[
          _StageCard(stage: stage),
          if (stage != config.stages.last) const Gap(12),
        ],
      ],
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.stage});

  final ProcedureStage stage;

  @override
  Widget build(BuildContext context) {
    final enabledExecutions = stage.executions.where((e) => e.enabled).length;
    final totalExecutions = stage.executions.length;

    return DetailSubCard(
      title: stage.name.isNotEmpty ? stage.name : 'Stage',
      icon: AppIcons.stacks,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill.onOff(
                isOn: stage.enabled,
                onLabel: 'Enabled',
                offLabel: 'Disabled',
                onIcon: AppIcons.ok,
                offIcon: AppIcons.canceled,
              ),
              TextPill(
                label: '$enabledExecutions/$totalExecutions executions',
                tone: PillTone.neutral,
              ),
            ],
          ),
          if (totalExecutions > 0) ...[
            const Gap(12),
            for (var i = 0; i < stage.executions.length; i++) ...[
              _ExecutionBlock(index: i, execution: stage.executions[i]),
              if (i != stage.executions.length - 1) const Gap(12),
            ],
          ],
        ],
      ),
    );
  }
}

class _ExecutionBlock extends StatelessWidget {
  const _ExecutionBlock({required this.index, required this.execution});

  final int index;
  final EnabledExecution execution;

  @override
  Widget build(BuildContext context) {
    final label = 'Execution ${index + 1}';
    final code = _pretty(execution.execution);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Gap(8),
            StatusPill.onOff(
              isOn: execution.enabled,
              onLabel: 'On',
              offLabel: 'Off',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.pause,
            ),
          ],
        ),
        const Gap(8),
        DetailCodeBlock(code: code, maxHeight: 220),
      ],
    );
  }
}

String _pretty(Object? value) {
  if (value == null) return 'null';
  if (value is String) return value.trim().isEmpty ? '""' : value.trim();
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } catch (_) {
    return value.toString();
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
