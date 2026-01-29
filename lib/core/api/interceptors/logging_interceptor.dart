import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Interceptor that logs HTTP requests and responses for debugging.
///
/// Sensitive headers (X-Api-Key, X-Api-Secret, Authorization, etc.) and
/// body fields containing secrets are automatically redacted.
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({this.enabled = kDebugMode});

  final bool enabled;

  /// Header names that should be redacted from logs.
  static const _sensitiveHeaders = <String>{
    'x-api-key',
    'x-api-secret',
    'authorization',
    'cookie',
    'set-cookie',
    'x-auth-token',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      developer.log('→ ${options.method} ${options.uri}', name: 'HTTP');
      if (options.data != null) {
        developer.log('  Body: ${_sanitize(options.data)}', name: 'HTTP');
      }
      // Log redacted headers for debugging connectivity issues.
      final safeHeaders = _redactHeaders(options.headers);
      if (safeHeaders.isNotEmpty) {
        developer.log('  Headers: $safeHeaders', name: 'HTTP');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (enabled) {
      developer.log(
        '← ${response.statusCode} ${response.requestOptions.uri}',
        name: 'HTTP',
      );
      if (response.data != null) {
        developer.log('  Response: ${_sanitize(response.data)}', name: 'HTTP');
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled) {
      developer.log(
        '✖ ${err.response?.statusCode ?? 'ERR'} ${err.requestOptions.uri}',
        name: 'HTTP',
        error: err.message,
      );
      final data = err.response?.data;
      if (data != null) {
        developer.log('  Error response: ${_sanitize(data)}', name: 'HTTP');
      }
    }
    handler.next(err);
  }

  /// Redacts sensitive header values while preserving header names.
  Map<String, String> _redactHeaders(Map<String, dynamic> headers) {
    final result = <String, String>{};
    for (final entry in headers.entries) {
      final key = entry.key;
      final lowerKey = key.toLowerCase();
      if (_sensitiveHeaders.contains(lowerKey) || _looksSensitiveKey(key)) {
        result[key] = '***';
      } else {
        result[key] = entry.value?.toString() ?? '';
      }
    }
    return result;
  }

  Object? _sanitize(Object? value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key: _sanitizeEntry(entry.key, entry.value),
      };
    }
    if (value is List) {
      return value.map(_sanitize).toList();
    }
    return value;
  }

  Object? _sanitizeEntry(Object? key, Object? value) {
    if (key is String && _looksSensitiveKey(key)) {
      return '***';
    }
    return _sanitize(value);
  }

  bool _looksSensitiveKey(String key) {
    final lower = key.toLowerCase();
    return lower.contains('secret') ||
        lower.contains('token') ||
        lower.contains('password') ||
        lower.contains('authorization') ||
        lower.contains('cookie') ||
        lower.contains('api_key') ||
        lower.contains('api-key') ||
        lower.contains('api-secret') ||
        lower.contains('api_secret') ||
        lower.contains('credential') ||
        lower == 'key' ||
        lower == 'value';
  }
}
