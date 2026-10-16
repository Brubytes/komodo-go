import 'package:flutter/material.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/menus/komodo_popup_menu.dart';

/// A single entry in an action menu.
class DetailActionItem {
  const DetailActionItem({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.destructive = false,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onSelected;
  final bool destructive;
  final bool enabled;
}

/// A labelled group of [DetailActionItem]s.
class DetailActionGroup {
  const DetailActionGroup({
    required this.items,
    this.label,
    this.sheetLabel,
  });

  final String? label;
  final List<DetailActionItem> items;

  /// When set (e.g. "Manage…") and the menu has other groups, the whole group
  /// collapses into a single menu entry that opens [items] in a bottom sheet.
  /// This keeps long menus short enough to reach Danger actions on phones.
  final String? sheetLabel;
}

/// A prominent button used in [DetailActionBar].
class DetailActionButton {
  const DetailActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
}

/// Builds popup menu entries from grouped actions.
///
/// Destructive items from every group are moved to a trailing group that is
/// separated by a divider and rendered in the error color.
List<PopupMenuEntry<DetailActionItem>> buildDetailActionMenuEntries(
  BuildContext context,
  List<DetailActionGroup> groups,
) {
  final textTheme = Theme.of(context).textTheme;
  final scheme = Theme.of(context).colorScheme;
  final entries = <PopupMenuEntry<DetailActionItem>>[];
  final destructive = <DetailActionItem>[];

  PopupMenuEntry<DetailActionItem> row(DetailActionItem item) {
    return PopupMenuItem<DetailActionItem>(
      value: item,
      enabled: item.enabled && item.onSelected != null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: KomodoPopupMenuItemRow(
        icon: item.icon,
        label: item.label,
        isDestructive: item.destructive,
      ),
    );
  }

  final sheetGroups = <DetailActionGroup>[];
  final hasOtherGroups = groups.any(
    (g) => g.sheetLabel == null && g.items.isNotEmpty,
  );

  for (final group in groups) {
    if (group.sheetLabel != null && hasOtherGroups) {
      if (group.items.isNotEmpty) sheetGroups.add(group);
      continue;
    }
    final normal = group.items.where((i) => !i.destructive).toList();
    destructive.addAll(group.items.where((i) => i.destructive));
    if (normal.isEmpty) continue;
    if (entries.isNotEmpty) entries.add(komodoPopupMenuDivider());
    final label = group.label;
    if (label != null && label.isNotEmpty) {
      entries.add(
        PopupMenuItem<DetailActionItem>(
          enabled: false,
          height: 28,
          child: Text(
            label.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
      );
    }
    entries.addAll(normal.map(row));
  }

  if (sheetGroups.isNotEmpty) {
    if (entries.isNotEmpty) entries.add(komodoPopupMenuDivider());
    for (final group in sheetGroups) {
      entries.add(
        row(
          DetailActionItem(
            label: group.sheetLabel!,
            icon: AppIcons.settings,
            onSelected: () => showDetailActionSheet(context, group),
          ),
        ),
      );
    }
  }

  if (destructive.isNotEmpty) {
    if (entries.isNotEmpty) entries.add(komodoPopupMenuDivider());
    entries.addAll(destructive.map(row));
  }
  return entries;
}

/// Shows [group]'s items in a compact bottom sheet (used for "Manage…").
Future<void> showDetailActionSheet(
  BuildContext context,
  DetailActionGroup group,
) {
  final title = group.label ?? group.sheetLabel ?? 'Actions';
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              title,
              style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
          ),
          for (final item in group.items)
            ListTile(
              enabled: item.enabled && item.onSelected != null,
              leading: Icon(
                item.icon,
                color: item.destructive ? scheme.error : null,
              ),
              title: Text(
                item.label,
                style: item.destructive ? TextStyle(color: scheme.error) : null,
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                item.onSelected?.call();
              },
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      );
    },
  );
}

/// Opens the grouped action menu at [position] (global coordinates) and runs
/// the selected item's callback.
Future<void> showDetailActionMenu(
  BuildContext context, {
  required List<DetailActionGroup> groups,
  required Offset position,
}) async {
  final entries = buildDetailActionMenuEntries(context, groups);
  if (entries.isEmpty) return;
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final selected = await showMenu<DetailActionItem>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(position.dx, position.dy, 0, 0),
      Offset.zero & overlay.size,
    ),
    items: entries,
  );
  selected?.onSelected?.call();
}

/// A "More" / overflow button that opens a grouped action menu.
class DetailActionMenuButton extends StatelessWidget {
  const DetailActionMenuButton({
    required this.groups,
    super.key,
    this.groupsBuilder,
    this.child,
    this.tooltip = 'More',
    this.icon = AppIcons.moreVertical,
  });

  final List<DetailActionGroup> groups;

  /// When set, evaluated lazily each time the menu opens instead of [groups].
  final List<DetailActionGroup> Function()? groupsBuilder;
  final Widget? child;
  final String tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DetailActionItem>(
      tooltip: tooltip,
      icon: child == null ? Icon(icon) : null,
      child: child,
      onSelected: (item) => item.onSelected?.call(),
      itemBuilder: (context) => buildDetailActionMenuEntries(
        context,
        groupsBuilder?.call() ?? groups,
      ),
    );
  }
}

/// Row placed below the detail header: one primary action, an optional
/// secondary action and a "More" menu built from grouped entries.
class DetailActionBar extends StatelessWidget {
  const DetailActionBar({
    required this.primary,
    super.key,
    this.secondary,
    this.moreGroups = const [],
    this.padding = EdgeInsets.zero,
  });

  final DetailActionButton primary;
  final DetailActionButton? secondary;
  final List<DetailActionGroup> moreGroups;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasMore = moreGroups.any((g) => g.items.isNotEmpty);
    final secondary = this.secondary;

    Widget fit(String label) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(label, maxLines: 1, softWrap: false),
    );

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: primary.loading ? null : primary.onPressed,
              icon: primary.loading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    )
                  : Icon(primary.icon, size: 18),
              label: fit(primary.label),
            ),
          ),
          if (secondary != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: secondary.loading ? null : secondary.onPressed,
                icon: secondary.loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(secondary.icon, size: 18),
                label: fit(secondary.label),
              ),
            ),
          ],
          if (hasMore) ...[
            const SizedBox(width: AppSpacing.sm),
            DetailActionMenuButton(
              groups: moreGroups,
              tooltip: 'More actions',
              child: Container(
                key: const ValueKey('detail_action_bar_more'),
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Icon(
                  AppIcons.moreVertical,
                  size: 20,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
