import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../data/models/procedure.dart';

/// Card widget displaying procedure information.
class ProcedureCard extends StatelessWidget {
  const ProcedureCard({
    required this.procedure,
    this.onTap,
    this.onRun,
    super.key,
  });

  final ProcedureListItem procedure;
  final VoidCallback? onTap;
  final VoidCallback? onRun;

  @override
  Widget build(BuildContext context) {
    final state = procedure.info.state;
    final stages = procedure.info.stages;
    final scheduleError = procedure.info.scheduleError ?? '';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _StatusBadge(state: state),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      procedure.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      '$stages stages',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                      ),
                    ),
                    if (scheduleError.isNotEmpty) ...[
                      const Gap(4),
                      Text(
                        scheduleError,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (onRun != null)
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: onRun,
                  tooltip: 'Run',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});

  final ProcedureState state;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      ProcedureState.running => (Colors.blue, Icons.sync),
      ProcedureState.ok => (Colors.green, Icons.check_circle),
      ProcedureState.failed => (Colors.red, Icons.error),
      ProcedureState.unknown => (Colors.orange, Icons.help),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const Gap(4),
          Text(
            state.displayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

