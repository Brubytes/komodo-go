import 'package:flutter/widgets.dart';

extension IconDataX on IconData {
  /// Returns an [IconData] that automatically flips in RTL layouts.
  IconData dir({bool matchTextDirection = true}) {
    return IconData(
      codePoint,
      fontFamily: fontFamily,
      fontPackage: fontPackage,
      matchTextDirection: matchTextDirection,
    );
  }
}
