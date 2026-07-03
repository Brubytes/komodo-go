import 'dart:async';

import 'package:flutter/material.dart';

enum AppSnackBarTone { neutral, success, warning, error }

class AppSnackBar {
  static const _defaultDuration = Duration(seconds: 4);

  static Timer? _dismissTimer;

  /// Identifies the `show` invocation that owns [_dismissTimer], so callbacks
  /// from an already-dismissed snackbar can't cancel its successor's timer.
  static Object? _activeSession;

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

    final session = Object();
    _activeSession = session;

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();

    var remaining = _defaultDuration;
    DateTime? lastStartedAt;
    var isPaused = false;

    final controllerRef = _SnackBarControllerRef();

    void scheduleDismiss() {
      if (_activeSession != session) return;
      _dismissTimer?.cancel();
      lastStartedAt = DateTime.now();
      _dismissTimer = Timer(remaining, () {
        controllerRef.value?.close();
      });
    }

    void pauseDismissTimer() {
      if (_activeSession != session || isPaused || _dismissTimer == null) {
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
      if (_activeSession != session || !isPaused) {
        return;
      }
      isPaused = false;
      if (remaining <= Duration.zero) {
        controllerRef.value?.close();
        return;
      }
      scheduleDismiss();
    }

    controllerRef.value = messenger.showSnackBar(
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
    final closed = controllerRef.value?.closed;
    if (closed != null) {
      unawaited(
        closed.whenComplete(() {
          if (_activeSession != session) return;
          _activeSession = null;
          _dismissTimer?.cancel();
          _dismissTimer = null;
        }),
      );
    }
  }
}

class _SnackBarControllerRef {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? value;
}
