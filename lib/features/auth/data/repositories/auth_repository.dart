import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/providers/dio_provider.dart';
import '../../../../core/providers/storage_provider.dart';
import '../../../../core/storage/secure_storage_service.dart';

part 'auth_repository.g.dart';

/// Repository for handling authentication operations.
class AuthRepository {
  AuthRepository({
    required SecureStorageService storage,
  }) : _storage = storage;

  final SecureStorageService _storage;

  /// Gets stored credentials if available.
  Future<ApiCredentials?> getStoredCredentials() {
    return _storage.getCredentials();
  }

  /// Validates credentials by making a test API call.
  Future<Either<Failure, void>> validateCredentials(
    ApiCredentials credentials,
  ) async {
    try {
      final dio = createValidationDio(credentials.baseUrl, credentials);
      final client = KomodoApiClient(dio);

      // Try to get the API version to validate credentials
      await client.read(
        const RpcRequest(type: 'GetVersion', params: <String, dynamic>{}),
      );

      return const Right(null);
    } on ApiException catch (e) {
      if (e.isUnauthorized || e.isForbidden) {
        return const Left(Failure.auth(message: 'Invalid API credentials'));
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } on DioException catch (_) {
      return const Left(
        Failure.network(message: 'Could not connect to server'),
      );
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  /// Authenticates with the given credentials.
  /// Validates the credentials and stores them if valid.
  Future<Either<Failure, ApiCredentials>> authenticate({
    required String baseUrl,
    required String apiKey,
    required String apiSecret,
  }) async {
    // Normalize base URL
    var normalizedUrl = baseUrl.trim();
    if (normalizedUrl.endsWith('/')) {
      normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
    }
    if (!normalizedUrl.startsWith('http')) {
      normalizedUrl = 'https://$normalizedUrl';
    }

    final credentials = ApiCredentials(
      baseUrl: normalizedUrl,
      apiKey: apiKey.trim(),
      apiSecret: apiSecret.trim(),
    );

    // Validate credentials
    final validationResult = await validateCredentials(credentials);

    return validationResult.fold(
      Left.new,
      (_) async {
        // Store credentials
        await _storage.saveCredentials(credentials);
        return Right(credentials);
      },
    );
  }

  /// Clears stored credentials.
  Future<void> logout() {
    return _storage.clearCredentials();
  }

  /// Checks if credentials are stored.
  Future<bool> hasStoredCredentials() {
    return _storage.hasCredentials();
  }
}

@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepository(
    storage: ref.watch(secureStorageProvider),
  );
}
