import 'dart:async';

import 'package:flutter/material.dart';
import 'package:komodo_go/core/ui/app_motion.dart';

/// Thin (2px) indeterminate progress bar for background refreshes.
///
/// Always reserves its 2px of height, so showing/hiding it never shifts the
/// layout. It fades in only after [delay] (so refreshes that finish quickly
/// never flash it) and fades out when [active] turns false. The bar looks
/// like the one in the log viewer.
///
/// Use it directly when composing a screen by hand; `AsyncContent` shows it
/// automatically while a value is refreshing.
/// ```dart
/// Column(children: [RefreshProgressBar(active: async.isBackgroundRefresh), ...])
/// ```
class RefreshProgressBar extends StatefulWidget {
  const RefreshProgressBar({
    required this.active,
    super.key,
    this.delay = const Duration(milliseconds: 200),
  });

  /// Whether a refresh is currently running.
  final bool active;

  /// How long [active] must hold before the bar becomes visible.
  final Duration delay;

  @override
  State<RefreshProgressBar> createState() => _RefreshProgressBarState();
}

class _RefreshProgressBarState extends State<RefreshProgressBar> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _arm();
  }

  @override
  void didUpdateWidget(RefreshProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      _arm();
    } else {
      _timer?.cancel();
      if (_visible) setState(() => _visible = false);
    }
  }

  void _arm() {
    _timer?.cancel();
    if (widget.delay == Duration.zero) {
      _visible = true;
      return;
    }
    _timer = Timer(widget.delay, () {
      if (mounted && widget.active) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2,
      child: AnimatedSwitcher(
        duration: AppMotion.fast,
        layoutBuilder: (current, previous) => Stack(
          fit: StackFit.expand,
          children: [...previous, ?current],
        ),
        child: _visible
            ? const LinearProgressIndicator(
                key: ValueKey('refresh_progress_bar'),
                minHeight: 2,
              )
            : const SizedBox.shrink(key: ValueKey('refresh_progress_idle')),
      ),
    );
  }
}
