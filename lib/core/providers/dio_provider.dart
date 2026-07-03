import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/interceptors/auth_interceptor.dart';
import 'package:komodo_go/core/api/interceptors/logging_interceptor.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dio_provider.g.dart';

class ActiveConnectionData {
  const ActiveConnectionData({
    required this.connectionId,
    required this.name,
    required this.credentials,
  });

  final String connectionId;
  final String name;
  final ApiCredentials credentials;
}

/// In-memory active connection (base URL + credentials) used to configure Dio.
@Riverpod(keepAlive: true)
class ActiveConnection extends _$ActiveConnection {
  @override
  ActiveConnectionData? build() => null;

  ActiveConnectionData? get active => state;

  set active(ActiveConnectionData? data) {
    state = data;
  }

  void clear() {
    state = null;
  }
}

/// Provides the Dio HTTP client configured for Komodo API.
/// Returns null if no active connection is configured (user not authenticated).
@riverpod
Dio? dio(Ref ref) {
  final activeConnection = ref.watch(activeConnectionProvider);
  final credentials = activeConnection?.credentials;

  if (credentials == null || credentials.baseUrl.isEmpty) {
    return null;
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: _normalizeTransportBaseUrl(credentials.baseUrl),
      contentType: 'application/json',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      // Never follow redirects: dart:io re-sends all headers (including
      // X-Api-Key/X-Api-Secret) to the redirect target, which could leak
      // credentials cross-origin. A 3xx surfaces as a badResponse and is
      // translated into proxy-redirect guidance by ApiException.
      followRedirects: false,
      maxRedirects: 0,
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(
      apiKey: credentials.apiKey,
      apiSecret: credentials.apiSecret,
      additionalHeaders: credentials.additionalHeaders(),
    ),
    if (kDebugMode) LoggingInterceptor(),
  ]);

  // Close the previous instance's keep-alive sockets when the active
  // connection changes and this provider is rebuilt.
  ref.onDispose(dio.close);

  return dio;
}

/// Provides the Komodo API client.
/// Returns null if Dio is not configured (user not authenticated).
@riverpod
KomodoApiClient? apiClient(Ref ref) {
  final dio = ref.watch(dioProvider);
  if (dio == null) {
    return null;
  }
  return KomodoApiClient(dio);
}

/// Creates a Dio instance for validating credentials before saving.
/// This instance doesn't use stored credentials.
Dio createValidationDio(String baseUrl, ApiCredentials credentials) {
  return Dio(
    BaseOptions(
      baseUrl: _normalizeTransportBaseUrl(baseUrl),
      contentType: 'application/json',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      followRedirects: false,
      maxRedirects: 0,
      headers: {
        'X-Api-Key': credentials.apiKey,
        'X-Api-Secret': credentials.apiSecret,
        ...credentials.additionalHeaders(),
      },
    ),
  )..interceptors.addAll([if (kDebugMode) LoggingInterceptor()]);
}

String _normalizeTransportBaseUrl(String baseUrl) {
  final normalized = baseUrl.trim();
  if (normalized.isEmpty ||
      normalized.startsWith('http://') ||
      normalized.startsWith('https://')) {
    return normalized;
  }
  return 'https://$normalized';
}
