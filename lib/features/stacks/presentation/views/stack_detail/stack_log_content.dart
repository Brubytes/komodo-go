import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/empty_state_view.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';

class StackLogContent extends StatelessWidget {
  const StackLogContent({required this.log, super.key});

  final StackLog? log;

  @override
  Widget build(BuildContext context) {
    final log = this.log;
    if (log == null) {
      return const EmptyStateView.inline(
        icon: AppIcons.logs,
        title: 'No logs available',
        message: 'Logs will appear here after running stack operations.',
      );
    }

    final output = [
      if (log.stdout.trim().isNotEmpty) log.stdout.trim(),
      if (log.stderr.trim().isNotEmpty) log.stderr.trim(),
    ].join('\n');

    final duration = (log.endTs > 0 && log.startTs > 0)
        ? Duration(milliseconds: log.endTs - log.startTs)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              label: log.success ? 'Success' : 'Failed',
              icon: log.success ? AppIcons.ok : AppIcons.error,
              tone: log.success ? PillTone.success : PillTone.alert,
            ),
            if (duration != null)
              ValuePill(label: 'Duration', value: '${duration.inSeconds}s'),
          ],
        ),
        const Gap(14),
        if (log.command.isNotEmpty) ...[
          DetailKeyValueRow(label: 'Command', value: log.command),
          const Gap(10),
        ],
        DetailCodeBlock(
          code: output.isNotEmpty ? output : 'No output',
          tabletMaxHeight: 560,
        ),
      ],
    );
  }
}
