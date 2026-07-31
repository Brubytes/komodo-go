import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';

class StackDeploymentContent extends StatelessWidget {
  const StackDeploymentContent({
    required this.info,
    required this.isRepoDefined,
    super.key,
  });

  final StackInfo info;
  final bool isRepoDefined;

  @override
  Widget build(BuildContext context) {
    final latest = info.latestHash;
    final deployed = info.deployedHash;

    final upToDate = latest != null && deployed == latest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (isRepoDefined)
              StatusPill(
                label: upToDate ? 'Up to date' : 'Out of date',
                icon: upToDate ? AppIcons.ok : AppIcons.warning,
                tone: upToDate ? PillTone.success : PillTone.warning,
              ),
            if (info.missingFiles.isNotEmpty)
              StatusPill(
                label: '${info.missingFiles.length} missing files',
                icon: AppIcons.warning,
                tone: PillTone.warning,
              ),
          ],
        ),
        if (isRepoDefined) ...[
          const Gap(14),
          DetailSubCard(
            title: 'Commits',
            icon: AppIcons.repos,
            child: Column(
              children: [
                DetailKeyValueRow(
                  label: 'Latest',
                  value: _shortHash(latest) ?? '—',
                ),
                if (info.latestMessage?.trim().isNotEmpty ?? false)
                  DetailKeyValueRow(
                    label: 'Message',
                    value: info.latestMessage!.trim(),
                  ),
                DetailKeyValueRow(
                  label: 'Deployed',
                  value: _shortHash(deployed) ?? '—',
                ),
                if (info.deployedMessage?.trim().isNotEmpty ?? false)
                  DetailKeyValueRow(
                    label: 'Message',
                    value: info.deployedMessage!.trim(),
                    bottomPadding: 0,
                  )
                else
                  const DetailKeyValueRow(
                    label: 'Message',
                    value: '—',
                    bottomPadding: 0,
                  ),
              ],
            ),
          ),
        ],
        if (info.missingFiles.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Missing files',
            icon: AppIcons.warning,
            child: DetailPillList(
              items: info.missingFiles,
              emptyLabel: 'No missing files',
            ),
          ),
        ],
      ],
    );
  }

  String? _shortHash(String? value) {
    if (value == null) return null;
    final v = value.trim();
    if (v.isEmpty) return null;
    return v.length > 8 ? v.substring(0, 8) : v;
  }
}
