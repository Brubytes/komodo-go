import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/providers/data/models/docker_registry_account.dart';
import 'package:komodo_go/features/providers/data/models/git_provider_account.dart';
import 'package:komodo_go/features/providers/data/repositories/docker_registry_repository.dart';
import 'package:komodo_go/features/providers/data/repositories/git_provider_repository.dart';

import '../../support/backend_test_config.dart';
import '../../support/backend_test_helpers.dart';

void registerProviderContractTests() {
  final config = BackendTestConfig.fromEnvironment();
  final missingConfigReason = config == null
      ? 'Set KOMODO_TEST_BASE_URL, KOMODO_TEST_API_KEY, and '
          'KOMODO_TEST_API_SECRET to run backend tests.'
      : null;

  group('Git provider account CRUD (real backend)', () {
    late GitProviderRepository repository;

    setUp(() async {
      await resetBackendIfConfigured(config!);
      repository = GitProviderRepository(buildTestClient(config!, RpcRecorder()));
    });

    test('create/update/delete account', () async {
      GitProviderAccount? created;
      final suffix = _randomToken(Random(3101));
      final username = 'contract-$suffix';

      try {
        created = expectRight(
          await repository.createAccount(
            domain: 'example.com',
            username: username,
            token: 'token-$suffix',
            https: true,
          ),
        );

        final listed = expectRight(await repository.listAccounts());
        expect(listed.any((a) => a.id == created!.id), isTrue);

        final updated = expectRight(
          await repository.updateAccount(
            id: created!.id,
            domain: 'example.org',
            https: false,
          ),
        );
        expect(updated.id, created!.id);
        expect(updated.domain, 'example.org');
        expect(updated.https, isFalse);

        expectRight(await repository.deleteAccount(id: created!.id));
        final afterDelete = expectRight(await repository.listAccounts());
        expect(afterDelete.any((a) => a.id == created!.id), isFalse);
      } finally {
        if (created != null) {
          await repository.deleteAccount(id: created.id);
        }
      }
    });
  },
      skip: missingConfigReason ??
          config?.skipReason() ??
          config?.requireResetReason());

  group('Docker registry account CRUD (real backend)', () {
    late DockerRegistryRepository repository;

    setUp(() async {
      await resetBackendIfConfigured(config!);
      repository = DockerRegistryRepository(
        buildTestClient(config!, RpcRecorder()),
      );
    });

    test('create/update/delete account', () async {
      DockerRegistryAccount? created;
      final suffix = _randomToken(Random(4101));
      final username = 'contract-$suffix';

      try {
        created = expectRight(
          await repository.createAccount(
            domain: 'registry.example.com',
            username: username,
            token: 'token-$suffix',
          ),
        );

        final listed = expectRight(await repository.listAccounts());
        expect(listed.any((a) => a.id == created!.id), isTrue);

        final updated = expectRight(
          await repository.updateAccount(
            id: created!.id,
            domain: 'registry.example.org',
          ),
        );
        expect(updated.id, created!.id);
        expect(updated.domain, 'registry.example.org');

        expectRight(await repository.deleteAccount(id: created!.id));
        final afterDelete = expectRight(await repository.listAccounts());
        expect(afterDelete.any((a) => a.id == created!.id), isFalse);
      } finally {
        if (created != null) {
          await repository.deleteAccount(id: created.id);
        }
      }
    });
  },
      skip: missingConfigReason ??
          config?.skipReason() ??
          config?.requireResetReason());
}

void main() => registerProviderContractTests();

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
