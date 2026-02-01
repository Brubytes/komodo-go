import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';
import 'package:komodo_go/features/syncs/data/repositories/sync_repository.dart';

import '../../support/backend_test_config.dart';
import '../../support/backend_test_helpers.dart';

void registerSyncContractTests() {
  final config = BackendTestConfig.fromEnvironment();
  final missingConfigReason = config == null
      ? 'Set KOMODO_TEST_BASE_URL, KOMODO_TEST_API_KEY, and '
          'KOMODO_TEST_API_SECRET to run backend tests.'
      : null;

  group('Resource sync CRUD (real backend)', () {
    late SyncRepository repository;
    late KomodoApiClient client;

    setUp(() async {
      await resetBackendIfConfigured(config!);
      client = buildTestClient(config!, RpcRecorder());
      repository = SyncRepository(client);
    });

    test('create/update/delete sync', () async {
      KomodoResourceSync? created;
      String? createdId;
      var deleted = false;

      try {
        final syncs = expectRight(await repository.listSyncs());
        expect(syncs, isNotEmpty);

        final seed = syncs.first;
        final seedDetail = expectRight(await repository.getSync(seed.id));

        final name = 'contract-sync-${_randomToken(Random(12021))}';
        final createdJson = await client.write(
          RpcRequest(
            type: 'CreateResourceSync',
            params: <String, dynamic>{
              'name': name,
              'config': seedDetail.config.toJson(),
            },
          ),
        );
        created =
            KomodoResourceSync.fromJson(createdJson as Map<String, dynamic>);

        createdId = await waitForListItemId(
          listItems: () async {
            final listed = expectRight(await repository.listSyncs());
            return listed.map((item) => item.toJson()).toList();
          },
          name: name,
        );

        final updated = await retryAsync(() async {
          return expectRight(
            await repository.updateSyncConfig(
              syncId: createdId!,
              partialConfig: <String, dynamic>{
                'include_resources': !seedDetail.config.includeResources,
              },
            ),
          );
        });
        expect(updated.id, createdId);

        final updatedFlags = await retryAsync(() async {
          return expectRight(
            await repository.updateSyncConfig(
              syncId: createdId!,
              partialConfig: <String, dynamic>{
                'include_variables': !seedDetail.config.includeVariables,
                'pending_alert': !seedDetail.config.pendingAlert,
              },
            ),
          );
        });
        expect(updatedFlags.id, createdId);

        final refreshed = expectRight(await repository.getSync(createdId!));
        expect(
          refreshed.config.includeVariables,
          updatedFlags.config.includeVariables,
        );
        expect(refreshed.config.pendingAlert, updatedFlags.config.pendingAlert);

        await retryAsync(() async {
          await client.write(
            RpcRequest(
              type: 'DeleteResourceSync',
              params: <String, dynamic>{'id': createdId},
            ),
          );
        });
        deleted = true;
        await expectEventuallyServerFailure(
          () => repository.getSync(createdId!),
        );
        final afterDelete = expectRight(await repository.listSyncs());
        expect(afterDelete.any((s) => s.id == createdId), isFalse);
      } finally {
        final idToDelete = createdId ?? created?.id;
        if (!deleted && idToDelete != null) {
          await retryAsync(() async {
            await client.write(
              RpcRequest(
                type: 'DeleteResourceSync',
                params: <String, dynamic>{'id': idToDelete},
              ),
            );
          });
        }
      }
    });
  },
      skip: missingConfigReason ??
          config?.skipReason() ??
          config?.requireResetReason());
}

void main() => registerSyncContractTests();

T expectRight<T>(Either<Failure, T> result) {
  return result.fold(
    (failure) => fail('Expected success, got $failure'),
    (value) => value,
  );
}

String _randomToken(Random random) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final buffer = StringBuffer();
  for (var i = 0; i < 6; i++) {
    buffer.write(chars[random.nextInt(chars.length)]);
  }
  return buffer.toString();
}
