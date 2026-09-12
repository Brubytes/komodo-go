import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/theme/app_theme.dart';

double contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

void main() {
  test('dark accent text and button labels remain readable', () {
    final scheme = AppTheme.darkTheme.colorScheme;
    for (final background in [scheme.surface, scheme.surfaceContainer]) {
      expect(contrast(scheme.primary, background), greaterThanOrEqualTo(4.5));
    }
    expect(
      contrast(scheme.onPrimary, scheme.primary),
      greaterThanOrEqualTo(4.5),
    );
  });
}
