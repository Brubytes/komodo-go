import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/api/custom_header.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';
import 'package:komodo_go/features/auth/data/repositories/auth_repository.dart';

void main() {
  group('AuthRepository', () {
    const credentials = ApiCredentials(
      baseUrl: 'https://komodo.example.com',
      apiKey: 'key',
      apiSecret: 'secret',
    );

    group('normalizeCredentials', () {
      test('keeps URL as entered when protocol is omitted', () {
        final credentials = normalizeCredentials(
          baseUrl: 'komodo.example.com',
          apiKey: 'key',
          apiSecret: 'secret',
        );

        expect(credentials.baseUrl, equals('komodo.example.com'));
      });

      test('preserves explicit http URLs', () {
        final credentials = normalizeCredentials(
          baseUrl: 'http://100.64.0.5:9120',
          apiKey: 'key',
          apiSecret: 'secret',
        );

        expect(credentials.baseUrl, equals('http://100.64.0.5:9120'));
      });

      test('removes trailing slash', () {
        final credentials = normalizeCredentials(
          baseUrl: 'https://komodo.example.com/',
          apiKey: 'key',
          apiSecret: 'secret',
        );

        expect(credentials.baseUrl, equals('https://komodo.example.com'));
      });

      test('trims key and secret', () {
        final credentials = normalizeCredentials(
          baseUrl: 'https://komodo.example.com',
          apiKey: '  key  ',
          apiSecret: '  secret  ',
        );

        expect(credentials.apiKey, equals('key'));
        expect(credentials.apiSecret, equals('secret'));
      });

      test('returns ApiCredentials', () {
        final credentials = normalizeCredentials(
          baseUrl: 'https://komodo.example.com',
          apiKey: 'key',
          apiSecret: 'secret',
        );

        expect(credentials, isA<ApiCredentials>());
      });

      test('trims optional proxy header auth fields', () {
        final credentials = normalizeCredentials(
          baseUrl: 'https://komodo.example.com',
          apiKey: 'key',
          apiSecret: 'secret',
          proxyAuthEnabled: true,
          proxyAuthUsername: '  user  ',
          proxyAuthPassword: '  pass  ',
        );

        expect(credentials.proxyAuth, isNotNull);
        expect(credentials.proxyAuth?.shouldApply, isTrue);
        expect(credentials.proxyAuth?.username, equals('user'));
        expect(credentials.proxyAuth?.password, equals('pass'));
      });

      test('keeps proxy auth stored but inactive by default', () {
        final credentials = normalizeCredentials(
          baseUrl: 'https://komodo.example.com',
          apiKey: 'key',
          apiSecret: 'secret',
          proxyAuthUsername: 'user',
          proxyAuthPassword: 'pass',
        );

        expect(credentials.proxyAuth, isNotNull);
        expect(credentials.proxyAuth?.enabled, isFalse);
        expect(credentials.proxyAuth?.shouldApply, isFalse);
      });

      test('normalizes blank optional proxy header auth fields to null', () {
        final credentials = normalizeCredentials(
          baseUrl: 'https://komodo.example.com',
          apiKey: 'key',
          apiSecret: 'secret',
          proxyAuthUsername: '   ',
          proxyAuthPassword: '',
        );

        expect(credentials.proxyAuth, isNull);
      });

      test('normalizes incomplete proxy auth pair to null', () {
        final credentials = normalizeCredentials(
          baseUrl: 'https://komodo.example.com',
          apiKey: 'key',
          apiSecret: 'secret',
          proxyAuthUsername: 'user',
          proxyAuthPassword: '   ',
        );

        expect(credentials.proxyAuth, isNull);
      });

      test('sanitizes custom headers and drops reserved keys', () {
        final credentials = normalizeCredentials(
          baseUrl: 'https://komodo.example.com',
          apiKey: 'key',
          apiSecret: 'secret',
          customHeaders: const [
            CustomHeader(key: ' X-Test ', value: ' one '),
            CustomHeader(key: 'Authorization', value: 'blocked'),
            CustomHeader(key: 'x-test', value: 'two'),
            CustomHeader(key: ' ', value: 'ignored'),
          ],
        );

        expect(credentials.customHeaders, hasLength(1));
        expect(credentials.customHeaders.single.key, equals('x-test'));
        expect(credentials.customHeaders.single.value, equals('two'));
      });
    });

    group('validateCredentials', () {
      test('rejects HTML responses returned for GetVersion', () async {
        final repository = AuthRepository(
          validationDioFactory: (_, _) => _createValidationDio((options) {
            if (options.path == '/read') {
              return _response(
                options,
                statusCode: 200,
                data: '<!doctype html><html><body>Login</body></html>',
              );
            }
            return _unexpectedRequest(options);
          }),
        );

        final result = await repository.validateCredentials(credentials);

        result.fold(
          (failure) => expect(
            failure,
            const Failure.server(
              message:
                  'Received an unexpected response for GetVersion. Your reverse proxy may be serving a login page instead of the Komodo API.',
            ),
          ),
          (_) => fail('Expected validation to fail'),
        );
      });

      test('rejects execute paths still blocked by proxy auth', () async {
        final repository = AuthRepository(
          validationDioFactory: (_, _) => _createValidationDio((options) {
            if (options.path == '/read') {
              return _response(
                options,
                statusCode: 200,
                data: const <String, dynamic>{'version': '1.0.0'},
              );
            }
            if (options.path == '/execute') {
              return _response(
                options,
                statusCode: 401,
                data: const <String, dynamic>{'error': 'Unauthorized'},
              );
            }
            return _unexpectedRequest(options);
          }),
        );

        final result = await repository.validateCredentials(credentials);

        result.fold(
          (failure) => expect(
            failure,
            const Failure.server(
              message:
                  'Connection works for /read, but your reverse proxy still requires authentication for /execute. Configure machine access for /execute as well (same policy as /read and /write).',
              statusCode: 401,
            ),
          ),
          (_) => fail('Expected validation to fail'),
        );
      });
    });

    test('createValidationDio disables redirects during validation', () {
      final dio = createValidationDio(credentials.baseUrl, credentials);

      expect(dio.options.followRedirects, isFalse);
      expect(dio.options.maxRedirects, 0);
    });
  });
}

Dio _createValidationDio(
  Response<dynamic> Function(RequestOptions options) responder,
) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(responder(options));
      },
    ),
  );
  return dio;
}

Response<dynamic> _response(
  RequestOptions requestOptions, {
  required int statusCode,
  Object? data,
  Map<String, List<String>> headers = const <String, List<String>>{},
}) {
  return Response<dynamic>(
    requestOptions: requestOptions,
    statusCode: statusCode,
    headers: Headers.fromMap(headers),
    data: data,
  );
}

Never _unexpectedRequest(RequestOptions options) {
  fail('Unexpected request to ${options.path}');
}
