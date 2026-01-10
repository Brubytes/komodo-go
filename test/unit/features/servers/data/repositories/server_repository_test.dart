import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/servers/data/repositories/server_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements KomodoApiClient {}

class _FakeRpcRequest extends Fake implements RpcRequest<dynamic> {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRpcRequest());
  });

  group('ServerRepository', () {
    late _MockApiClient client;
    late ServerRepository repository;

    setUp(() {
      client = _MockApiClient();
      repository = ServerRepository(client);
    });

    test('listServers returns parsed servers', () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => [
          {
            'id': 'server-1',
            'name': 'alpha',
            'info': {'state': 'Ok', 'address': '10.0.0.1'},
          },
        ],
      );

      final result = await repository.listServers();

      result.fold((failure) => fail('Expected servers, got $failure'), (
        servers,
      ) {
        expect(servers, hasLength(1));
        expect(servers.first.id, 'server-1');
        expect(servers.first.name, 'alpha');
      });
    });

    test('getServer maps unauthorized errors to auth failure', () async {
      when(
        () => client.read(any()),
      ).thenThrow(const ApiException(message: 'Unauthorized', statusCode: 401));

      final result = await repository.getServer('server-1');

      result.fold(
        (failure) => expect(failure, const Failure.auth()),
        (_) => fail('Expected auth failure'),
      );
    });
  });
}
