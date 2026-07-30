import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/servers/data/repositories/server_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements KomodoApiClient {}

class _FakeRpcRequest extends Fake implements RpcRequest<dynamic> {}

T _rightOrFail<T>(Either<Failure, T> result) => result.fold(
  (failure) => fail('Expected Right, got $failure'),
  (value) => value,
);

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

    RpcRequest<dynamic> capturedRead() =>
        verify(() => client.read(captureAny())).captured.single
            as RpcRequest<dynamic>;

    RpcRequest<dynamic> capturedWrite() =>
        verify(() => client.write(captureAny())).captured.single
            as RpcRequest<dynamic>;

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

    test('listServers sends ListServers with exact query payload', () async {
      when(() => client.read(any())).thenAnswer((_) async => <dynamic>[]);

      await repository.listServers();

      final request = capturedRead();
      expect(request.type, 'ListServers');
      expect(request.params, <String, dynamic>{
        'query': <String, dynamic>{
          'terms': '',
          'names': <String>[],
          'templates': 'Include',
          'tags': <String>[],
          'tag_behavior': 'All',
          'specific': <String, dynamic>{},
        },
        'sort_by': 'Name',
        'sort_desc': false,
        'page': 0,
        'limit': 50,
      });
    });

    test('getServer sends GetServer with server param', () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => <String, dynamic>{'id': 'server-1', 'name': 'alpha'},
      );

      final result = await repository.getServer('server-1');

      expect(_rightOrFail(result).name, 'alpha');

      final request = capturedRead();
      expect(request.type, 'GetServer');
      expect(request.params, <String, dynamic>{'server': 'server-1'});
    });

    test('getSystemStats sends GetSystemStats with server param', () async {
      when(
        () => client.read(any()),
      ).thenAnswer((_) async => <String, dynamic>{});

      final result = await repository.getSystemStats('server-1');

      _rightOrFail(result);

      final request = capturedRead();
      expect(request.type, 'GetSystemStats');
      expect(request.params, <String, dynamic>{'server': 'server-1'});
    });

    test('getSystemInformation sends GetSystemInformation with server param',
        () async {
      when(
        () => client.read(any()),
      ).thenAnswer((_) async => <String, dynamic>{});

      final result = await repository.getSystemInformation('server-1');

      _rightOrFail(result);

      final request = capturedRead();
      expect(request.type, 'GetSystemInformation');
      expect(request.params, <String, dynamic>{'server': 'server-1'});
    });

    test('listDockerNetworks sends ListNetworks and parses names',
        () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => [
          {'name': ' bridge '},
          {'other': 'ignored'},
          {'name': ''},
        ],
      );

      final result = await repository.listDockerNetworks('server-1');

      expect(_rightOrFail(result), ['bridge']);

      final request = capturedRead();
      expect(request.type, 'ListNetworks');
      expect(request.params, <String, dynamic>{'server': 'server-1'});
    });

    test('updateServerConfig sends UpdateServer via write with id and config',
        () async {
      when(() => client.write(any())).thenAnswer(
        (_) async => <String, dynamic>{'id': 'server-1', 'name': 'alpha'},
      );

      final result = await repository.updateServerConfig(
        serverId: 'server-1',
        partialConfig: {'address': 'https://periphery:8120'},
      );

      expect(_rightOrFail(result).id, 'server-1');

      final request = capturedWrite();
      expect(request.type, 'UpdateServer');
      expect(request.params, <String, dynamic>{
        'id': 'server-1',
        'config': {'address': 'https://periphery:8120'},
      });
      verifyNever(() => client.execute(any()));
    });
  });
}
