import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';

void main() {
  for (final status in ['Complete', 'InProgress']) {
    for (final success in [true, false]) {
      test('execute handles HTTP 200 $status success=$success', () async {
        final payload = {'status': status, 'success': success};
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) => handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: payload,
                ),
              ),
            ),
          );
        addTearDown(dio.close);
        final result = KomodoApiClient(dio).execute(
          const RpcRequest(type: 'DeployStack', params: {'stack': 'qa'}),
        );
        if (status == 'Complete' && !success) {
          await expectLater(result, throwsA(isA<ApiException>()));
        } else {
          expect(await result, payload);
        }
      });
    }
  }
}
