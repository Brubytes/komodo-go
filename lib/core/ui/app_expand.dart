import 'package:flutter/material.dart';
import 'package:komodo_go/core/ui/app_motion.dart';

/// Animates height changes of [child] (base duration, standard curve, top
/// aligned). Under reduced motion the change is instant.
///
/// When [expanded] is false the child is replaced by an empty box, so the
/// content collapses away. Pair a disclosure icon with [AppChevron], which
/// uses the same duration and curve.
class AppExpand extends StatelessWidget {
  const AppExpand({
    required this.child,
    super.key,
    this.expanded = true,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final bool expanded;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final content = expanded ? child : const SizedBox(width: double.infinity);
    // AnimatedSize asserts with a zero duration, so skip it when reduced.
    if (AppMotion.reducedOf(context)) return content;
    return AnimatedSize(
      duration: AppMotion.base,
      curve: AppMotion.standard,
      alignment: alignment,
      child: content,
    );
  }
}

/// Disclosure chevron whose rotation is synced with [AppExpand]
/// (same duration and curve).
class AppChevron extends StatelessWidget {
  const AppChevron({
    required this.expanded,
    super.key,
    this.icon = Icons.expand_more,
    this.expandedTurns = 0.5,
    this.size,
    this.color,
  });

  final bool expanded;
  final IconData icon;

  /// Rotation (in full turns) when [expanded]. Use `0.25` for a right-pointing
  /// icon that turns downward.
  final double expandedTurns;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: expanded ? expandedTurns : 0,
      duration: AppMotion.durationOf(context, AppMotion.base),
      curve: AppMotion.standard,
      child: Icon(icon, size: size, color: color),
    );
  }
}
