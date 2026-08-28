import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/api/komodo_api_capabilities.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/containers/data/models/container.dart';
import 'package:komodo_go/features/containers/data/repositories/container_repository.dart';
import 'package:komodo_go/shared/logs/server_log.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements KomodoApiClient {
  KomodoApiCapabilities capabilitiesValue = KomodoApiCapabilities.v23AndNewer;

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

    test(
      'listDockerContainers sends ListContainers with server param',
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
      },
    );

    test('Komodo 2.2 lists containers with ListDockerContainers', () async {
      client.capabilitiesValue = KomodoApiCapabilities.v22;
      when(() => client.read(any())).thenAnswer((_) async => <dynamic>[]);

      await repository.listDockerContainers('server-1');

      expect(capturedRead().type, 'ListDockerContainers');
    });

    test(
      'getContainerLog sends GetContainerLog with exact default params',
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
      },
    );

    test('searchServerLog sends SearchContainerLog to the server', () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => <String, dynamic>{'stdout': 'error line'},
      );

      final result = await repository.searchServerLog(
        serverIdOrName: 'server-1',
        containerIdOrName: 'web',
        terms: const ['error'],
        combinator: LogSearchCombinator.and,
      );

      expect(_rightOrFail(result).stdout, 'error line');
      final request = capturedRead();
      expect(request.type, 'SearchContainerLog');
      expect(request.params, <String, dynamic>{
        'server': 'server-1',
        'container': 'web',
        'terms': ['error'],
        'combinator': 'And',
        'invert': false,
        'timestamps': true,
      });
    });

    test(
      'inspectContainer parses Docker casing and retains raw inspection',
      () async {
        client.capabilitiesValue = KomodoApiCapabilities.v22;
        when(() => client.read(any())).thenAnswer(
          (_) async => <String, dynamic>{
            'Id': 'container-1',
            'Name': '/web',
            'Created': '2026-08-27T12:00:00Z',
            'Driver': 'overlay2',
            'Platform': 'linux',
            'RestartCount': 2,
            'Mounts': [
              {'Source': '/data', 'Destination': '/app/data'},
            ],
          },
        );

        final inspection = _rightOrFail(
          await repository.inspectContainer(
            serverIdOrName: 'server-1',
            containerIdOrName: 'web',
          ),
        );
        expect(inspection.id, 'container-1');
        expect(inspection.created, '2026-08-27T12:00:00Z');
        expect(inspection.driver, 'overlay2');
        expect(inspection.platform, 'linux');
        expect(inspection.restartCount, 2);
        expect(inspection.mounts.single['destination'], '/app/data');
        expect(inspection.raw['RestartCount'], 2);
        final request = capturedRead();
        expect(request.type, 'InspectDockerContainer');
        expect(request.params, <String, dynamic>{
          'server': 'server-1',
          'container': 'web',
        });
      },
    );

    test('getResourceMatchingContainer parses a Stack target', () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => <String, dynamic>{
          'resource': {'type': 'Stack', 'id': 'stack-1'},
        },
      );

      final resource = _rightOrFail(
        await repository.getResourceMatchingContainer(
          serverIdOrName: 'server-1',
          containerIdOrName: 'web',
        ),
      );
      expect(resource?.id, 'stack-1');
      final request = capturedRead();
      expect(request.type, 'GetResourceMatchingContainer');
    });

    test('infers a managed stack from Komodo compose paths', () async {
      when(() => client.read(any())).thenAnswer((invocation) async {
        final request =
            invocation.positionalArguments.single as RpcRequest<dynamic>;
        if (request.type == 'GetResourceMatchingContainer') {
          return <String, dynamic>{'resource': null};
        }
        return <String, dynamic>{
          'Config': <String, dynamic>{
            'Labels': <String, dynamic>{
              'com.docker.compose.project.working_dir':
                  '/opt/komodo/periphery_root/stacks/my-stack',
            },
          },
        };
      });

      final resource = _rightOrFail(
        await repository.getResourceMatchingContainer(
          serverIdOrName: 'server-1',
          containerIdOrName: 'web',
        ),
      );

      expect(resource?.type, ContainerResourceType.stack);
      expect(resource?.id, 'my-stack');
      final requests = verify(
        () => client.read(captureAny()),
      ).captured.cast<RpcRequest<dynamic>>();
      expect(requests.map((request) => request.type), [
        'GetResourceMatchingContainer',
        'InspectContainer',
      ]);
    });

    test(
      'start pause unpause and remove use documented execute RPCs',
      () async {
        when(
          () => client.execute(any()),
        ).thenAnswer((_) async => <String, dynamic>{});

        await repository.startContainer(
          serverIdOrName: 'server-1',
          containerIdOrName: 'web',
        );
        await repository.pauseContainer(
          serverIdOrName: 'server-1',
          containerIdOrName: 'web',
        );
        await repository.unpauseContainer(
          serverIdOrName: 'server-1',
          containerIdOrName: 'web',
        );
        await repository.removeContainer(
          serverIdOrName: 'server-1',
          containerIdOrName: 'web',
        );

        final requests = verify(
          () => client.execute(captureAny()),
        ).captured.cast<RpcRequest<dynamic>>();
        expect(requests.map((request) => request.type), [
          'StartContainer',
          'PauseContainer',
          'UnpauseContainer',
          'DestroyContainer',
        ]);
        expect(requests.last.params, <String, dynamic>{
          'server': 'server-1',
          'container': 'web',
          'signal': null,
          'time': null,
        });
      },
    );

    test(
      'stopContainer sends StopContainer via execute with exact payload',
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
      },
    );

    test('restartContainer sends RestartContainer via execute '
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

    test(
      'restartContainer maps generic ApiException to server failure',
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
      },
    );
  });
}
