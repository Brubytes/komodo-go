import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/api/api_exception.dart';

void main() {
  group('ApiException.fromDioException', () {
    test('maps auth redirects to a proxy guidance message', () {
      final requestOptions = RequestOptions(path: '/execute');
      final response = Response<dynamic>(
        requestOptions: requestOptions,
        statusCode: 302,
        statusMessage: 'Found',
        headers: Headers.fromMap(<String, List<String>>{
          'location': <String>['https://auth.example.com/auth/resource/abc'],
        }),
        data: '<html>redirect</html>',
      );

      final error = DioException(
        requestOptions: requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );

      final exception = ApiException.fromDioException(error);

      expect(exception.statusCode, 302);
      expect(
        exception.message,
        contains('redirected to an authentication page'),
      );
      expect(exception.message, contains('/read, /write, and /execute'));
    });

    test('uses server error messages for non-redirect bad responses', () {
      final requestOptions = RequestOptions(path: '/read');
      final response = Response<dynamic>(
        requestOptions: requestOptions,
        statusCode: 400,
        statusMessage: 'Bad Request',
        data: <String, dynamic>{'message': 'Invalid payload'},
      );

      final error = DioException(
        requestOptions: requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );

      final exception = ApiException.fromDioException(error);

      expect(exception.statusCode, 400);
      expect(exception.message, 'Invalid payload');
    });
  });
}
