import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_call.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/api/custom_header.dart';
import 'package:komodo_go/core/api/komodo_api_capabilities.dart';
import 'package:komodo_go/core/api/proxy_auth.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository.g.dart';

typedef ValidationDioFactory =
    Dio Function(
      String baseUrl,
      ApiCredentials credentials,
    );

ApiCredentials normalizeCredentials({
  required String baseUrl,
  required String apiKey,
  required String apiSecret,
  bool proxyAuthEnabled = false,
  String? proxyAuthUsername,
  String? proxyAuthPassword,
  List<CustomHeader> customHeaders = const <CustomHeader>[],
}) {
  var normalizedUrl = baseUrl.trim();
  if (normalizedUrl.endsWith('/')) {
    normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
  }

  final normalizedProxyAuthUsername = _normalizeOptionalSecret(
    proxyAuthUsername,
  );
  final normalizedProxyAuthPassword = _normalizeOptionalSecret(
    proxyAuthPassword,
  );

  return ApiCredentials(
    baseUrl: normalizedUrl,
    apiKey: apiKey.trim(),
    apiSecret: apiSecret.trim(),
    proxyAuth: switch ((
      normalizedProxyAuthUsername,
      normalizedProxyAuthPassword,
    )) {
      (final username?, final password?) => ProxyAuthConfig(
        scheme: ProxyAuthScheme.basic,
        username: username,
        password: password,
        enabled: proxyAuthEnabled,
      ),
      _ => null,
    },
    customHeaders: sanitizeCustomHeaders(customHeaders),
  );
}

String? _normalizeOptionalSecret(String? value) {
  if (value == null) {
    return null;
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

/// Repository for handling authentication operations.
class AuthRepository {
  AuthRepository({ValidationDioFactory? validationDioFactory})
    : _validationDioFactory = validationDioFactory ?? createValidationDio;

  static const _executeProbePayload = <String, dynamic>{
    'type': '__komodo_go_proxy_probe__',
    'params': <String, dynamic>{},
  };

  final ValidationDioFactory _validationDioFactory;

  /// Validates credentials by making a test API call.
  Future<Either<Failure, KomodoCoreVersion>> validateCredentials(
    ApiCredentials credentials,
  ) async {
    return apiCall(
      () async {
        final dio = _validationDioFactory(credentials.baseUrl, credentials);
        final client = KomodoApiClient(dio);

        // Try to get the API version to validate credentials
        final versionResponse = await client.read(
          const RpcRequest(type: 'GetVersion', params: <String, dynamic>{}),
        );
        final version = _validateVersionProbeResponse(versionResponse);

        await _probeExecutePath(dio);

        return version;
      },
      onApiException: (e) {
        if (_looksLikeExecutePathBlocked(e)) {
          return Failure.server(message: e.message, statusCode: e.statusCode);
        }
        if (e.isUnauthorized || e.isForbidden) {
          if ((credentials.proxyAuth?.shouldApply ?? false) &&
              _looksLikeForwardedProxyAuth(e)) {
            return const Failure.auth(
              message:
                  'Your reverse proxy forwarded the Authorization header to Komodo. '
                  'Configure the proxy to clear or override Authorization before forwarding requests.',
            );
          }
          return const Failure.auth(message: 'Invalid API credentials');
        }
        return Failure.server(message: e.message, statusCode: e.statusCode);
      },
      onDioException: (_) => const Failure.network(
        message:
            'Cannot reach the server. Check your connection and server address.',
      ),
    );
  }

  KomodoCoreVersion _validateVersionProbeResponse(Object? response) {
    if (response case {
      'version': final String version,
    } when version.trim().isNotEmpty) {
      return KomodoCoreVersion.parse(version);
    }

    throw const ApiException(
      message:
          'Received an unexpected response for GetVersion. Your reverse proxy may be serving a login page instead of the Komodo API.',
    );
  }

  bool _looksLikeForwardedProxyAuth(ApiException error) {
    final message = error.message.toLowerCase();
    return message.contains('authenticate jwt') ||
        message.contains('invalidtoken') ||
        message.contains('token');
  }

  bool _looksLikeExecutePathBlocked(ApiException error) {
    final message = error.message.toLowerCase();
    return message.contains(
      'connection works for /read, but your reverse proxy',
    );
  }

  Future<void> _probeExecutePath(Dio dio) async {
    final response = await dio.post<dynamic>(
      '/execute',
      data: _executeProbePayload,
      options: Options(
        followRedirects: false,
        maxRedirects: 0,
        validateStatus: (status) => status != null,
      ),
    );

    final statusCode = response.statusCode;
    if (statusCode == null) {
      throw const ApiException(
        message:
            'Connection works for /read, but /execute returned no HTTP status. Check your reverse proxy configuration.',
      );
    }

    if (statusCode >= 300 && statusCode < 400) {
      final location = response.headers.value('location')?.trim();
      final locationInfo = location != null && location.isNotEmpty
          ? ' Redirect target: $location.'
          : '';
      throw ApiException(
        message:
            'Connection works for /read, but your reverse proxy redirected /execute to authentication.$locationInfo '
            'Configure machine access for /execute as well (same policy as /read and /write).',
        statusCode: statusCode,
      );
    }

    if (statusCode == 401 || statusCode == 403) {
      throw ApiException(
        message:
            'Connection works for /read, but your reverse proxy still requires authentication for /execute. Configure machine access for /execute as well (same policy as /read and /write).',
        statusCode: statusCode,
      );
    }

    if (!_looksLikeApiResponsePayload(response.data)) {
      throw ApiException(
        message:
            'Connection works for /read, but /execute returned a non-API response. Your reverse proxy may still be serving a login page for /execute.',
        statusCode: statusCode,
      );
    }
  }

  bool _looksLikeApiResponsePayload(Object? data) {
    if (data is Map || data is List) {
      return true;
    }

    if (data is String) {
      final trimmed = data.trimLeft();
      if (trimmed.isEmpty) {
        return false;
      }

      final lower = trimmed.toLowerCase();
      return !(lower.startsWith('<!doctype html') ||
          lower.startsWith('<html') ||
          lower.startsWith('<head') ||
          lower.startsWith('<body'));
    }

    return false;
  }

  /// Authenticates with the given credentials.
  /// Validates the credentials and returns normalized credentials if valid.
  Future<Either<Failure, ApiCredentials>> authenticate({
    required String baseUrl,
    required String apiKey,
    required String apiSecret,
    bool proxyAuthEnabled = false,
    String? proxyAuthUsername,
    String? proxyAuthPassword,
    List<CustomHeader> customHeaders = const <CustomHeader>[],
  }) async {
    final credentials = normalizeCredentials(
      baseUrl: baseUrl,
      apiKey: apiKey,
      apiSecret: apiSecret,
      proxyAuthEnabled: proxyAuthEnabled,
      proxyAuthUsername: proxyAuthUsername,
      proxyAuthPassword: proxyAuthPassword,
      customHeaders: customHeaders,
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
