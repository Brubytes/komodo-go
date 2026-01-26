import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/builders/data/models/builder_list_item.dart';
import 'package:komodo_go/features/builders/data/repositories/builder_repository.dart';

import '../../support/backend_test_config.dart';
import '../../support/backend_test_helpers.dart';

void registerBuilderContractTests() {
  final config = BackendTestConfig.fromEnvironment();
  final missingConfigReason = config == null
      ? 'Set KOMODO_TEST_BASE_URL, KOMODO_TEST_API_KEY, and '
          'KOMODO_TEST_API_SECRET to run backend tests.'
      : null;

  group('Builder CRUD (real backend)', () {
    late BuilderRepository repository;
    late KomodoApiClient client;

    setUp(() async {
      await resetBackendIfConfigured(config!);
      client = buildTestClient(config!, RpcRecorder());
      repository = BuilderRepository(client);
    });

    test('create/rename/delete builder', () async {
      BuilderListItem? created;

      try {
        final builders = expectRight(await repository.listBuilders());
        expect(builders, isNotEmpty);

        final seed = builders.first;
        final seedJson = expectRight(
          await repository.getBuilderJson(builderIdOrName: seed.id),
        );
        final seedConfigRaw = seedJson['config'];
        final seedConfig = seedConfigRaw is Map
            ? Map<String, dynamic>.from(seedConfigRaw as Map)
            : <String, dynamic>{};

        final name = 'contract-builder-${_randomToken(Random(5021))}';
        final createdJson = await client.write(
          RpcRequest(
            type: 'CreateBuilder',
            params: <String, dynamic>{'name': name, 'config': seedConfig},
          ),
        );
        final createdMap = createdJson as Map<String, dynamic>;
        final createdId = readIdFromMap(createdMap);

        final afterCreate = expectRight(await repository.listBuilders());
        created = afterCreate.firstWhere(
          (item) => item.id == createdId,
          orElse: () => BuilderListItem.fromJson(createdMap),
        );

        expectRight(
          await repository.renameBuilder(id: createdId, name: '$name-renamed'),
        );

        final afterRename = expectRight(await repository.listBuilders());
        final renamed = afterRename.firstWhere((item) => item.id == createdId);
        expect(renamed.name, '$name-renamed');

        expectRight(await repository.deleteBuilder(id: createdId));
        await expectEventuallyServerFailure(
          () => repository.getBuilderJson(builderIdOrName: createdId),
        );
        final afterDelete = expectRight(await repository.listBuilders());
        expect(afterDelete.any((item) => item.id == createdId), isFalse);
      } finally {
        if (created != null) {
          await repository.deleteBuilder(id: created.id);
        }
      }
    });
  },
      skip: missingConfigReason ??
          config?.skipReason() ??
          config?.requireResetReason());
}

void main() => registerBuilderContractTests();

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
