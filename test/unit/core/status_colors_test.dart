import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/theme/app_theme.dart';
import 'package:komodo_go/core/theme/status_colors.dart';

double _contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

void main() {
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    test('${theme.brightness} status text has readable contrast', () {
      final scheme = theme.colorScheme;
      for (final (foreground, background) in [
        (scheme.statusSuccess, scheme.statusSuccessContainer),
        (scheme.statusWarning, scheme.statusWarningContainer),
        (scheme.onErrorContainer, scheme.errorContainer),
        (scheme.onPrimaryContainer, scheme.primaryContainer),
      ]) {
        expect(_contrast(foreground, background), greaterThanOrEqualTo(4.5));
      }
      for (final surface in [scheme.surface, scheme.surfaceContainer]) {
        for (final foreground in [
          scheme.statusSuccess,
          scheme.statusWarning,
          scheme.error,
          scheme.primary,
          scheme.onSurfaceVariant,
        ]) {
          expect(_contrast(foreground, surface), greaterThanOrEqualTo(4.5));
          // Resource badges and container chips tint their underlying surface.
          for (final alpha in [0.1, 0.12]) {
            final background = Color.alphaBlend(
              foreground.withValues(alpha: alpha),
              surface,
            );
            expect(
              _contrast(foreground, background),
              greaterThanOrEqualTo(4.5),
              reason: '${theme.brightness}, $foreground, tint $alpha',
            );
          }
        }
      }
    });
  }
}
