import 'dart:async';

import 'package:flutter/material.dart';

enum AppSnackBarTone { neutral, success, warning, error }

class AppSnackBar {
  static const _defaultDuration = Duration(seconds: 4);

  static Timer? _dismissTimer;

  static void show(
    BuildContext context,
    String message, {
    AppSnackBarTone tone = AppSnackBarTone.neutral,
  }) {
    final scheme = Theme.of(context).colorScheme;

    final Color backgroundColor;
    final Color foregroundColor;

    switch (tone) {
      case AppSnackBarTone.neutral:
        backgroundColor = scheme.inverseSurface;
        foregroundColor = scheme.onInverseSurface;
      case AppSnackBarTone.success:
        backgroundColor = scheme.secondaryContainer;
        foregroundColor = scheme.onSecondaryContainer;
      case AppSnackBarTone.warning:
        backgroundColor = scheme.tertiaryContainer;
        foregroundColor = scheme.onTertiaryContainer;
      case AppSnackBarTone.error:
        backgroundColor = scheme.errorContainer;
        foregroundColor = scheme.onErrorContainer;
    }

    _dismissTimer?.cancel();

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();

    Duration remaining = _defaultDuration;
    DateTime? lastStartedAt;
    var isPaused = false;

    late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
    controller;

    void scheduleDismiss() {
      _dismissTimer?.cancel();
      lastStartedAt = DateTime.now();
      _dismissTimer = Timer(remaining, () {
        controller.close();
      });
    }

    void pauseDismissTimer() {
      if (isPaused || _dismissTimer == null) {
        return;
      }
      isPaused = true;
      _dismissTimer?.cancel();

      final startedAt = lastStartedAt;
      if (startedAt != null) {
        final elapsed = DateTime.now().difference(startedAt);
        final reduced = remaining - elapsed;
        remaining = reduced.isNegative ? Duration.zero : reduced;
      }
    }

    void resumeDismissTimer() {
      if (!isPaused) {
        return;
      }
      isPaused = false;
      if (remaining <= Duration.zero) {
        controller.close();
        return;
      }
      scheduleDismiss();
    }

    controller = messenger.showSnackBar(
      SnackBar(
        duration: const Duration(days: 1),
        backgroundColor: backgroundColor,
        content: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (_) => pauseDismissTimer(),
          onLongPressEnd: (_) => resumeDismissTimer(),
          onLongPressCancel: resumeDismissTimer,
          child: Text(
            message,
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );

    scheduleDismiss();
    controller.closed.whenComplete(() {
      _dismissTimer?.cancel();
      _dismissTimer = null;
    });
  }
}
