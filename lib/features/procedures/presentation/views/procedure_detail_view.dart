import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

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
    final actionsState = ref.watch(procedureActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(procedureName),
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
              padding: const EdgeInsets.all(16),
              children: [
                procedureAsync.when(
                  data: (procedure) => procedure != null
                      ? _ProcedureInfoCard(procedure: procedure)
                      : const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Procedure not found'),
                          ),
                        ),
                  loading: () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (error, _) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error: $error'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (actionsState.isLoading)
            Container(
              color: Colors.black26,
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
      ref.invalidate(procedureDetailProvider(procedureId));
      ref.invalidate(proceduresProvider);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Procedure started'
                : 'Action failed. Please try again.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}

class _ProcedureInfoCard extends StatelessWidget {
  const _ProcedureInfoCard({required this.procedure});

  final KomodoProcedure procedure;

  @override
  Widget build(BuildContext context) {
    final config = procedure.config;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Procedure',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(16),
            _InfoRow(label: 'Name', value: procedure.name),
            _InfoRow(label: 'Stages', value: config.stages.length.toString()),
            _InfoRow(
              label: 'Schedule',
              value: config.scheduleEnabled
                  ? (config.schedule.isNotEmpty ? config.schedule : 'Enabled')
                  : 'Disabled',
            ),
            _InfoRow(
              label: 'Webhook',
              value: config.webhookEnabled ? 'Enabled' : 'Disabled',
            ),
            const Gap(12),
            Text(
              'Stages',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(8),
            if (config.stages.isEmpty)
              const Text('No stages configured')
            else
              Column(
                children: config.stages
                    .map((stage) => _StageTile(stage: stage))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _StageTile extends StatelessWidget {
  const _StageTile({required this.stage});

  final ProcedureStage stage;

  @override
  Widget build(BuildContext context) {
    final enabledExecutions =
        stage.executions.where((e) => e.enabled).length;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(stage.enabled ? AppIcons.ok : AppIcons.canceled),
        title: Text(stage.name.isNotEmpty ? stage.name : 'Stage'),
        subtitle: Text('$enabledExecutions executions enabled'),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: 0.7,
                    ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
