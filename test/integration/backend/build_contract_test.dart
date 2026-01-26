import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/builds/data/repositories/build_repository.dart';

import '../../support/backend_test_config.dart';
import '../../support/backend_test_helpers.dart';

void registerBuildContractTests() {
  final config = BackendTestConfig.fromEnvironment();
  final missingConfigReason = config == null
      ? 'Set KOMODO_TEST_BASE_URL, KOMODO_TEST_API_KEY, and '
          'KOMODO_TEST_API_SECRET to run backend tests.'
      : null;

  group('Build CRUD (real backend)', () {
    late BuildRepository repository;
    late KomodoApiClient client;

    setUp(() async {
      await resetBackendIfConfigured(config!);
      client = buildTestClient(config!, RpcRecorder());
      repository = BuildRepository(client);
    });

    test('create/update/delete build', () async {
      KomodoBuild? created;
      String? createdId;
      var deleted = false;

      try {
        final builds = expectRight(await repository.listBuilds());
        expect(builds, isNotEmpty);

        final seed = builds.first;
        final seedDetail = expectRight(await repository.getBuild(seed.id));

        final name = 'contract-build-${_randomToken(Random(13021))}';
        final createdJson = await client.write(
          RpcRequest(
            type: 'CreateBuild',
            params: <String, dynamic>{
              'name': name,
              'config': seedDetail.config.toJson(),
            },
          ),
        );
        created = KomodoBuild.fromJson(createdJson as Map<String, dynamic>);

        createdId = await waitForListItemId(
          listItems: () async {
            final listed = expectRight(await repository.listBuilds());
            return listed.map((item) => item.toJson()).toList();
          },
          name: name,
        );

        final updated = await retryAsync(() async {
          return expectRight(
            await repository.updateBuildConfig(
              buildId: createdId!,
              partialConfig: <String, dynamic>{
                'auto_increment_version':
                    !seedDetail.config.autoIncrementVersion,
              },
            ),
          );
        });
        expect(updated.id, createdId);

        final updatedFields = await retryAsync(() async {
          return expectRight(
            await repository.updateBuildConfig(
              buildId: createdId!,
              partialConfig: <String, dynamic>{
                'use_buildx': !seedDetail.config.useBuildx,
                'image_tag': 'test-${_randomToken(Random(13022))}',
              },
            ),
          );
        });
        expect(updatedFields.id, createdId);

        final refreshed = expectRight(await repository.getBuild(createdId!));
        expect(refreshed.config.useBuildx, updatedFields.config.useBuildx);
        expect(refreshed.config.imageTag, updatedFields.config.imageTag);

        await retryAsync(() async {
          await client.write(
            RpcRequest(
              type: 'DeleteBuild',
              params: <String, dynamic>{'id': createdId},
            ),
          );
        });
        deleted = true;
        await expectEventuallyServerFailure(
          () => repository.getBuild(createdId!),
        );
        final afterDelete = expectRight(await repository.listBuilds());
        expect(afterDelete.any((b) => b.id == createdId), isFalse);
      } finally {
        final idToDelete = createdId ?? created?.id;
        if (!deleted && idToDelete != null) {
          await retryAsync(() async {
            await client.write(
              RpcRequest(
                type: 'DeleteBuild',
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

void main() => registerBuildContractTests();

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
