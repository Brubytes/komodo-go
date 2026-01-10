import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_call.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository.g.dart';

ApiCredentials normalizeCredentials({
  required String baseUrl,
  required String apiKey,
  required String apiSecret,
}) {
  // Normalize base URL
  var normalizedUrl = baseUrl.trim();
  if (normalizedUrl.endsWith('/')) {
    normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
  }
  if (!normalizedUrl.startsWith('http')) {
    normalizedUrl = 'https://$normalizedUrl';
  }

  return ApiCredentials(
    baseUrl: normalizedUrl,
    apiKey: apiKey.trim(),
    apiSecret: apiSecret.trim(),
  );
}

/// Repository for handling authentication operations.
class AuthRepository {
  /// Validates credentials by making a test API call.
  Future<Either<Failure, void>> validateCredentials(
    ApiCredentials credentials,
  ) async {
    return apiCall(
      () async {
        final dio = createValidationDio(credentials.baseUrl, credentials);
        final client = KomodoApiClient(dio);

        // Try to get the API version to validate credentials
        await client.read(
          const RpcRequest(type: 'GetVersion', params: <String, dynamic>{}),
        );

        return;
      },
      onApiException: (e) {
        if (e.isUnauthorized || e.isForbidden) {
          return const Failure.auth(message: 'Invalid API credentials');
        }
        return Failure.server(message: e.message, statusCode: e.statusCode);
      },
      onDioException: (_) =>
          const Failure.network(message: 'Could not connect to server'),
    );
  }

  /// Authenticates with the given credentials.
  /// Validates the credentials and returns normalized credentials if valid.
  Future<Either<Failure, ApiCredentials>> authenticate({
    required String baseUrl,
    required String apiKey,
    required String apiSecret,
  }) async {
    final credentials = normalizeCredentials(
      baseUrl: baseUrl,
      apiKey: apiKey,
      apiSecret: apiSecret,
    );

    // Validate credentials
    final validationResult = await validateCredentials(credentials);

    return validationResult.fold(Left.new, (_) => Right(credentials));
  }
}

@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepository();
}
