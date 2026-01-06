import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/api_client.dart';
import '../api/interceptors/auth_interceptor.dart';
import '../api/interceptors/logging_interceptor.dart';
import '../storage/secure_storage_service.dart';

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

  void setActive(ActiveConnectionData data) {
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
      baseUrl: credentials.baseUrl,
      contentType: 'application/json',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(
      apiKey: credentials.apiKey,
      apiSecret: credentials.apiSecret,
    ),
    LoggingInterceptor(),
  ]);

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
      baseUrl: baseUrl,
      contentType: 'application/json',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'X-Api-Key': credentials.apiKey,
        'X-Api-Secret': credentials.apiSecret,
      },
    ),
  )..interceptors.add(LoggingInterceptor());
}
