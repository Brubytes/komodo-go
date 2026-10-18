import 'package:flutter/material.dart';

export 'app_animated_value.dart';
export 'app_expand.dart';
export 'app_fade_slide.dart';
export 'app_list_intro.dart';
export 'app_pressable.dart';
export 'app_switcher.dart';

/// Single source of truth for UI motion.
///
/// Motion is short, decelerating and spatially honest: things that enter ease
/// out, things that leave ease in (and are faster than entrances). Nothing
/// bounces. Under reduced motion (`MediaQuery.disableAnimations`) all
/// movement, scaling, size and stagger animation is removed; at most a short
/// opacity fade remains.
///
/// Importing this file also exports the shared motion widgets
/// (`AppFadeSlide`, `AppSwitcher`, `AppExpand`, `AppChevron`, `AppPressable`,
/// `AppAnimatedValue`, `AppListIntro`).
abstract final class AppMotion {
  AppMotion._();

  // --- Durations -----------------------------------------------------------

  /// Press feedback, icon swaps, chevrons.
  static const Duration micro = Duration(milliseconds: 100);

  /// Fades, value changes, small state flips, exits of switchers.
  static const Duration fast = Duration(milliseconds: 150);

  /// Switchers, expand/collapse, list intros, dialogs in.
  static const Duration base = Duration(milliseconds: 250);

  /// Tab changes, programmatic scrolls, sheets in, page-level motion.
  static const Duration slow = Duration(milliseconds: 350);

  /// Period of one skeleton shimmer sweep (ambient, not an interaction).
  static const Duration shimmer = Duration(milliseconds: 1600);

  // --- Curves --------------------------------------------------------------

  /// On-screen changes (size, scroll, tab).
  static const Curve standard = Easing.standard;

  /// Things appearing.
  static const Curve enter = Easing.emphasizedDecelerate;

  /// Things leaving.
  static const Curve exit = Easing.emphasizedAccelerate;

  /// Large movement (scroll-to-top, header collapse).
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  // --- Distances / scale ---------------------------------------------------

  /// Vertical travel of list/section intros, in logical pixels.
  static const double slideOffsetY = 8;

  /// Scale of a pressed `AppPressable`.
  static const double pressScale = 0.97;

  // --- Stagger -------------------------------------------------------------

  /// Maximum number of items that take part in a list intro.
  static const int introItemLimit = 8;

  /// Delay of the item at [index]: 30ms steps, capped at 150ms.
  static Duration stagger(int index, {int stepMs = 30, int maxMs = 150}) {
    final ms = (index * stepMs).clamp(0, maxMs);
    return Duration(milliseconds: ms);
  }

  // --- Reduced motion ------------------------------------------------------

  /// Whether the platform asks for reduced motion (iOS "Reduce Motion",
  /// Android "Remove animations").
  static bool reducedOf(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or [Duration.zero] under reduced motion.
  static Duration durationOf(BuildContext context, Duration duration) =>
      reducedOf(context) ? Duration.zero : duration;

  /// Scrolls [controller] to [offset]; jumps instead under reduced motion or
  /// when the controller is not attached to a scroll view.
  static Future<void> animateOrJump(
    ScrollController controller,
    double offset,
    BuildContext context, {
    Duration? duration,
    Curve? curve,
  }) async {
    if (!controller.hasClients) return;
    if (reducedOf(context)) {
      controller.jumpTo(offset);
      return;
    }
    await controller.animateTo(
      offset,
      duration: duration ?? slow,
      curve: curve ?? emphasized,
    );
  }

  /// Animation style for modal bottom sheets.
  static AnimationStyle sheetStyle(BuildContext context) {
    if (reducedOf(context)) return AnimationStyle.noAnimation;
    return const AnimationStyle(
      duration: slow,
      reverseDuration: base,
      curve: enter,
      reverseCurve: exit,
    );
  }

  /// Animation style for dialogs (reduced: short fade only).
  static AnimationStyle dialogStyle(BuildContext context) {
    if (reducedOf(context)) {
      return const AnimationStyle(duration: fast, reverseDuration: fast);
    }
    return const AnimationStyle(
      duration: base,
      reverseDuration: fast,
      curve: enter,
      reverseCurve: exit,
    );
  }

  /// Animation style for expand/collapse of `ExpansionTile`s.
  static AnimationStyle expansionStyle(BuildContext context) {
    if (reducedOf(context)) return AnimationStyle.noAnimation;
    return const AnimationStyle(
      duration: base,
      reverseDuration: base,
      curve: standard,
      reverseCurve: standard,
    );
  }

  /// Animation style for snack bars, for `showSnackBar(snackBarAnimationStyle:)`.
  static AnimationStyle snackBarStyle(BuildContext context) {
    if (reducedOf(context)) return AnimationStyle.noAnimation;
    return const AnimationStyle(
      duration: base,
      reverseDuration: fast,
      curve: enter,
      reverseCurve: exit,
    );
  }
}
