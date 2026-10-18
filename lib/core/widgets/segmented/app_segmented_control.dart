import 'package:flutter/material.dart';
import 'package:komodo_go/core/theme/status_colors.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';

const double _kTrackHeight = 40;
const double _kTrackPadding = 3;
const double _kTrackRadius = 12;
const double _kThumbRadius = 9;
const double _kSegmentHeight = _kTrackHeight - _kTrackPadding * 2;

Color _trackColor(ColorScheme scheme) => scheme.surfaceContainerHigh;

BoxDecoration _thumbDecoration(ColorScheme scheme) {
  final isLight = scheme.brightness == Brightness.light;
  return BoxDecoration(
    color: scheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(_kThumbRadius),
    boxShadow: isLight
        ? [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.08),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ]
        : null,
  );
}

TextStyle? _labelStyle(
  BuildContext context, {
  required bool selected,
}) {
  final scheme = Theme.of(context).colorScheme;
  return Theme.of(context).textTheme.labelLarge?.copyWith(
    color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
  );
}

/// One segment of an [AppSegmentedTabBar].
class AppSegment {
  const AppSegment({
    required this.label,
    this.badgeCount,
    this.badgeTone = PillTone.neutral,
    this.icon,
    this.key,
  });

  final String label;

  /// Trailing count badge; hidden when null or 0.
  final int? badgeCount;
  final PillTone badgeTone;
  final IconData? icon;

  /// Key applied to the segment's tab.
  final Key? key;
}

/// One option of an [AppSegmentedControl].
class AppSegmentOption<T> {
  const AppSegmentOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Small stadium count badge shown inside a segment.
class _SegmentBadge extends StatelessWidget {
  const _SegmentBadge({required this.count, required this.tone});

  final int count;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (tone) {
      PillTone.warning => (scheme.statusWarningContainer, scheme.statusWarning),
      PillTone.success => (scheme.statusSuccessContainer, scheme.statusSuccess),
      PillTone.alert => (scheme.errorContainer, scheme.onErrorContainer),
      PillTone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    return Container(
      height: 20,
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: AppAnimatedValue.text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SegmentContent extends StatelessWidget {
  const _SegmentContent({
    required this.label,
    this.icon,
    this.badgeCount,
    this.badgeTone = PillTone.neutral,
  });

  final String label;
  final IconData? icon;
  final int? badgeCount;
  final PillTone badgeTone;

  @override
  Widget build(BuildContext context) {
    // Inherits color/weight from the surrounding DefaultTextStyle/TabBar.
    final color = DefaultTextStyle.of(context).style.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (badgeCount != null && badgeCount! > 0) ...[
          const SizedBox(width: 6),
          _SegmentBadge(count: badgeCount!, tone: badgeTone),
        ],
      ],
    );
  }
}

/// Segmented pill control driven by a [TabController]. Place it in an app
/// bar's `bottom`; the thumb follows the controller's animation, so swiping
/// a `TabBarView` moves it continuously.
class AppSegmentedTabBar extends StatelessWidget
    implements PreferredSizeWidget {
  const AppSegmentedTabBar({
    required this.controller,
    required this.segments,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    super.key,
  });

  final TabController controller;
  final List<AppSegment> segments;
  final EdgeInsetsGeometry padding;

  @override
  Size get preferredSize => Size.fromHeight(_kTrackHeight + padding.vertical);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Container(
        height: _kTrackHeight,
        padding: const EdgeInsets.all(_kTrackPadding),
        decoration: BoxDecoration(
          color: _trackColor(scheme),
          borderRadius: BorderRadius.circular(_kTrackRadius),
        ),
        child: TabBar(
          controller: controller,
          indicator: _thumbDecoration(scheme),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerHeight: 0,
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          labelPadding: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          labelColor: scheme.onSurface,
          unselectedLabelColor: scheme.onSurfaceVariant,
          labelStyle: _labelStyle(context, selected: true),
          unselectedLabelStyle: _labelStyle(context, selected: false),
          tabs: [
            for (final s in segments)
              Tab(
                key: s.key,
                height: _kSegmentHeight,
                child: _SegmentContent(
                  label: s.label,
                  icon: s.icon,
                  badgeCount: s.badgeCount,
                  badgeTone: s.badgeTone,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Value-based segmented pill control with a sliding thumb.
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    required this.value,
    required this.segments,
    required this.onChanged,
    this.expand = true,
    super.key,
  }) : assert(segments.length > 0, 'segments must not be empty');

  final T value;
  final List<AppSegmentOption<T>> segments;

  /// Null disables the control.
  final ValueChanged<T>? onChanged;

  /// Fill the available width (default) or size to the widest segment.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = segments.length;
    final index = segments.indexWhere((s) => s.value == value);
    final alignX = n == 1 || index < 0 ? 0.0 : -1 + 2 * index / (n - 1);
    final enabled = onChanged != null;

    Widget track = Container(
      height: _kTrackHeight,
      padding: const EdgeInsets.all(_kTrackPadding),
      decoration: BoxDecoration(
        color: _trackColor(scheme),
        borderRadius: BorderRadius.circular(_kTrackRadius),
      ),
      child: Stack(
        children: [
          if (index >= 0)
            Positioned.fill(
              child: AnimatedAlign(
                duration: AppMotion.durationOf(context, AppMotion.base),
                curve: AppMotion.standard,
                alignment: Alignment(alignX, 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  heightFactor: 1,
                  child: DecoratedBox(decoration: _thumbDecoration(scheme)),
                ),
              ),
            ),
          Row(
            children: [
              for (final s in segments)
                Expanded(
                  child: _Segment(
                    label: s.label,
                    icon: s.icon,
                    selected: s.value == value,
                    onTap: enabled ? () => onChanged!(s.value) : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    if (!expand) {
      track = IntrinsicWidth(child: track);
    }
    return Opacity(opacity: enabled ? 1 : 0.5, child: track);
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    final style = _labelStyle(context, selected: selected)?.copyWith(
      color: color,
    );
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: _kSegmentHeight,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: AnimatedDefaultTextStyle(
                style: style ?? const TextStyle(),
                duration: AppMotion.durationOf(context, AppMotion.fast),
                curve: AppMotion.standard,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
