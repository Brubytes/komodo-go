import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:dio/dio.dart';

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
    final previewLen = math.min(8, _apiKey.length);
    developer.log(
      '  Auth: API key present (${_apiKey.substring(0, previewLen)}...)',
      name: 'HTTP',
    );

    handler.next(options);
  }
}
