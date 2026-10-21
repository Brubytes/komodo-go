import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/empty_state_view.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_ref.dart';
import 'package:komodo_go/shared/resources/providers/resource_name_resolver_provider.dart';

/// Resolves a human readable name for an execution target.
// ignore: specify_nonobvious_property_types
final executionTargetNameProvider = FutureProvider.autoDispose
    .family<String?, ResourceRef>((ref, target) {
      return ref.watch(resourceNameResolverProvider)(target);
    });

/// Parameter keys that reference a target resource, in lookup order.
const _targetKeys = <String, ResourceKind>{
  'stack': ResourceKind.stacks,
  'deployment': ResourceKind.deployments,
  'server': ResourceKind.servers,
  'build': ResourceKind.builds,
  'repo': ResourceKind.repos,
  'procedure': ResourceKind.procedures,
  'action': ResourceKind.actions,
  'sync': ResourceKind.syncs,
};

/// Splits an execution payload into its type and target reference.
({String type, ResourceRef? target, String? rawTarget}) parseExecution(
  Object? execution,
) {
  if (execution is! Map) {
    return (type: 'Execution', target: null, rawTarget: null);
  }
  final type = execution['type']?.toString() ?? 'Execution';
  final params = execution['params'];
  if (params is Map) {
    for (final entry in _targetKeys.entries) {
      final value = params[entry.key];
      if (value is String && value.trim().isNotEmpty) {
        return (
          type: type,
          target: ResourceRef(kind: entry.value, id: value.trim()),
          rawTarget: value.trim(),
        );
      }
    }
  }
  return (type: type, target: null, rawTarget: null);
}

/// Numbered vertical timeline of procedure stages.
class ProcedureStagesTimeline extends StatelessWidget {
  const ProcedureStagesTimeline({required this.stages, super.key});

  final List<ProcedureStage> stages;

  @override
  Widget build(BuildContext context) {
    if (stages.isEmpty) {
      return const EmptyStateView.inline(
        icon: AppIcons.procedures,
        title: 'No stages configured',
        message: 'Configure stages in the Komodo web interface.',
      );
    }
    return Column(
      children: [
        for (var i = 0; i < stages.length; i++)
          _StageNode(
            index: i,
            total: stages.length,
            stage: stages[i],
            isLast: i == stages.length - 1,
          ),
      ],
    );
  }
}

class _StageNode extends StatelessWidget {
  const _StageNode({
    required this.index,
    required this.total,
    required this.stage,
    required this.isLast,
  });

  final int index;
  final int total;
  final ProcedureStage stage;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final muted = !stage.enabled;
    final count = stage.executions.length;
    final railColor = scheme.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: muted
                      ? scheme.surfaceContainerHighest
                      : scheme.primaryContainer,
                  foregroundColor: muted
                      ? scheme.onSurfaceVariant
                      : scheme.onPrimaryContainer,
                  child: Text(
                    '${index + 1}',
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: railColor)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Stage ${index + 1}/$total',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (stage.name.trim().isNotEmpty)
                        Text(
                          stage.name,
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      if (count > 1) TextPill(label: '$count parallel'),
                      if (!stage.enabled) const TextPill(label: 'Disabled'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (count == 0)
                    Text(
                      'No executions',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  else
                    for (final e in stage.executions)
                      _ExecutionRow(execution: e, stageEnabled: stage.enabled),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutionRow extends ConsumerStatefulWidget {
  const _ExecutionRow({required this.execution, required this.stageEnabled});

  final EnabledExecution execution;
  final bool stageEnabled;

  @override
  ConsumerState<_ExecutionRow> createState() => _ExecutionRowState();
}

class _ExecutionRowState extends ConsumerState<_ExecutionRow> {
  var _showJson = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final parsed = parseExecution(widget.execution.execution);
    final target = parsed.target;
    final nameAsync = target == null
        ? null
        : ref.watch(executionTargetNameProvider(target));
    final name = nameAsync?.asData?.value ?? parsed.rawTarget;
    final off = !widget.execution.enabled || !widget.stageEnabled;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: off ? 0.55 : 1,
            child: Row(
              children: [
                TextPill(label: parsed.type),
                const SizedBox(width: AppSpacing.sm),
                if (target != null)
                  Icon(target.kind.icon, size: 14, color: target.kind.color),
                if (target != null) const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    name ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!widget.execution.enabled)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    child: Text(
                      'Off',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                  ),
                  onPressed: () => setState(() => _showJson = !_showJson),
                  child: Text(_showJson ? 'Hide JSON' : 'View JSON'),
                ),
              ],
            ),
          ),
          if (_showJson)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: DetailCodeBlock(
                code: prettyJson(widget.execution.execution),
                maxHeight: 220,
              ),
            ),
        ],
      ),
    );
  }
}

/// Pretty-prints an arbitrary decoded JSON value.
String prettyJson(Object? value) {
  if (value == null) return 'null';
  if (value is String) return value.trim().isEmpty ? '""' : value.trim();
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } on Object {
    return value.toString();
  }
}
