import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/api/komodo_api_capabilities.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';
import 'package:komodo_go/features/syncs/data/repositories/sync_repository.dart';
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

    test(
      'listSyncs sends ListResourceSyncs with exact query payload',
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
            'terms': '',
            'names': <String>[],
            'templates': 'Include',
            'tags': <String>[],
            'tag_behavior': 'All',
            'specific': <String, dynamic>{'repos': <String>[]},
          },
          'sort_by': 'Name',
          'sort_desc': false,
          'page': 0,
          'limit': 50,
        });
      },
    );

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

    test(
      'runSync sends RunSync via execute with null optionals by default',
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
      },
    );

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
      'refreshPending uses the write endpoint and parses the plan',
      () async {
        when(() => client.write(any())).thenAnswer(
          (_) async => <String, dynamic>{
            'id': 'sync-1',
            'name': 'main',
            'config': <String, dynamic>{},
            'info': <String, dynamic>{
              'resource_updates': <Object?>[
                <String, dynamic>{
                  'target': <String, dynamic>{'type': 'Stack', 'id': 'stack-1'},
                  'data': <String, dynamic>{
                    'type': 'Update',
                    'data': <String, dynamic>{
                      'current': 'name = "old"',
                      'proposed': 'name = "new"',
                    },
                  },
                },
              ],
            },
          },
        );

        final result = await repository.refreshPending('sync-1');

        expect(
          _rightOrFail(result).info.resourceUpdates.single.name,
          'stack-1',
        );
        final request = capturedWrite();
        expect(request.type, 'RefreshResourceSyncPending');
        expect(request.params, <String, dynamic>{'sync': 'sync-1'});
      },
    );

    test('commitSync sends CommitSync through write', () async {
      when(
        () => client.write(any()),
      ).thenAnswer((_) async => <String, dynamic>{'id': 'update-1'});

      final result = await repository.commitSync('sync-1');

      expect(_rightOrFail(result), 'update-1');
      final request = capturedWrite();
      expect(request.type, 'CommitSync');
      expect(request.params, <String, dynamic>{'sync': 'sync-1'});
      verifyNever(() => client.execute(any()));
    });

    test('writeFileContents forwards both paths and contents', () async {
      when(
        () => client.write(any()),
      ).thenAnswer((_) async => <String, dynamic>{'id': 'update-2'});

      await repository.writeFileContents(
        syncIdOrName: 'sync-1',
        resourcePath: 'resources',
        filePath: 'stacks.toml',
        contents: '[[stack]]',
      );

      final request = capturedWrite();
      expect(request.type, 'WriteSyncFileContents');
      expect(request.params, <String, dynamic>{
        'sync': 'sync-1',
        'resource_path': 'resources',
        'file_path': 'stacks.toml',
        'contents': '[[stack]]',
      });
    });

    test('exports explicitly selected resource targets to TOML', () async {
      when(
        () => client.read(any()),
      ).thenAnswer((_) async => <String, dynamic>{'toml': '[[stack]]'});

      final result = await repository.exportResourcesToToml(const [
        SyncResourceTarget(type: 'Stack', id: 'stack-1'),
        SyncResourceTarget(type: 'Deployment', id: 'deployment-1'),
      ]);

      expect(_rightOrFail(result), '[[stack]]');
      final request = capturedRead();
      expect(request.type, 'ExportResourcesToToml');
      expect(request.params, <String, dynamic>{
        'targets': <Map<String, dynamic>>[
          <String, dynamic>{'type': 'Stack', 'id': 'stack-1'},
          <String, dynamic>{'type': 'Deployment', 'id': 'deployment-1'},
        ],
        'user_groups': <String>[],
        'include_variables': false,
      });
    });

    test('runSelected groups changes by resource type', () async {
      when(
        () => client.execute(any()),
      ).thenAnswer((_) async => <String, dynamic>{});

      await repository.runSelected('sync-1', [
        const ResourceSyncDiff(
          target: SyncResourceTarget(type: 'Stack', id: 'stack-1'),
          data: SyncDiffData(
            operation: SyncDiffOperation.update,
            proposed: 'new',
            current: 'old',
          ),
        ),
        const ResourceSyncDiff(
          target: SyncResourceTarget(type: 'Deployment', id: ''),
          data: SyncDiffData(
            operation: SyncDiffOperation.create,
            name: 'new-deployment',
            proposed: 'new',
          ),
        ),
      ]);

      final requests = verify(
        () => client.execute(captureAny()),
      ).captured.cast<RpcRequest<dynamic>>();
      expect(requests, hasLength(2));
      expect(requests[0].params, <String, dynamic>{
        'sync': 'sync-1',
        'resource_type': 'Stack',
        'resources': <String>['stack-1'],
      });
      expect(requests[1].params, <String, dynamic>{
        'sync': 'sync-1',
        'resource_type': 'Deployment',
        'resources': <String>['new-deployment'],
      });
    });

    test('updateSyncConfig sends UpdateResourceSync via write '
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
