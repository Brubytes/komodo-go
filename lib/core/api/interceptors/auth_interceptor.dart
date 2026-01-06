import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../../storage/secure_storage_service.dart';

/// Interceptor that adds API key authentication headers to requests.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  final SecureStorageService _storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final credentials = await _storage.getCredentials();

    if (credentials != null) {
      options.headers['X-Api-Key'] = credentials.apiKey;
      options.headers['X-Api-Secret'] = credentials.apiSecret;
      developer.log(
        '  Auth: API key present (${credentials.apiKey.substring(0, 8)}...)',
        name: 'HTTP',
      );
    } else {
      developer.log(
        '  Auth: No credentials found!',
        name: 'HTTP',
      );
    }

    handler.next(options);
  }
}
