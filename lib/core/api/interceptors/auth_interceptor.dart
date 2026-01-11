import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Interceptor that adds API key authentication headers to requests.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required String apiKey, required String apiSecret})
    : _apiKey = apiKey,
      _apiSecret = apiSecret;

  final String _apiKey;
  final String _apiSecret;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers['X-Api-Key'] = _apiKey;
    options.headers['X-Api-Secret'] = _apiSecret;
    if (kDebugMode) {
      developer.log('  Auth: API key present', name: 'HTTP');
    }

    handler.next(options);
  }
}
