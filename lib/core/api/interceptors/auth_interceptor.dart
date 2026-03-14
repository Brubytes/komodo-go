import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Interceptor that adds API key authentication headers to requests.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required String apiKey,
    required String apiSecret,
    Map<String, String> additionalHeaders = const <String, String>{},
  }) : _apiKey = apiKey,
       _apiSecret = apiSecret,
       _additionalHeaders = additionalHeaders;

  final String _apiKey;
  final String _apiSecret;
  final Map<String, String> _additionalHeaders;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers['X-Api-Key'] = _apiKey;
    options.headers['X-Api-Secret'] = _apiSecret;
    if (_additionalHeaders.isNotEmpty) {
      options.headers.addAll(_additionalHeaders);
    }

    if (kDebugMode) {
      final hasAdditionalHeaders = _additionalHeaders.isNotEmpty;
      developer.log(
        '  Auth: API key present${hasAdditionalHeaders ? ', advanced headers present' : ''}',
        name: 'HTTP',
      );
    }

    handler.next(options);
  }
}
