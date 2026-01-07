import 'package:flutter/material.dart';

/// Design-system tokens shared across the app.
///
/// Keep these as small, stable primitives (colors, radii, spacing) so widgets
/// don't hard-code styling decisions.
abstract final class AppTokens {
  AppTokens._();

  static const Color brandPrimary = Color(0xFF014226);
  /// Slightly brighter variant of [brandPrimary] for dark mode accents (labels/icons).
  static const Color brandPrimaryDark = Color(0xFF1E7A52);
  static const Color brandSecondary = Color(0xFF4EB333);

  /// Status colors used for alerts/updates chips.
  ///
  /// These mirror Komodo web’s status palette.
  static const Color statusGreen = Color(0xFF4ADE80); // 74 222 128
  static const Color statusOrange = Color(0xFFFACC15); // 250 204 21
  static const Color statusRed = Color(0xFFF87171); // 248 113 113

  static const String systemFontStack =
      '-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Oxygen,Ubuntu,Cantarell,Fira Sans,Droid Sans,Helvetica Neue,sans-serif';

  static const double radiusMd = 12;
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 16,
  );
}
