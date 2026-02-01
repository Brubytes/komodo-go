import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/data/repositories/repo_repository.dart';

import '../../support/backend_test_config.dart';
import '../../support/backend_test_helpers.dart';

void registerRepoContractTests() {
  final config = BackendTestConfig.fromEnvironment();
  final missingConfigReason = config == null
      ? 'Set KOMODO_TEST_BASE_URL, KOMODO_TEST_API_KEY, and '
          'KOMODO_TEST_API_SECRET to run backend tests.'
      : null;

  group('Repo CRUD (real backend)', () {
    late RepoRepository repository;
    late KomodoApiClient client;

    setUp(() async {
      await resetBackendIfConfigured(config!);
      client = buildTestClient(config!, RpcRecorder());
      repository = RepoRepository(client);
    });

    test('create/update/delete repo', () async {
      KomodoRepo? created;
      String? createdId;
      var deleted = false;

      try {
        final repos = expectRight(await repository.listRepos());
        expect(repos, isNotEmpty);

        final seed = repos.first;
        final seedDetail = expectRight(await repository.getRepo(seed.id));

        final name = 'contract-repo-${_randomToken(Random(7021))}';
        final createConfig = seedDetail.config.toJson();
        createConfig['server_id'] = '';
        createConfig['builder_id'] = '';
        createConfig['repo'] = 'contract/$name';
        if ((createConfig['branch'] as String?)?.isEmpty ?? true) {
          createConfig['branch'] = 'main';
        }
        final createdJson = await client.write(
          RpcRequest(
            type: 'CreateRepo',
            params: <String, dynamic>{
              'name': name,
              'config': createConfig,
            },
          ),
        );
        created = KomodoRepo.fromJson(createdJson as Map<String, dynamic>);

        createdId = await waitForListItemId(
          listItems: () async {
            final listed = expectRight(await repository.listRepos());
            return listed.map((repo) => repo.toJson()).toList();
          },
          name: name,
        );

        final updated = await retryAsync(() async {
          return expectRight(
            await repository.updateRepoConfig(
              repoId: createdId!,
              partialConfig: <String, dynamic>{
                'skip_secret_interp': !seedDetail.config.skipSecretInterp,
              },
            ),
          );
        });
        expect(updated.name, name);

        final updatedHttps = await retryAsync(() async {
          return expectRight(
            await repository.updateRepoConfig(
              repoId: createdId!,
              partialConfig: <String, dynamic>{
                'git_https': !seedDetail.config.gitHttps,
              },
            ),
          );
        });
        expect(updatedHttps.id, createdId);

        final refreshed = expectRight(await repository.getRepo(createdId!));
        expect(refreshed.config.gitHttps, updatedHttps.config.gitHttps);

        await retryAsync(() async {
          await client.write(
            RpcRequest(
              type: 'DeleteRepo',
              params: <String, dynamic>{'id': createdId},
            ),
          );
        });
        deleted = true;
        await expectEventuallyServerFailure(
          () => repository.getRepo(createdId!),
        );
        final afterDelete = expectRight(await repository.listRepos());
        expect(afterDelete.any((r) => r.id == createdId), isFalse);
      } finally {
        final idToDelete = createdId ?? created?.id;
        if (!deleted && idToDelete != null) {
          await retryAsync(() async {
            await client.write(
              RpcRequest(
                type: 'DeleteRepo',
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

  group('Repo CRUD property-based (real backend)', () {
    late RepoRepository repository;
    late KomodoApiClient client;

    setUp(() async {
      await resetBackendIfConfigured(config!);
      client = buildTestClient(config!, RpcRecorder());
      repository = RepoRepository(client);
    });

    test('randomized repos survive CRUD roundtrip', () async {
      final repos = expectRight(await repository.listRepos());
      expect(repos, isNotEmpty);

      final seed = repos.first;
      final seedDetail = expectRight(await repository.getRepo(seed.id));
      final random = Random(7031);
      final pendingDeletes = <String>{};

      try {
        for (var i = 0; i < 5; i++) {
          final name = 'prop-repo-$i-${_randomToken(random)}';
          final createConfig = seedDetail.config.toJson();
          createConfig['server_id'] = '';
          createConfig['builder_id'] = '';
          createConfig['repo'] = 'contract/$name';
          if ((createConfig['branch'] as String?)?.isEmpty ?? true) {
            createConfig['branch'] = 'main';
          }

          final createdJson = await client.write(
            RpcRequest(
              type: 'CreateRepo',
              params: <String, dynamic>{
                'name': name,
                'config': createConfig,
              },
            ),
          );
          KomodoRepo.fromJson(createdJson as Map<String, dynamic>);

          final createdId = await waitForListItemId(
            listItems: () async {
              final listed = expectRight(await repository.listRepos());
              return listed.map((repo) => repo.toJson()).toList();
            },
            name: name,
          );
          pendingDeletes.add(createdId);

          final updated = expectRight(
            await repository.updateRepoConfig(
              repoId: createdId,
              partialConfig: <String, dynamic>{
                'skip_secret_interp': !seedDetail.config.skipSecretInterp,
              },
            ),
          );
          expect(updated.id, createdId);

          final updatedHttps = expectRight(
            await repository.updateRepoConfig(
              repoId: createdId,
              partialConfig: <String, dynamic>{
                'git_https': !seedDetail.config.gitHttps,
              },
            ),
          );
          expect(updatedHttps.id, createdId);

          final refreshed = expectRight(await repository.getRepo(createdId));
          expect(refreshed.config.gitHttps, updatedHttps.config.gitHttps);

          await retryAsync(() async {
            await client.write(
              RpcRequest(
                type: 'DeleteRepo',
                params: <String, dynamic>{'id': createdId},
              ),
            );
          });
          pendingDeletes.remove(createdId);
          await expectEventuallyServerFailure(
            () => repository.getRepo(createdId),
          );
        }
      } finally {
        for (final id in pendingDeletes) {
          await retryAsync(() async {
            await client.write(
              RpcRequest(
                type: 'DeleteRepo',
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

void main() => registerRepoContractTests();

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
