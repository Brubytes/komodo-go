import 'dart:async';

import 'package:flutter/material.dart';
import 'package:komodo_go/core/ui/app_motion.dart';

/// Lightweight "an action is running" overlay that blocks input.
///
/// Replaces the old full-screen scrim with a skeleton card. Input is blocked
/// as soon as [busy] is true, but the visuals (a faint scrim and a small
/// centered progress card) only fade in after [delay], so instant actions
/// never flash anything, and they fade out when the action ends.
///
/// Use it as a (non-positioned) child of a `Stack` that wraps the screen
/// body; it fills the stack:
/// ```dart
/// Stack(children: [
///   body,
///   ActionBusyOverlay(busy: actionsState.isLoading),
/// ])
/// ```
class ActionBusyOverlay extends StatefulWidget {
  const ActionBusyOverlay({
    required this.busy,
    super.key,
    this.delay = const Duration(milliseconds: 150),
  });

  final bool busy;

  /// Time [busy] must hold before the visuals appear.
  final Duration delay;

  @override
  State<ActionBusyOverlay> createState() => _ActionBusyOverlayState();
}

class _ActionBusyOverlayState extends State<ActionBusyOverlay> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (widget.busy) _arm();
  }

  @override
  void didUpdateWidget(ActionBusyOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.busy == oldWidget.busy) return;
    if (widget.busy) {
      _arm();
    } else {
      _timer?.cancel();
      _visible = false;
    }
  }

  void _arm() {
    _timer?.cancel();
    if (widget.delay == Duration.zero) {
      _visible = true;
      return;
    }
    _timer = Timer(widget.delay, () {
      if (mounted && widget.busy) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visuals = AppSwitcher(
      animateSize: false,
      alignment: Alignment.center,
      child: _visible
          ? ColoredBox(
              key: const ValueKey('action_busy_visible'),
              color: scheme.scrim.withValues(alpha: 0.12),
              child: Center(
                child: Material(
                  color: scheme.surfaceContainerHigh,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.expand(key: ValueKey('action_busy_hidden')),
    );
    return SizedBox.expand(
      child: AbsorbPointer(
        absorbing: widget.busy,
        // While fading out the scrim must not swallow touches any more.
        child: IgnorePointer(ignoring: !widget.busy, child: visuals),
      ),
    );
  }
}
