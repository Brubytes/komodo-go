import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/api_client.dart';
import '../api/interceptors/auth_interceptor.dart';
import '../api/interceptors/logging_interceptor.dart';
import '../storage/secure_storage_service.dart';
import 'storage_provider.dart';

part 'dio_provider.g.dart';

/// Provides the base URL for the Komodo API.
/// This is a simple state that can be updated when credentials change.
@riverpod
class BaseUrl extends _$BaseUrl {
  @override
  String? build() => null;

  void setBaseUrl(String url) {
    state = url;
  }

  void clear() {
    state = null;
  }
}

/// Provides the Dio HTTP client configured for Komodo API.
@riverpod
Dio dio(Ref ref) {
  final baseUrl = ref.watch(baseUrlProvider);
  final storage = ref.watch(secureStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl ?? '',
      contentType: 'application/json',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(storage),
    LoggingInterceptor(),
  ]);

  return dio;
}

/// Provides the Komodo API client.
@riverpod
KomodoApiClient apiClient(Ref ref) {
  return KomodoApiClient(ref.watch(dioProvider));
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
