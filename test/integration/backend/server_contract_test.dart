import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/data/repositories/server_repository.dart';

import '../../support/backend_test_config.dart';
import '../../support/backend_test_helpers.dart';

void registerServerContractTests() {
  final config = BackendTestConfig.fromEnvironment();
  final missingConfigReason = config == null
      ? 'Set KOMODO_TEST_BASE_URL, KOMODO_TEST_API_KEY, and '
          'KOMODO_TEST_API_SECRET to run backend tests.'
      : null;

  group('Server CRUD (real backend)', () {
    late ServerRepository repository;
    late KomodoApiClient client;

    setUp(() async {
      await resetBackendIfConfigured(config!);
      client = buildTestClient(config!, RpcRecorder());
      repository = ServerRepository(client);
    });

    test('create/update/delete server', () async {
      Server? created;
      String? createdId;
      var deleted = false;

      try {
        final servers = expectRight(await repository.listServers());
        expect(servers, isNotEmpty);

        final seed = servers.first;
        final seedDetail = expectRight(await repository.getServer(seed.id));
        final seedConfig = seedDetail.config;
        expect(seedConfig, isNotNull);

        final name = 'contract-server-${_randomToken(Random(9021))}';
        final createdJson = await client.write(
          RpcRequest(
            type: 'CreateServer',
            params: <String, dynamic>{
              'name': name,
              'config': seedConfig!.toJson(),
            },
          ),
        );
        created = Server.fromJson(createdJson as Map<String, dynamic>);

        createdId = await waitForListItemId(
          listItems: () async {
            final listed = expectRight(await repository.listServers());
            return listed.map((item) => item.toJson()).toList();
          },
          name: name,
        );

        final updated = await retryAsync(() async {
          return expectRight(
            await repository.updateServerConfig(
              serverId: createdId!,
              partialConfig: <String, dynamic>{
                'enabled': !seedConfig.enabled,
              },
            ),
          );
        });
        expect(updated.id, createdId);

        await retryAsync(() async {
          await client.write(
            RpcRequest(
              type: 'DeleteServer',
              params: <String, dynamic>{'id': createdId},
            ),
          );
        });
        deleted = true;
        final afterDelete = expectRight(await repository.listServers());
        expect(afterDelete.any((s) => s.id == createdId), isFalse);
      } finally {
        final idToDelete = createdId ?? created?.id;
        if (!deleted && idToDelete != null) {
          await retryAsync(() async {
            await client.write(
              RpcRequest(
                type: 'DeleteServer',
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

void main() => registerServerContractTests();

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
