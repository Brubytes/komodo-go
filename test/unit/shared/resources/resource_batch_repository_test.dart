import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/shared/resources/data/resource_batch_repository.dart';
import 'package:komodo_go/shared/resources/models/resource_batch.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements KomodoApiClient {}

class _FakeRpcRequest extends Fake implements RpcRequest<dynamic> {}

T _rightOrFail<T>(Either<Failure, T> result) => result.fold(
  (failure) => fail('Expected Right, got $failure'),
  (value) => value,
);

void main() {
  setUpAll(() => registerFallbackValue(_FakeRpcRequest()));

  group('ResourceBatchRepository', () {
    late _MockApiClient client;
    late ResourceBatchRepository repository;

    setUp(() {
      client = _MockApiClient();
      repository = ResourceBatchRepository(client);
    });

    const items = [
      ResourceBatchItem(id: 's1', name: 'one'),
      ResourceBatchItem(id: 's2', name: 'two'),
    ];

    test(
      'uses native batch endpoint and preserves every item result',
      () async {
        when(() => client.execute(any())).thenAnswer(
          (_) async => <Object?>[
            <String, dynamic>{
              'status': 'Ok',
              'data': <String, dynamic>{
                'id': 'update-1',
                'target': <String, dynamic>{'type': 'Stack', 'id': 's1'},
              },
            },
            <String, dynamic>{
              'status': 'Err',
              'data': <String, dynamic>{
                'name': 'two',
                'error': <String, dynamic>{'message': 'permission denied'},
              },
            },
          ],
        );

        final result = await repository.execute(
          kind: ResourceKind.stacks,
          action: ResourceBatchAction.deploy,
          items: items,
        );

        final values = _rightOrFail(result);
        expect(values, hasLength(2));
        expect(values.first.item.id, 's1');
        expect(values.first.success, isTrue);
        expect(values.first.updateId, 'update-1');
        expect(values.last.item.id, 's2');
        expect(values.last.success, isFalse);
        expect(values.last.error, 'permission denied');

        final request =
            verify(
                  () => client.execute(captureAny()),
                ).captured.single
                as RpcRequest<dynamic>;
        expect(request.type, 'BatchDeployStack');
        expect(request.params, <String, dynamic>{'pattern': 'one, two'});
      },
    );

    test(
      'runs unsupported batch operations individually and aggregates',
      () async {
        when(() => client.execute(any())).thenAnswer((invocation) async {
          final request =
              invocation.positionalArguments.single as RpcRequest<dynamic>;
          final params = request.params as Map<String, dynamic>;
          if (params['stack'] == 's2') {
            throw const ApiException(message: 'offline', statusCode: 503);
          }
          return <String, dynamic>{'id': 'update-start'};
        });

        final result = await repository.execute(
          kind: ResourceKind.stacks,
          action: ResourceBatchAction.start,
          items: items,
        );

        final values = _rightOrFail(result);
        expect(values.map((item) => item.success), [true, false]);
        expect(values.last.error, contains('offline'));
        final requests = verify(
          () => client.execute(captureAny()),
        ).captured.cast<RpcRequest<dynamic>>();
        expect(requests.map((request) => request.type), [
          'StartStack',
          'StartStack',
        ]);
        expect(requests.map((request) => request.params), [
          <String, dynamic>{'stack': 's1'},
          <String, dynamic>{'stack': 's2'},
        ]);
      },
    );

    test('maps run actions to native batch execution types', () async {
      when(() => client.execute(any())).thenAnswer((_) async => <Object?>[]);

      await repository.execute(
        kind: ResourceKind.actions,
        action: ResourceBatchAction.run,
        items: const [ResourceBatchItem(id: 'a1', name: 'action')],
      );

      final request =
          verify(
                () => client.execute(captureAny()),
              ).captured.single
              as RpcRequest<dynamic>;
      expect(request.type, 'BatchRunAction');
      expect(request.params, <String, dynamic>{'pattern': 'action'});
    });
  });
}
