import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/actions/data/repositories/action_repository.dart';

import '../../support/backend_test_config.dart';
import '../../support/backend_test_helpers.dart';

void registerActionContractTests() {
  final config = BackendTestConfig.fromEnvironment();
  final missingConfigReason = config == null
      ? 'Set KOMODO_TEST_BASE_URL, KOMODO_TEST_API_KEY, and '
          'KOMODO_TEST_API_SECRET to run backend tests.'
      : null;

  group('Action CRUD (real backend)', () {
    late ActionRepository repository;
    late KomodoApiClient client;

    setUp(() async {
      await resetBackendIfConfigured(config!);
      client = buildTestClient(config!, RpcRecorder());
      repository = ActionRepository(client);
    });

    test('create/update/delete action', () async {
      KomodoAction? created;
      String? createdId;
      var deleted = false;

      try {
        final actions = expectRight(await repository.listActions());
        expect(actions, isNotEmpty);

        final seed = actions.first;
        final seedDetail = expectRight(await repository.getAction(seed.id));

        final name = 'contract-action-${_randomToken(Random(11021))}';
        final createConfig = seedDetail.config.toJson();
        if (createConfig['arguments_format'] == 'KeyValue') {
          createConfig['arguments_format'] = 'key_value';
        }
        final createdJson = await client.write(
          RpcRequest(
            type: 'CreateAction',
            params: <String, dynamic>{
              'name': name,
              'config': createConfig,
            },
          ),
        );
        created = KomodoAction.fromJson(createdJson as Map<String, dynamic>);

        createdId = await waitForListItemId(
          listItems: () async {
            final listed = expectRight(await repository.listActions());
            return listed.map((item) => item.toJson()).toList();
          },
          name: name,
        );

        final updated = await retryAsync(() async {
          return expectRight(
            await repository.updateActionConfig(
              actionId: createdId!,
              partialConfig: <String, dynamic>{
                'run_at_startup': !seedDetail.config.runAtStartup,
              },
            ),
          );
        });
        expect(updated.id, createdId);

        final updatedArgs = await retryAsync(() async {
          return expectRight(
            await repository.updateActionConfig(
              actionId: createdId!,
              partialConfig: <String, dynamic>{
                'arguments_format': 'key_value',
                'arguments': 'FOO=bar\nBAZ=qux',
              },
            ),
          );
        });
        expect(updatedArgs.config.arguments, contains('FOO=bar'));

        final refreshed = expectRight(await repository.getAction(createdId!));
        expect(refreshed.config.arguments, contains('FOO=bar'));

        await retryAsync(() async {
          await client.write(
            RpcRequest(
              type: 'DeleteAction',
              params: <String, dynamic>{'id': createdId},
            ),
          );
        });
        deleted = true;
        await expectEventuallyServerFailure(
          () => repository.getAction(createdId!),
        );
        final afterDelete = expectRight(await repository.listActions());
        expect(afterDelete.any((a) => a.id == createdId), isFalse);
      } finally {
        final idToDelete = createdId ?? created?.id;
        if (!deleted && idToDelete != null) {
          await retryAsync(() async {
            await client.write(
              RpcRequest(
                type: 'DeleteAction',
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

void main() => registerActionContractTests();

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
