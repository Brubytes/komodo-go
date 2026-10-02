import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/api/komodo_api_capabilities.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/shared/resources/data/resource_management_repository.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_metadata.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements KomodoApiClient {}

class _FakeRpcRequest extends Fake implements RpcRequest<dynamic> {}

void main() {
  setUpAll(() => registerFallbackValue(_FakeRpcRequest()));

  group('ResourceManagementRepository', () {
    late _MockApiClient client;
    late ResourceManagementRepository repository;

    setUp(() {
      client = _MockApiClient();
      repository = ResourceManagementRepository(client);
      when(
        () => client.capabilities,
      ).thenReturn(KomodoApiCapabilities.v23AndNewer);
      when(
        () => client.write(any()),
      ).thenAnswer((_) async => <String, dynamic>{});
    });

    RpcRequest<dynamic> capturedWrite() =>
        verify(() => client.write(captureAny())).captured.single
            as RpcRequest<dynamic>;

    test('updates all common metadata with exact tag set', () async {
      const metadata = ResourceMetadata(
        kind: ResourceKind.stacks,
        id: 'stack-1',
        name: 'Stack one',
        description: 'old',
        template: false,
        tags: <String>['old-tag'],
      );

      final result = await repository.updateMetadata(
        metadata: metadata,
        draft: const ResourceMetadataDraft(
          description: 'new description',
          template: true,
          tags: <String>['tag-1', 'tag-2'],
        ),
      );

      expect(result, isA<Right<Failure, void>>());
      final request = capturedWrite();
      expect(request.type, 'UpdateResourceMeta');
      expect(request.params, <String, dynamic>{
        'target': <String, dynamic>{'type': 'Stack', 'id': 'stack-1'},
        'description': 'new description',
        'template': true,
        'tags': <String>['tag-1', 'tag-2'],
      });
    });

    test('uses the tagged resource target shape on Komodo 2.2', () async {
      when(() => client.capabilities).thenReturn(KomodoApiCapabilities.v22);

      await repository.updateMetadata(
        metadata: const ResourceMetadata(
          kind: ResourceKind.stacks,
          id: 'stack-1',
          name: 'Stack one',
          description: '',
          template: false,
          tags: <String>[],
        ),
        draft: const ResourceMetadataDraft(
          description: 'legacy',
          template: false,
          tags: <String>['tag-1'],
        ),
      );

      final request = capturedWrite();
      expect(request.params, <String, dynamic>{
        'target': <String, dynamic>{'type': 'Stack', 'id': 'stack-1'},
        'description': 'legacy',
        'template': false,
        'tags': <String>['tag-1'],
      });
    });

    test('creates a resource with the exact partial config payload', () async {
      when(() => client.write(any())).thenAnswer(
        (_) async => <String, dynamic>{
          '_id': <String, dynamic>{r'$oid': 'stack-new'},
          'name': 'web',
        },
      );

      final result = await repository.create(
        kind: ResourceKind.stacks,
        name: 'web',
        config: <String, dynamic>{
          'server_id': 'server-1',
          'file_contents': 'services: {}',
        },
      );

      final created = result.getOrElse(
        (_) => fail('Expected created resource'),
      );
      expect(created.id, 'stack-new');
      expect(created.name, 'web');
      final request = capturedWrite();
      expect(request.type, 'CreateStack');
      expect(request.params, <String, dynamic>{
        'name': 'web',
        'config': <String, dynamic>{
          'server_id': 'server-1',
          'file_contents': 'services: {}',
        },
      });
    });

    test('copyAndReturn returns the copied identity', () async {
      when(() => client.write(any())).thenAnswer(
        (_) async => <String, dynamic>{'id': 'copy-1', 'name': 'Copy'},
      );

      final result = await repository.copyAndReturn(
        kind: ResourceKind.deployments,
        id: 'deployment-1',
        name: 'Copy',
      );

      final created = result.getOrElse(
        (_) => fail('Expected copied resource'),
      );
      expect(created.id, 'copy-1');
      final request = capturedWrite();
      expect(request.type, 'CopyDeployment');
      expect(request.params, <String, dynamic>{
        'id': 'deployment-1',
        'name': 'Copy',
      });
    });

    const kinds = <ResourceKind, String>{
      ResourceKind.servers: 'Server',
      ResourceKind.stacks: 'Stack',
      ResourceKind.deployments: 'Deployment',
      ResourceKind.builds: 'Build',
      ResourceKind.repos: 'Repo',
      ResourceKind.procedures: 'Procedure',
      ResourceKind.actions: 'Action',
      ResourceKind.syncs: 'ResourceSync',
    };

    for (final entry in kinds.entries) {
      test('${entry.value} copy/rename/delete use canonical RPCs', () async {
        expect(
          await repository.copy(kind: entry.key, id: 'id-1', name: 'Copy'),
          isA<Right<Failure, void>>(),
        );
        var request = capturedWrite();
        expect(request.type, 'Copy${entry.value}');
        expect(request.params, <String, dynamic>{'id': 'id-1', 'name': 'Copy'});

        expect(
          await repository.rename(
            kind: entry.key,
            id: 'id-1',
            name: 'Renamed',
          ),
          isA<Right<Failure, void>>(),
        );
        request = capturedWrite();
        expect(request.type, 'Rename${entry.value}');
        expect(request.params, <String, dynamic>{
          'id': 'id-1',
          'name': 'Renamed',
        });

        expect(
          await repository.delete(kind: entry.key, id: 'id-1'),
          isA<Right<Failure, void>>(),
        );
        request = capturedWrite();
        expect(request.type, 'Delete${entry.value}');
        expect(request.params, <String, dynamic>{'id': 'id-1'});
      });
    }

    test('maps API failures to Failure', () async {
      when(() => client.write(any())).thenThrow(
        const ApiException(message: 'denied', statusCode: 403),
      );

      final result = await repository.delete(
        kind: ResourceKind.actions,
        id: 'action-1',
      );

      expect(result, isA<Left<Failure, void>>());
    });
  });
}
