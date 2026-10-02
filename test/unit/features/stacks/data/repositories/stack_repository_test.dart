import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/api/komodo_api_capabilities.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/stacks/data/repositories/stack_repository.dart';
import 'package:komodo_go/shared/logs/server_log.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements KomodoApiClient {
  @override
  KomodoApiCapabilities get capabilities => KomodoApiCapabilities.v23AndNewer;
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

  group('StackRepository', () {
    late _MockApiClient client;
    late StackRepository repository;

    setUp(() {
      client = _MockApiClient();
      repository = StackRepository(client);
    });

    RpcRequest<dynamic> capturedRead() =>
        verify(() => client.read(captureAny())).captured.single
            as RpcRequest<dynamic>;

    RpcRequest<dynamic> capturedWrite() =>
        verify(() => client.write(captureAny())).captured.single
            as RpcRequest<dynamic>;

    RpcRequest<dynamic> capturedExecute() =>
        verify(() => client.execute(captureAny())).captured.single
            as RpcRequest<dynamic>;

    group('reads', () {
      test('listStacks sends ListStacks with exact query payload', () async {
        when(() => client.read(any())).thenAnswer(
          (_) async => [
            {
              'id': 'stack-1',
              'name': 'web',
              'info': <String, dynamic>{'state': 'Running'},
            },
          ],
        );

        final result = await repository.listStacks();

        final stacks = _rightOrFail(result);
        expect(stacks, hasLength(1));
        expect(stacks.first.id, 'stack-1');

        final request = capturedRead();
        expect(request.type, 'ListStacks');
        expect(request.params, <String, dynamic>{
          'query': <String, dynamic>{
            'terms': '',
            'names': <String>[],
            'templates': 'Include',
            'tags': <String>[],
            'tag_behavior': 'All',
            'specific': <String, dynamic>{
              'server_ids': <String>[],
              'linked_repos': <String>[],
              'repos': <String>[],
              'update_available': false,
            },
          },
          'sort_by': 'Name',
          'sort_desc': false,
          'page': 0,
          'limit': 50,
        });
      });

      test('getStack sends GetStack with stack param', () async {
        when(() => client.read(any())).thenAnswer(
          (_) async => <String, dynamic>{
            'id': 'stack-1',
            'name': 'web',
            'config': <String, dynamic>{},
            'info': <String, dynamic>{},
          },
        );

        final result = await repository.getStack('stack-1');

        expect(_rightOrFail(result).name, 'web');

        final request = capturedRead();
        expect(request.type, 'GetStack');
        expect(request.params, <String, dynamic>{'stack': 'stack-1'});
      });

      test(
        'listStackServices sends ListStackServices with stack param',
        () async {
          when(() => client.read(any())).thenAnswer(
            (_) async => [
              {'service': 'db'},
            ],
          );

          final result = await repository.listStackServices('stack-1');

          expect(_rightOrFail(result).single.service, 'db');

          final request = capturedRead();
          expect(request.type, 'ListStackServices');
          expect(request.params, <String, dynamic>{'stack': 'stack-1'});
        },
      );

      test('getStackLog sends GetStackLog with exact params', () async {
        when(() => client.read(any())).thenAnswer(
          (_) async => <String, dynamic>{'stdout': 'hello'},
        );

        final result = await repository.getStackLog(stackIdOrName: 'stack-1');

        expect(_rightOrFail(result).stdout, 'hello');

        final request = capturedRead();
        expect(request.type, 'GetStackLog');
        expect(request.params, <String, dynamic>{
          'stack': 'stack-1',
          'services': <String>[],
          'tail': 200,
          'timestamps': true,
        });
      });
    });

    group('execute payloads', () {
      setUp(() {
        when(
          () => client.execute(any()),
        ).thenAnswer((_) async => <String, dynamic>{});
      });

      test(
        'deployStack sends DeployStack with exact default payload',
        () async {
          final result = await repository.deployStack('stack-1');

          _rightOrFail(result);

          final request = capturedExecute();
          expect(request.type, 'DeployStack');
          expect(request.params, <String, dynamic>{
            'stack': 'stack-1',
            'services': <String>[],
            'stop_time': null,
          });
          verifyNever(() => client.write(any()));
          verifyNever(() => client.read(any()));
        },
      );

      test('deployStackIfChanged uses the conditional execute RPC', () async {
        _rightOrFail(await repository.deployStackIfChanged('stack-1'));

        final request = capturedExecute();
        expect(request.type, 'DeployStackIfChanged');
        expect(request.params, <String, dynamic>{
          'stack': 'stack-1',
          'stop_time': null,
        });
      });

      test('deployStack forwards services and stop_time', () async {
        final result = await repository.deployStack(
          'stack-1',
          services: ['web', 'db'],
          stopTime: 30,
        );

        _rightOrFail(result);

        final request = capturedExecute();
        expect(request.type, 'DeployStack');
        expect(request.params, <String, dynamic>{
          'stack': 'stack-1',
          'services': ['web', 'db'],
          'stop_time': 30,
        });
      });

      test('stopStack sends StopStack with exact payload', () async {
        final result = await repository.stopStack('stack-1', stopTime: 10);

        _rightOrFail(result);

        final request = capturedExecute();
        expect(request.type, 'StopStack');
        expect(request.params, <String, dynamic>{
          'stack': 'stack-1',
          'services': <String>[],
          'stop_time': 10,
        });
      });

      // These stack actions all share the {stack, services} payload shape.
      final serviceActions = <String, Future<Either<Failure, void>> Function()>{
        'PullStack': () => repository.pullStackImages('stack-1'),
        'RestartStack': () => repository.restartStack('stack-1'),
        'PauseStack': () => repository.pauseStack('stack-1'),
        'StartStack': () => repository.startStack('stack-1'),
        'DestroyStack': () => repository.destroyStack('stack-1'),
      };

      for (final entry in serviceActions.entries) {
        test('${entry.key} is sent via execute with exact payload', () async {
          final result = await entry.value();

          _rightOrFail(result);

          final request = capturedExecute();
          expect(request.type, entry.key);
          expect(request.params, <String, dynamic>{
            'stack': 'stack-1',
            'services': <String>[],
          });
          verifyNever(() => client.write(any()));
        });
      }
    });

    test(
      'checkForUpdates returns service status and skips auto deploy',
      () async {
        when(() => client.write(any())).thenAnswer(
          (_) async => <String, dynamic>{
            'stack': 'stack-1',
            'services': [
              {'service': 'web', 'update_available': true},
            ],
          },
        );

        final result = await repository.checkForUpdates('stack-1');

        expect(_rightOrFail(result).single.updateAvailable, isTrue);
        final request = capturedWrite();
        expect(request.type, 'CheckStackForUpdate');
        expect(request.params, <String, dynamic>{
          'stack': 'stack-1',
          'skip_auto_update': true,
          'wait_for_auto_update': false,
          'skip_cache_refresh': false,
        });
      },
    );

    test(
      'searchServerLog includes stack services and AND combinator',
      () async {
        when(() => client.read(any())).thenAnswer(
          (_) async => <String, dynamic>{'stdout': 'matched'},
        );

        final result = await repository.searchServerLog(
          stackIdOrName: 'stack-1',
          services: const ['api'],
          terms: const ['error', 'timeout'],
          combinator: LogSearchCombinator.and,
        );

        expect(_rightOrFail(result).stdout, 'matched');
        final request = capturedRead();
        expect(request.type, 'SearchStackLog');
        expect(request.params, <String, dynamic>{
          'stack': 'stack-1',
          'services': ['api'],
          'terms': ['error', 'timeout'],
          'combinator': 'And',
          'invert': false,
          'timestamps': true,
        });
      },
    );

    group('write payloads', () {
      test(
        'writeStackFileContents sends WriteStackFileContents via write',
        () async {
          when(
            () => client.write(any()),
          ).thenAnswer((_) async => <String, dynamic>{});

          final result = await repository.writeStackFileContents(
            stackIdOrName: 'stack-1',
            filePath: 'compose.yaml',
            contents: 'services: {}',
          );

          _rightOrFail(result);

          final request = capturedWrite();
          expect(request.type, 'WriteStackFileContents');
          expect(request.params, <String, dynamic>{
            'stack': 'stack-1',
            'file_path': 'compose.yaml',
            'contents': 'services: {}',
          });
          verifyNever(() => client.execute(any()));
        },
      );

      test('updateStackConfig sends UpdateStack with id and config', () async {
        when(() => client.write(any())).thenAnswer(
          (_) async => <String, dynamic>{
            'id': 'stack-1',
            'name': 'web',
            'config': <String, dynamic>{},
            'info': <String, dynamic>{},
          },
        );

        final result = await repository.updateStackConfig(
          stackId: 'stack-1',
          partialConfig: {'auto_update': true},
        );

        expect(_rightOrFail(result).id, 'stack-1');

        final request = capturedWrite();
        expect(request.type, 'UpdateStack');
        expect(request.params, <String, dynamic>{
          'id': 'stack-1',
          'config': {'auto_update': true},
        });
        verifyNever(() => client.execute(any()));
      });
    });

    group('failure mapping', () {
      test('deployStack maps 401 to auth failure', () async {
        when(() => client.execute(any())).thenThrow(
          const ApiException(message: 'Unauthorized', statusCode: 401),
        );

        final result = await repository.deployStack('stack-1');

        result.fold(
          (failure) => expect(failure, const Failure.auth()),
          (_) => fail('Expected auth failure'),
        );
      });

      test(
        'destroyStack maps generic ApiException to server failure',
        () async {
          when(() => client.execute(any())).thenThrow(
            const ApiException(message: 'boom', statusCode: 500),
          );

          final result = await repository.destroyStack('stack-1');

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
  });
}
