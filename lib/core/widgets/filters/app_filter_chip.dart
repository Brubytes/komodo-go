import 'package:flutter/material.dart';

/// Height shared by all quick-filter chips.
const double kAppFilterChipHeight = 34;

/// Tappable stadium-shaped quick-filter chip.
///
/// Unselected chips show a subtle outline, selected chips a tonal primary fill
/// with a check mark. An optional [count] is rendered as a trailing number.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.count,
    super.key,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return _FilterChipBody(
      label: label,
      icon: icon,
      count: count,
      selected: selected,
      checkWhenSelected: true,
      onTap: onSelected == null ? null : () => onSelected!(!selected),
    );
  }
}

/// One entry of an [AppFilterMenuChip].
class AppFilterMenuOption<T> {
  const AppFilterMenuOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Dropdown-style chip (label + chevron) opening a single-select menu.
///
/// The chip renders as selected when [active] is true (a non-default choice).
class AppFilterMenuChip<T> extends StatelessWidget {
  const AppFilterMenuChip({
    required this.label,
    required this.options,
    required this.onSelected,
    this.value,
    this.icon,
    this.active = false,
    super.key,
  });

  /// Text shown on the chip, e.g. `Server: All`.
  final String label;
  final IconData? icon;
  final List<AppFilterMenuOption<T>> options;
  final T? value;
  final bool active;
  final ValueChanged<T> onSelected;

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromLTRB(
      topLeft.dx,
      topLeft.dy + box.size.height,
      overlay.size.width - topLeft.dx - box.size.width,
      0,
    );
    final result = await showMenu<AppFilterMenuOption<T>>(
      context: context,
      position: position,
      items: [
        for (final option in options)
          PopupMenuItem<AppFilterMenuOption<T>>(
            value: option,
            child: Row(
              children: [
                Expanded(child: Text(option.label)),
                if (option.value == value)
                  Icon(
                    Icons.check,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          ),
      ],
    );
    if (result != null) onSelected(result.value);
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => _FilterChipBody(
        label: label,
        icon: icon,
        selected: active,
        checkWhenSelected: false,
        trailing: Icons.expand_more,
        onTap: () => _open(context),
      ),
    );
  }
}

/// Horizontally scrollable single row of filter chips.
class AppFilterChipBar extends StatelessWidget {
  const AppFilterChipBar({
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.verticalPadding = 8,
    super.key,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: kAppFilterChipHeight + verticalPadding * 2,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding.add(EdgeInsets.symmetric(vertical: verticalPadding)),
        child: Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Center(child: children[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChipBody extends StatelessWidget {
  const _FilterChipBody({
    required this.label,
    required this.selected,
    required this.checkWhenSelected,
    required this.onTap,
    this.icon,
    this.count,
    this.trailing,
  });

  final String label;
  final IconData? icon;
  final int? count;
  final bool selected;
  final bool checkWhenSelected;
  final IconData? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final foreground = selected ? scheme.primary : scheme.onSurfaceVariant;
    final fill = selected
        ? scheme.primary.withValues(alpha: 0.16)
        : Colors.transparent;
    final borderColor = selected
        ? scheme.primary.withValues(alpha: 0.35)
        : scheme.outlineVariant;
    final leading = selected && checkWhenSelected ? Icons.check : icon;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: fill,
        shape: StadiumBorder(side: BorderSide(color: borderColor)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kAppFilterChipHeight),
            child: Padding(
              padding: EdgeInsets.only(
                left: leading == null ? 14 : 10,
                right: trailing == null ? 14 : 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[
                    Icon(leading, size: 16, color: foreground),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    maxLines: 1,
                    style: textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '$count',
                      style: textTheme.labelMedium?.copyWith(
                        color: foreground.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                  if (trailing != null) ...[
                    const SizedBox(width: 2),
                    Icon(trailing, size: 18, color: foreground),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
