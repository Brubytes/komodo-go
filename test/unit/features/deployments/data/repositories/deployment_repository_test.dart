import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/api/komodo_api_capabilities.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/deployments/data/repositories/deployment_repository.dart';
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

  group('DeploymentRepository', () {
    late _MockApiClient client;
    late DeploymentRepository repository;

    setUp(() {
      client = _MockApiClient();
      repository = DeploymentRepository(client);
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
      test(
        'listDeployments sends ListDeployments with exact query payload',
        () async {
          when(() => client.read(any())).thenAnswer(
            (_) async => [
              {'id': 'dep-1', 'name': 'api'},
            ],
          );

          final result = await repository.listDeployments();

          expect(_rightOrFail(result).single.id, 'dep-1');

          final request = capturedRead();
          expect(request.type, 'ListDeployments');
          expect(request.params, <String, dynamic>{
            'query': <String, dynamic>{
              'terms': '',
              'names': <String>[],
              'templates': 'Include',
              'tags': <String>[],
              'tag_behavior': 'All',
              'specific': <String, dynamic>{
                'server_ids': <String>[],
                'build_ids': <String>[],
                'update_available': false,
              },
            },
            'sort_by': 'Name',
            'sort_desc': false,
            'page': 0,
            'limit': 50,
          });
        },
      );

      test('getDeployment sends GetDeployment with deployment param', () async {
        when(() => client.read(any())).thenAnswer(
          (_) async => <String, dynamic>{'id': 'dep-1', 'name': 'api'},
        );

        final result = await repository.getDeployment('dep-1');

        expect(_rightOrFail(result).name, 'api');

        final request = capturedRead();
        expect(request.type, 'GetDeployment');
        expect(request.params, <String, dynamic>{'deployment': 'dep-1'});
      });
    });

    group('write payloads', () {
      test('checkForUpdate suppresses configured auto-update', () async {
        when(() => client.write(any())).thenAnswer(
          (_) async => <String, dynamic>{
            'deployment': 'dep-1',
            'update_available': true,
          },
        );

        expect(_rightOrFail(await repository.checkForUpdate('dep-1')), isTrue);

        final request = capturedWrite();
        expect(request.type, 'CheckDeploymentForUpdate');
        expect(request.params, <String, dynamic>{
          'deployment': 'dep-1',
          'skip_auto_update': true,
          'wait_for_auto_update': false,
        });
      });

      test(
        'updateDeploymentConfig sends UpdateDeployment with id and config',
        () async {
          when(() => client.write(any())).thenAnswer(
            (_) async => <String, dynamic>{'id': 'dep-1', 'name': 'api'},
          );

          final result = await repository.updateDeploymentConfig(
            deploymentId: 'dep-1',
            partialConfig: {'network': 'host'},
          );

          expect(_rightOrFail(result).id, 'dep-1');

          final request = capturedWrite();
          expect(request.type, 'UpdateDeployment');
          expect(request.params, <String, dynamic>{
            'id': 'dep-1',
            'config': {'network': 'host'},
          });
          verifyNever(() => client.execute(any()));
        },
      );
    });

    test('searchServerLog uses server-side search parameters', () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => <String, dynamic>{'stdout': 'timeout'},
      );

      final result = await repository.searchServerLog(
        deploymentIdOrName: 'dep-1',
        terms: const ['error', 'timeout'],
        combinator: LogSearchCombinator.or,
        invert: true,
      );

      expect(_rightOrFail(result).stdout, 'timeout');
      final request = capturedRead();
      expect(request.type, 'SearchDeploymentLog');
      expect(request.params, <String, dynamic>{
        'deployment': 'dep-1',
        'terms': ['error', 'timeout'],
        'combinator': 'Or',
        'invert': true,
        'timestamps': true,
      });
    });

    group('execute payloads', () {
      setUp(() {
        when(
          () => client.execute(any()),
        ).thenAnswer((_) async => <String, dynamic>{});
      });

      // All deployment actions share the {deployment} payload shape.
      final actions = <String, Future<Either<Failure, void>> Function()>{
        'StartDeployment': () => repository.startDeployment('dep-1'),
        'StopDeployment': () => repository.stopDeployment('dep-1'),
        'RestartDeployment': () => repository.restartDeployment('dep-1'),
        'DestroyDeployment': () => repository.destroyDeployment('dep-1'),
        'PauseDeployment': () => repository.pauseDeployment('dep-1'),
        'UnpauseDeployment': () => repository.unpauseDeployment('dep-1'),
        'Deploy': () => repository.deploy('dep-1'),
        'PullDeployment': () => repository.pullDeployment('dep-1'),
      };

      for (final entry in actions.entries) {
        test('${entry.key} is sent via execute with exact payload', () async {
          final result = await entry.value();

          _rightOrFail(result);

          final request = capturedExecute();
          expect(request.type, entry.key);
          expect(request.params, <String, dynamic>{'deployment': 'dep-1'});
          verifyNever(() => client.write(any()));
          verifyNever(() => client.read(any()));
        });
      }
    });

    group('failure mapping', () {
      test('restartDeployment maps 401 to auth failure', () async {
        when(() => client.execute(any())).thenThrow(
          const ApiException(message: 'Unauthorized', statusCode: 401),
        );

        final result = await repository.restartDeployment('dep-1');

        result.fold(
          (failure) => expect(failure, const Failure.auth()),
          (_) => fail('Expected auth failure'),
        );
      });

      test(
        'destroyDeployment maps generic ApiException to server failure',
        () async {
          when(() => client.execute(any())).thenThrow(
            const ApiException(message: 'boom', statusCode: 500),
          );

          final result = await repository.destroyDeployment('dep-1');

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
