import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/api/komodo_api_capabilities.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/containers/data/repositories/container_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements KomodoApiClient {
  KomodoApiCapabilities capabilitiesValue =
      KomodoApiCapabilities.v23AndNewer;

  @override
  KomodoApiCapabilities get capabilities => capabilitiesValue;
}

class _FakeRpcRequest extends Fake implements RpcRequest<dynamic> {}

T _rightOrFail<T>(Either<Failure, T> result) => result.fold(
  (failure) => fail('Expected Right, got $failure'),
  (value) => value,
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRpcRequest());
  });

  group('ContainerRepository', () {
    late _MockApiClient client;
    late ContainerRepository repository;

    setUp(() {
      client = _MockApiClient();
      repository = ContainerRepository(client);
    });

    RpcRequest<dynamic> capturedRead() =>
        verify(() => client.read(captureAny())).captured.single
            as RpcRequest<dynamic>;

    RpcRequest<dynamic> capturedExecute() =>
        verify(() => client.execute(captureAny())).captured.single
            as RpcRequest<dynamic>;

    test('listDockerContainers sends ListContainers with server param',
        () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => [
          {'name': 'web', 'state': 'running'},
        ],
      );

      final result = await repository.listDockerContainers('server-1');

      expect(_rightOrFail(result).single.name, 'web');

      final request = capturedRead();
      expect(request.type, 'ListContainers');
      expect(request.params, <String, dynamic>{'server': 'server-1'});
    });

    test('Komodo 2.2 lists containers with ListDockerContainers', () async {
      client.capabilitiesValue = KomodoApiCapabilities.v22;
      when(() => client.read(any())).thenAnswer((_) async => <dynamic>[]);

      await repository.listDockerContainers('server-1');

      expect(capturedRead().type, 'ListDockerContainers');
    });

    test('getContainerLog sends GetContainerLog with exact default params',
        () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => <String, dynamic>{'stdout': 'log line'},
      );

      final result = await repository.getContainerLog(
        serverIdOrName: 'server-1',
        containerIdOrName: 'web',
      );

      expect(_rightOrFail(result).stdout, 'log line');

      final request = capturedRead();
      expect(request.type, 'GetContainerLog');
      expect(request.params, <String, dynamic>{
        'server': 'server-1',
        'container': 'web',
        'tail': 200,
        'timestamps': false,
      });
    });

    test('stopContainer sends StopContainer via execute with exact payload',
        () async {
      when(
        () => client.execute(any()),
      ).thenAnswer((_) async => <String, dynamic>{});

      final result = await repository.stopContainer(
        serverIdOrName: 'server-1',
        containerIdOrName: 'web',
      );

      _rightOrFail(result);

      final request = capturedExecute();
      expect(request.type, 'StopContainer');
      expect(request.params, <String, dynamic>{
        'server': 'server-1',
        'container': 'web',
      });
      verifyNever(() => client.write(any()));
    });

    test(
        'restartContainer sends RestartContainer via execute '
        'with exact payload', () async {
      when(
        () => client.execute(any()),
      ).thenAnswer((_) async => <String, dynamic>{});

      final result = await repository.restartContainer(
        serverIdOrName: 'server-1',
        containerIdOrName: 'web',
      );

      _rightOrFail(result);

      final request = capturedExecute();
      expect(request.type, 'RestartContainer');
      expect(request.params, <String, dynamic>{
        'server': 'server-1',
        'container': 'web',
      });
      verifyNever(() => client.write(any()));
    });

    test('stopContainer maps 401 to auth failure', () async {
      when(() => client.execute(any())).thenThrow(
        const ApiException(message: 'Unauthorized', statusCode: 401),
      );

      final result = await repository.stopContainer(
        serverIdOrName: 'server-1',
        containerIdOrName: 'web',
      );

      result.fold(
        (failure) => expect(failure, const Failure.auth()),
        (_) => fail('Expected auth failure'),
      );
    });

    test('restartContainer maps generic ApiException to server failure',
        () async {
      when(() => client.execute(any())).thenThrow(
        const ApiException(message: 'boom', statusCode: 500),
      );

      final result = await repository.restartContainer(
        serverIdOrName: 'server-1',
        containerIdOrName: 'web',
      );

      result.fold(
        (failure) => expect(
          failure,
          const Failure.server(message: 'boom', statusCode: 500),
        ),
        (_) => fail('Expected server failure'),
      );
    });
  });
}
