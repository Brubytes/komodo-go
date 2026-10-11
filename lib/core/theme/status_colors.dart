import 'package:flutter/material.dart';

/// Semantic colors for health and attention, independent of resource accents.
/// Error, working, and inactive states use error, primary, and
/// onSurfaceVariant from the same ColorScheme.
extension StatusColors on ColorScheme {
  Color get statusSuccess => brightness == Brightness.dark
      ? const Color(0xFF86EFAC)
      : const Color(0xFF166534);

  Color get statusSuccessContainer => brightness == Brightness.dark
      ? const Color(0xFF173B29)
      : const Color(0xFFDCFCE7);

  Color get statusWarning => brightness == Brightness.dark
      ? const Color(0xFFFCD34D)
      : const Color(0xFF92400E);

  Color get statusWarningContainer => brightness == Brightness.dark
      ? const Color(0xFF422F13)
      : const Color(0xFFFEF3C7);
}
