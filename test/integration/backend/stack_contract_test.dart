import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/data/repositories/stack_repository.dart';

import '../../support/backend_test_config.dart';
import '../../support/backend_test_helpers.dart';

void registerStackContractTests() {
  final config = BackendTestConfig.fromEnvironment();
  final missingConfigReason = config == null
      ? 'Set KOMODO_TEST_BASE_URL, KOMODO_TEST_API_KEY, and '
          'KOMODO_TEST_API_SECRET to run backend tests.'
      : null;

  group('Stack contract CRUD-ish (real backend)', () {
    late StackRepository repository;
    late RpcRecorder recorder;
    late KomodoApiClient client;

    setUp(() async {
      await resetBackendIfConfigured(config!);
      recorder = RpcRecorder();
      client = buildTestClient(config!, recorder);
      repository = StackRepository(client);
    });

    test('list/get/update stack config + golden request', () async {
      final stacks = expectRight(await repository.listStacks());
      expect(stacks, isNotEmpty);

      final target = stacks.first;
      final stack = expectRight(await repository.getStack(target.id));
      final originalEnvironment = stack.config.environment;

      final updated = expectRight(
        await repository.updateStackConfig(
          stackId: stack.id,
          partialConfig: <String, dynamic>{'environment': 'komodo-test'},
        ),
      );
      expect(updated.id, stack.id);
      expect(updated.config.environment.trim(), 'komodo-test');

      final requestData = recorder.lastRequest?.data;
      expect(requestData, isA<Map>());

      final normalizedRequest = normalizeStackUpdateRequest(
        (requestData as Map).cast<String, dynamic>(),
      );
      expect(
        normalizedRequest,
        loadGoldenJson('test/golden/stack_update_request.json'),
      );

      final toggled = expectRight(
        await repository.updateStackConfig(
          stackId: stack.id,
          partialConfig: <String, dynamic>{
            'poll_for_updates': !stack.config.pollForUpdates,
            'auto_update': !stack.config.autoUpdate,
          },
        ),
      );
      expect(toggled.id, stack.id);

      final refreshed = expectRight(await repository.getStack(target.id));
      expect(refreshed.config.environment.trim(), 'komodo-test');
      expect(
        refreshed.config.pollForUpdates,
        toggled.config.pollForUpdates,
      );
      expect(refreshed.config.autoUpdate, toggled.config.autoUpdate);

      await repository.updateStackConfig(
        stackId: stack.id,
        partialConfig: <String, dynamic>{
          'environment': originalEnvironment,
          'poll_for_updates': stack.config.pollForUpdates,
          'auto_update': stack.config.autoUpdate,
        },
      );
    });

    test('create/delete stack', () async {
      KomodoStack? created;
      String? createdId;
      var deleted = false;

      try {
        final stacks = expectRight(await repository.listStacks());
        expect(stacks, isNotEmpty);

        final seed = stacks.first;
        final seedDetail = expectRight(await repository.getStack(seed.id));

        final name = 'contract-stack-${_randomToken(Random(21021))}';
        final createdJson = await client.write(
          RpcRequest(
            type: 'CreateStack',
            params: <String, dynamic>{
              'name': name,
              'config': seedDetail.config.toJson(),
            },
          ),
        );
        created = KomodoStack.fromJson(createdJson as Map<String, dynamic>);

        createdId = await waitForListItemId(
          listItems: () async {
            final listed = expectRight(await repository.listStacks());
            return listed.map((item) => item.toJson()).toList();
          },
          name: name,
        );

        await retryAsync(() async {
          await client.write(
            RpcRequest(
              type: 'DeleteStack',
              params: <String, dynamic>{'id': createdId},
            ),
          );
        });
        deleted = true;
        await expectEventuallyServerFailure(
          () => repository.getStack(createdId!),
        );
        final afterDelete = expectRight(await repository.listStacks());
        expect(afterDelete.any((s) => s.id == createdId), isFalse);
      } finally {
        final idToDelete = createdId ?? created?.id;
        if (!deleted && idToDelete != null) {
          await retryAsync(() async {
            await client.write(
              RpcRequest(
                type: 'DeleteStack',
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

  group('Stack CRUD property-based (real backend)', () {
    late StackRepository repository;
    late KomodoApiClient client;

    setUp(() async {
      await resetBackendIfConfigured(config!);
      client = buildTestClient(config!, RpcRecorder());
      repository = StackRepository(client);
    });

    test('randomized stacks survive CRUD roundtrip', () async {
      final stacks = expectRight(await repository.listStacks());
      expect(stacks, isNotEmpty);

      final seed = stacks.first;
      final seedDetail = expectRight(await repository.getStack(seed.id));
      final createConfig = seedDetail.config.toJson();

      final random = Random(21031);
      final pendingDeletes = <String>{};

      try {
        for (var i = 0; i < 5; i++) {
          final name = 'prop-stack-$i-${_randomToken(random)}';
          final createdJson = await client.write(
            RpcRequest(
              type: 'CreateStack',
              params: <String, dynamic>{
                'name': name,
                'config': createConfig,
              },
            ),
          );
          KomodoStack.fromJson(createdJson as Map<String, dynamic>);

          final createdId = await waitForListItemId(
            listItems: () async {
              final listed = expectRight(await repository.listStacks());
              return listed.map((item) => item.toJson()).toList();
            },
            name: name,
          );
          pendingDeletes.add(createdId);

          final environment = 'prop-env-$i-${_randomToken(random)}';
          final updated = expectRight(
            await repository.updateStackConfig(
              stackId: createdId,
              partialConfig: <String, dynamic>{'environment': environment},
            ),
          );
          expect(updated.config.environment.trim(), environment);

          final refreshed = expectRight(await repository.getStack(createdId));
          expect(refreshed.config.environment.trim(), environment);

          await retryAsync(() async {
            await client.write(
              RpcRequest(
                type: 'DeleteStack',
                params: <String, dynamic>{'id': createdId},
              ),
            );
          });
          pendingDeletes.remove(createdId);
          await expectEventuallyServerFailure(
            () => repository.getStack(createdId),
          );
        }
      } finally {
        for (final id in pendingDeletes) {
          await retryAsync(() async {
            await client.write(
              RpcRequest(
                type: 'DeleteStack',
                params: <String, dynamic>{'id': id},
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

  group('Stack config property-based (real backend)', () {
    late StackRepository repository;

    setUp(() async {
      await resetBackendIfConfigured(config!);
      repository = StackRepository(
        buildTestClient(config!, RpcRecorder()),
      );
    });

    test('randomized environment values survive update', () async {
      final stacks = expectRight(await repository.listStacks());
      expect(stacks, isNotEmpty);

      final target = stacks.first;
      final original = expectRight(await repository.getStack(target.id));
      final originalEnvironment = original.config.environment;

      final random = Random(2026);

      try {
        for (var i = 0; i < 10; i++) {
          final environment = 'komodo-test-${_randomToken(random)}';
          final updated = expectRight(
            await repository.updateStackConfig(
              stackId: target.id,
              partialConfig: <String, dynamic>{'environment': environment},
            ),
          );
          expect(updated.config.environment.trim(), environment);

          final refreshed = expectRight(await repository.getStack(target.id));
          expect(refreshed.config.environment.trim(), environment);
        }
      } finally {
        await repository.updateStackConfig(
          stackId: target.id,
          partialConfig: <String, dynamic>{'environment': originalEnvironment},
        );
      }
    });
  },
      skip: missingConfigReason ??
          config?.skipReason() ??
          config?.requireResetReason());
}

void main() => registerStackContractTests();

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

Map<String, dynamic> normalizeStackUpdateRequest(Map<String, dynamic> json) {
  final normalized = normalizeJson(json);
  final params = Map<String, dynamic>.from(
    (normalized['params'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{},
  );
  params['id'] = '<id>';
  normalized['params'] = params;
  return normalized;
}
