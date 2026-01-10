import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

void debugLog(
  String message, {
  String name = 'APP',
  Object? error,
  StackTrace? stackTrace,
}) {
  if (!kDebugMode) return;
  developer.log(message, name: name, error: error, stackTrace: stackTrace);
}
