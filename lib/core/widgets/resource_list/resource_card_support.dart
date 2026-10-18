import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_action_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Shared group labels so every resource card menu reads the same.
abstract final class ResourceMenuGroups {
  static const lifecycle = 'Lifecycle';
  static const maintenance = 'Maintenance';
}

/// Shared labels/icons for actions that exist on several resource types.
abstract final class ResourceMenuItems {
  static DetailActionItem start(VoidCallback onSelected) => DetailActionItem(
    label: 'Start',
    icon: AppIcons.play,
    onSelected: onSelected,
  );

  static DetailActionItem stop(VoidCallback onSelected) => DetailActionItem(
    label: 'Stop',
    icon: AppIcons.stop,
    onSelected: onSelected,
  );

  static DetailActionItem restart(VoidCallback onSelected) => DetailActionItem(
    label: 'Restart',
    icon: AppIcons.refresh,
    onSelected: onSelected,
  );

  static DetailActionItem pause(VoidCallback onSelected) => DetailActionItem(
    label: 'Pause',
    icon: AppIcons.pause,
    onSelected: onSelected,
  );

  static DetailActionItem unpause(VoidCallback onSelected) => DetailActionItem(
    label: 'Unpause',
    icon: AppIcons.play,
    onSelected: onSelected,
  );

  static DetailActionItem pullImages(VoidCallback onSelected) =>
      DetailActionItem(
        label: 'Pull images',
        icon: AppIcons.download,
        onSelected: onSelected,
      );

  static DetailActionItem checkUpdates(VoidCallback onSelected) =>
      DetailActionItem(
        label: 'Check for updates',
        icon: AppIcons.updateAvailable,
        onSelected: onSelected,
      );

  static DetailActionItem deployIfChanged(VoidCallback onSelected) =>
      DetailActionItem(
        label: 'Deploy if changed',
        icon: AppIcons.deployments,
        onSelected: onSelected,
      );

  static DetailActionItem redeploy(
    VoidCallback onSelected, {
    String label = 'Redeploy',
  }) => DetailActionItem(
    label: label,
    icon: AppIcons.deployments,
    onSelected: onSelected,
  );

  static DetailActionItem destroy(
    VoidCallback onSelected, {
    String label = 'Destroy',
  }) => DetailActionItem(
    label: label,
    icon: AppIcons.delete,
    onSelected: onSelected,
    destructive: true,
  );
}

/// Builds the grouped card menu: Lifecycle, Maintenance, then Danger
/// (destructive items are rendered last, after a divider, by the menu itself).
List<DetailActionGroup> resourceMenuGroups({
  List<DetailActionItem> lifecycle = const [],
  List<DetailActionItem> maintenance = const [],
  List<DetailActionItem> danger = const [],
}) {
  return [
    if (lifecycle.isNotEmpty)
      DetailActionGroup(label: ResourceMenuGroups.lifecycle, items: lifecycle),
    if (maintenance.isNotEmpty)
      DetailActionGroup(
        label: ResourceMenuGroups.maintenance,
        items: maintenance,
      ),
    if (danger.isNotEmpty) DetailActionGroup(items: danger),
  ];
}

/// Tag pills capped at [max] with a "+N" overflow pill.
List<Widget> resourceTagPills(List<String> tags, {int max = 2}) {
  if (tags.isEmpty) return const [];
  final shown = tags.take(max).toList();
  final remaining = tags.length - shown.length;
  return [
    for (final tag in shown) TextPill(label: tag),
    if (remaining > 0) TextPill(label: '+$remaining'),
  ];
}

final _hashPattern = RegExp(
  r'\b(?:sha256:)?[a-f0-9]{7,64}\b',
  caseSensitive: false,
);

/// Removes image/commit hashes from free-form status/image strings.
String stripHashes(String value) {
  return value.replaceAll(_hashPattern, '').replaceAll('  ', ' ').trim();
}

/// Placeholder cards built from the real [ResourceCard] so the layout does not
/// shift when data arrives. Wrap in [Skeletonizer] via this widget.
class ResourceCardSkeletonList extends StatelessWidget {
  const ResourceCardSkeletonList({
    required this.title,
    this.subtitle,
    this.metaLeft,
    this.metaRight,
    this.bottom,
    this.count = 6,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? metaLeft;
  final String? metaRight;
  final Widget? bottom;
  final int count;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: Padding(
        padding: padding,
        child: Column(
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const Gap(12),
              ResourceCard(
                title: title,
                subtitle: subtitle,
                status: const ResourceStatusSpec(
                  label: 'Running',
                  icon: AppIcons.ok,
                ),
                meta: [
                  if (metaLeft != null)
                    ResourceIconLabel(icon: AppIcons.server, label: metaLeft!),
                  if (metaRight != null)
                    ResourceIconLabel(
                      icon: AppIcons.package,
                      label: metaRight!,
                    ),
                ],
                bottom: bottom,
                menu: const [
                  DetailActionGroup(
                    items: [
                      DetailActionItem(
                        label: 'Actions',
                        icon: AppIcons.moreVertical,
                        onSelected: null,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
