import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';

class StackServiceCard extends StatelessWidget {
  const StackServiceCard({required this.service, super.key});

  final StackService service;

  @override
  Widget build(BuildContext context) {
    final container = service.container;
    final status = container?.status?.trim() ?? '';
    final state = container?.state.trim() ?? '';
    final hasUpdate = service.updateAvailable;

    return DetailSubCard(
      title: service.service,
      icon: hasUpdate ? AppIcons.updateAvailable : AppIcons.widgets,
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasUpdate)
                const StatusPill(
                  label: 'Update available',
                  icon: AppIcons.updateAvailable,
                  tone: PillTone.warning,
                )
              else
                const StatusPill(
                  label: 'Up to date',
                  icon: AppIcons.ok,
                  tone: PillTone.success,
                ),
              if (state.isNotEmpty) ValuePill(label: 'State', value: state),
              if (status.isNotEmpty) ValuePill(label: 'Status', value: status),
            ],
          ),
          if ((container?.image?.trim().isNotEmpty ?? false) ||
              (container?.name.trim().isNotEmpty ?? false)) ...[
            const Gap(12),
            if (container?.name.trim().isNotEmpty ?? false)
              DetailKeyValueRow(
                label: 'Container',
                value: container!.name.trim(),
              ),
            if (container?.image?.trim().isNotEmpty ?? false)
              DetailKeyValueRow(
                label: 'Image',
                value: container!.image!.trim(),
                bottomPadding: 0,
              ),
          ],
        ],
      ),
    );
  }
}
