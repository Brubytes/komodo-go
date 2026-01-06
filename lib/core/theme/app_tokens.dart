import 'package:flutter/material.dart';

/// Design-system tokens shared across the app.
///
/// Keep these as small, stable primitives (colors, radii, spacing) so widgets
/// don't hard-code styling decisions.
abstract final class AppTokens {
  AppTokens._();

  static const Color brandPrimary = Color(0xFF014226);
  static const Color brandSecondary = Color(0xFF4EB333);

  static const double radiusMd = 12;
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 16,
  );
}
