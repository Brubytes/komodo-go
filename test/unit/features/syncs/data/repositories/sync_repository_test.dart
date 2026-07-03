import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/syncs/data/repositories/sync_repository.dart';
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

  group('SyncRepository', () {
    late _MockApiClient client;
    late SyncRepository repository;

    setUp(() {
      client = _MockApiClient();
      repository = SyncRepository(client);
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

    test('listSyncs sends ListResourceSyncs with exact query payload',
        () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => [
          {'id': 'sync-1', 'name': 'main', 'info': <String, dynamic>{}},
        ],
      );

      final result = await repository.listSyncs();

      expect(_rightOrFail(result).single.id, 'sync-1');

      final request = capturedRead();
      expect(request.type, 'ListResourceSyncs');
      expect(request.params, <String, dynamic>{
        'query': <String, dynamic>{
          'names': <String>[],
          'templates': 'Include',
          'tags': <String>[],
          'tag_behavior': 'All',
          'specific': <String, dynamic>{'repos': <String>[]},
        },
      });
    });

    test('getSync sends GetResourceSync with sync param', () async {
      when(() => client.read(any())).thenAnswer(
        (_) async => <String, dynamic>{
          'id': 'sync-1',
          'name': 'main',
          'config': <String, dynamic>{},
          'info': <String, dynamic>{},
        },
      );

      final result = await repository.getSync('sync-1');

      expect(_rightOrFail(result).name, 'main');

      final request = capturedRead();
      expect(request.type, 'GetResourceSync');
      expect(request.params, <String, dynamic>{'sync': 'sync-1'});
    });

    test('runSync sends RunSync via execute with null optionals by default',
        () async {
      when(
        () => client.execute(any()),
      ).thenAnswer((_) async => <String, dynamic>{});

      final result = await repository.runSync('sync-1');

      _rightOrFail(result);

      final request = capturedExecute();
      expect(request.type, 'RunSync');
      expect(request.params, <String, dynamic>{
        'sync': 'sync-1',
        'resource_type': null,
        'resources': null,
      });
      verifyNever(() => client.write(any()));
    });

    test('runSync forwards resource_type and resources', () async {
      when(
        () => client.execute(any()),
      ).thenAnswer((_) async => <String, dynamic>{});

      final result = await repository.runSync(
        'sync-1',
        resourceType: 'Stack',
        resources: ['web'],
      );

      _rightOrFail(result);

      final request = capturedExecute();
      expect(request.type, 'RunSync');
      expect(request.params, <String, dynamic>{
        'sync': 'sync-1',
        'resource_type': 'Stack',
        'resources': ['web'],
      });
    });

    test(
        'updateSyncConfig sends UpdateResourceSync via write '
        'with id and config', () async {
      when(() => client.write(any())).thenAnswer(
        (_) async => <String, dynamic>{
          'id': 'sync-1',
          'name': 'main',
          'config': <String, dynamic>{},
          'info': <String, dynamic>{},
        },
      );

      final result = await repository.updateSyncConfig(
        syncId: 'sync-1',
        partialConfig: {'managed': true},
      );

      expect(_rightOrFail(result).id, 'sync-1');

      final request = capturedWrite();
      expect(request.type, 'UpdateResourceSync');
      expect(request.params, <String, dynamic>{
        'id': 'sync-1',
        'config': {'managed': true},
      });
      verifyNever(() => client.execute(any()));
    });

    test('runSync maps 401 to auth failure', () async {
      when(() => client.execute(any())).thenThrow(
        const ApiException(message: 'Unauthorized', statusCode: 401),
      );

      final result = await repository.runSync('sync-1');

      result.fold(
        (failure) => expect(failure, const Failure.auth()),
        (_) => fail('Expected auth failure'),
      );
    });

    test('runSync maps generic ApiException to server failure', () async {
      when(() => client.execute(any())).thenThrow(
        const ApiException(message: 'boom', statusCode: 500),
      );

      final result = await repository.runSync('sync-1');

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
