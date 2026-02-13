import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:komodo_go/features/deployments/data/repositories/deployment_repository.dart';

import '../../support/backend_test_config.dart';
import '../../support/backend_test_helpers.dart';

void registerDeploymentContractTests() {
  final config = BackendTestConfig.fromEnvironment();
  final missingConfigReason = config == null
      ? 'Set KOMODO_TEST_BASE_URL, KOMODO_TEST_API_KEY, and '
          'KOMODO_TEST_API_SECRET to run backend tests.'
      : null;

  group('Deployment CRUD (real backend)', () {
    late DeploymentRepository repository;
    late KomodoApiClient client;

    setUp(() async {
      await resetBackendIfConfigured(requireConfig(config));
      client = buildTestClient(requireConfig(config), RpcRecorder());
      repository = DeploymentRepository(client);
    });

    test('create/update/delete deployment', () async {
      Deployment? created;
      String? createdId;
      var deleted = false;

      try {
        final deployments = expectRight(await repository.listDeployments());
        expect(deployments, isNotEmpty);

        final seed = deployments.first;
        final seedDetail = expectRight(await repository.getDeployment(seed.id));
        final seedConfig = seedDetail.config;
        expect(seedConfig, isNotNull);

        final name = 'contract-deploy-${_randomToken(Random(8021))}';
        final createdJson = await client.write(
          RpcRequest(
            type: 'CreateDeployment',
            params: <String, dynamic>{
              'name': name,
              'config': seedConfig!.toJson(),
            },
          ),
        );
        created = Deployment.fromJson(createdJson as Map<String, dynamic>);

        createdId = await waitForListItemId(
          listItems: () async {
            final listed = expectRight(await repository.listDeployments());
            return listed.map((item) => item.toJson()).toList();
          },
          name: name,
        );
        final createdIdValue = createdId;

        final updated = await retryAsync(() async {
          return expectRight(
            await repository.updateDeploymentConfig(
              deploymentId: createdIdValue,
              partialConfig: <String, dynamic>{
                'poll_for_updates': !seedConfig.pollForUpdates,
              },
            ),
          );
        });
        expect(updated.name, name);

        final updatedFields = await retryAsync(() async {
          return expectRight(
            await repository.updateDeploymentConfig(
              deploymentId: createdIdValue,
              partialConfig: <String, dynamic>{
                'environment': 'FOO=bar\nHELLO=world',
                'labels': 'app=komodo-test',
              },
            ),
          );
        });
        expect(updatedFields.id, createdIdValue);

        final refreshed =
            expectRight(await repository.getDeployment(createdIdValue));
        expect(refreshed.config?.environment.trim(), 'FOO=bar\nHELLO=world');
        expect(refreshed.config?.labels.trim(), 'app=komodo-test');

        await retryAsync(() async {
          await client.write(
            RpcRequest(
              type: 'DeleteDeployment',
              params: <String, dynamic>{'id': createdIdValue},
            ),
          );
        });
        deleted = true;
        await expectEventuallyServerFailure(
          () => repository.getDeployment(createdIdValue),
        );
        final afterDelete = expectRight(await repository.listDeployments());
        expect(afterDelete.any((d) => d.id == createdIdValue), isFalse);
      } finally {
        final idToDelete = createdId ?? created?.id;
        if (!deleted && idToDelete != null) {
          await retryAsync(() async {
            await client.write(
              RpcRequest(
                type: 'DeleteDeployment',
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

  group('Deployment CRUD property-based (real backend)', () {
    late DeploymentRepository repository;
    late KomodoApiClient client;

    setUp(() async {
      await resetBackendIfConfigured(requireConfig(config));
      client = buildTestClient(requireConfig(config), RpcRecorder());
      repository = DeploymentRepository(client);
    });

    test('randomized deployments survive CRUD roundtrip', () async {
      final deployments = expectRight(await repository.listDeployments());
      expect(deployments, isNotEmpty);

      final seed = deployments.first;
      final seedDetail = expectRight(await repository.getDeployment(seed.id));
      final seedConfig = seedDetail.config;
      expect(seedConfig, isNotNull);

      final random = Random(8031);
      final pendingDeletes = <String>{};

      try {
        for (var i = 0; i < 5; i++) {
          final name = 'prop-deploy-$i-${_randomToken(random)}';
          final createdJson = await client.write(
            RpcRequest(
              type: 'CreateDeployment',
              params: <String, dynamic>{
                'name': name,
                'config': seedConfig!.toJson(),
              },
            ),
          );
          Deployment.fromJson(createdJson as Map<String, dynamic>);

          final createdId = await waitForListItemId(
            listItems: () async {
              final listed = expectRight(await repository.listDeployments());
              return listed.map((item) => item.toJson()).toList();
            },
            name: name,
          );
          pendingDeletes.add(createdId);

          final environment = 'FOO=bar-${_randomToken(random)}';
          final labels = 'app=prop-${_randomToken(random)}';
          final updated = expectRight(
            await repository.updateDeploymentConfig(
              deploymentId: createdId,
              partialConfig: <String, dynamic>{
                'environment': environment,
                'labels': labels,
              },
            ),
          );
          expect(updated.id, createdId);

          final refreshed = expectRight(await repository.getDeployment(createdId));
          expect(refreshed.config?.environment.trim(), environment);
          expect(refreshed.config?.labels.trim(), labels);

          await retryAsync(() async {
            await client.write(
              RpcRequest(
                type: 'DeleteDeployment',
                params: <String, dynamic>{'id': createdId},
              ),
            );
          });
          pendingDeletes.remove(createdId);
          await expectEventuallyServerFailure(
            () => repository.getDeployment(createdId),
          );
        }
      } finally {
        for (final id in pendingDeletes) {
          await retryAsync(() async {
            await client.write(
              RpcRequest(
                type: 'DeleteDeployment',
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
}

void main() => registerDeploymentContractTests();

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
