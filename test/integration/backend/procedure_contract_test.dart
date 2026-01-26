import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/features/procedures/data/repositories/procedure_repository.dart';

import '../../support/backend_test_config.dart';
import '../../support/backend_test_helpers.dart';

void registerProcedureContractTests() {
  final config = BackendTestConfig.fromEnvironment();
  final missingConfigReason = config == null
      ? 'Set KOMODO_TEST_BASE_URL, KOMODO_TEST_API_KEY, and '
          'KOMODO_TEST_API_SECRET to run backend tests.'
      : null;

  group('Procedure CRUD (real backend)', () {
    late ProcedureRepository repository;
    late KomodoApiClient client;

    setUp(() async {
      await resetBackendIfConfigured(config!);
      client = buildTestClient(config!, RpcRecorder());
      repository = ProcedureRepository(client);
    });

    test('create/update/delete procedure', () async {
      KomodoProcedure? created;
      String? createdId;
      var deleted = false;

      try {
        final procedures = expectRight(await repository.listProcedures());
        expect(procedures, isNotEmpty);

        final seed = procedures.first;
        final seedDetail = expectRight(await repository.getProcedure(seed.id));

        final name = 'contract-proc-${_randomToken(Random(10021))}';
        final createdJson = await client.write(
          RpcRequest(
            type: 'CreateProcedure',
            params: <String, dynamic>{
              'name': name,
              'config': seedDetail.config.toJson(),
            },
          ),
        );
        created = KomodoProcedure.fromJson(createdJson as Map<String, dynamic>);

        createdId = await waitForListItemId(
          listItems: () async {
            final listed = expectRight(await repository.listProcedures());
            return listed.map((item) => item.toJson()).toList();
          },
          name: name,
        );

        final updated = await retryAsync(() async {
          return expectRight(
            await repository.updateProcedureConfig(
              procedureId: createdId!,
              partialConfig: <String, dynamic>{
                'schedule_enabled': !seedDetail.config.scheduleEnabled,
              },
            ),
          );
        });
        expect(updated.id, createdId);

        final alertsUpdated = await retryAsync(() async {
          return expectRight(
            await repository.updateProcedureConfig(
              procedureId: createdId!,
              partialConfig: <String, dynamic>{
                'schedule_alert': !seedDetail.config.scheduleAlert,
                'failure_alert': !seedDetail.config.failureAlert,
              },
            ),
          );
        });
        expect(alertsUpdated.id, createdId);

        final refreshed = expectRight(await repository.getProcedure(createdId!));
        expect(refreshed.config.scheduleAlert, alertsUpdated.config.scheduleAlert);
        expect(refreshed.config.failureAlert, alertsUpdated.config.failureAlert);

        await retryAsync(() async {
          await client.write(
            RpcRequest(
              type: 'DeleteProcedure',
              params: <String, dynamic>{'id': createdId},
            ),
          );
        });
        deleted = true;
        final afterDelete = expectRight(await repository.listProcedures());
        expect(afterDelete.any((p) => p.id == createdId), isFalse);
      } finally {
        final idToDelete = createdId ?? created?.id;
        if (!deleted && idToDelete != null) {
          await retryAsync(() async {
            await client.write(
              RpcRequest(
                type: 'DeleteProcedure',
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

void main() => registerProcedureContractTests();

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
