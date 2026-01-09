import 'package:flutter/material.dart';

enum AppSnackBarTone { neutral, success, warning, error }

class AppSnackBar {
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

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: backgroundColor,
          content: Text(
            message,
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
  }
}
