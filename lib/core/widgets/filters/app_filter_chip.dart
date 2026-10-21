import 'package:flutter/material.dart';
import 'package:komodo_go/core/ui/app_motion.dart';

/// Height shared by all quick-filter chips.
const double kAppFilterChipHeight = 34;

/// Tappable stadium-shaped quick-filter chip.
///
/// Tonal pills without outline: unselected chips use a neutral container fill,
/// selected chips a tinted primary fill. An optional [count] is rendered as a trailing number.
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
    required this.onTap,
    this.icon,
    this.count,
    this.trailing,
  });

  final String label;
  final IconData? icon;
  final int? count;
  final bool selected;
  final IconData? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final duration = AppMotion.durationOf(context, AppMotion.fast);
    final foreground = selected ? scheme.primary : scheme.onSurfaceVariant;
    final countColor = selected ? scheme.primary : scheme.onSurface;
    final fill = selected
        ? scheme.primary.withValues(alpha: 0.16)
        : scheme.surfaceContainerHigh;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: fill),
        duration: duration,
        curve: AppMotion.standard,
        builder: (context, color, child) => Material(
          color: color,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kAppFilterChipHeight),
            child: Padding(
              padding: EdgeInsets.only(
                left: icon == null ? 14 : 10,
                right: trailing == null ? 14 : 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: foreground),
                    const SizedBox(width: 6),
                  ],
                  AnimatedDefaultTextStyle(
                    duration: duration,
                    curve: AppMotion.standard,
                    maxLines: 1,
                    style: (textTheme.labelLarge ?? const TextStyle()).copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    child: Text(label),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 6),
                    AppAnimatedValue.text(
                      '$count',
                      style: textTheme.labelMedium?.copyWith(
                        color: countColor,
                        fontWeight: FontWeight.w600,
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
