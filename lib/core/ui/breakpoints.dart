import 'package:flutter/widgets.dart';

/// Coarse window width buckets used to pick between phone-style and
/// wide-window layouts. The window resizes live on fold/unfold and in Split
/// View, so never cache the result; derive it from the current constraints.
enum WindowSizeClass {
  compact,
  medium,
  expanded;

  /// Below 600 is compact, below 840 medium, everything else expanded.
  static WindowSizeClass fromWidth(double width) {
    if (width < 600) return WindowSizeClass.compact;
    if (width < 840) return WindowSizeClass.medium;
    return WindowSizeClass.expanded;
  }

  bool get isCompact => this == WindowSizeClass.compact;
}

/// Width at which the navigation rail switches to its extended (icon + label
/// side by side) form.
const double kExtendedRailMinWidth = 1200;

extension WindowSizeClassContext on BuildContext {
  /// Size class of the whole window. Inside nested panes measure the local
  /// width with a `LayoutBuilder` instead.
  WindowSizeClass get windowSizeClass =>
      WindowSizeClass.fromWidth(MediaQuery.sizeOf(this).width);
}
