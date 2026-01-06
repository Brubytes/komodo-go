import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ProviderScope(
      retry: (retryCount, error) {
        // Retry network errors up to 3 times with exponential backoff
        if (retryCount >= 3) return null;
        if (error is DioException) {
          return Duration(milliseconds: 200 * (1 << retryCount));
        }
        return null; // Don't retry non-network errors
      },
      child: const KomodoApp(),
    ),
  );
}
