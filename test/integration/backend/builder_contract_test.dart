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

  group(
    'Builder CRUD (real backend)',
    () {
      late BuilderRepository repository;
      late KomodoApiClient client;

      setUp(() async {
        await resetBackendIfConfigured(requireConfig(config));
        client = buildTestClient(requireConfig(config), RpcRecorder());
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
              ? Map<String, dynamic>.from(seedConfigRaw)
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
            await repository.renameBuilder(
              id: createdId,
              name: '$name-renamed',
            ),
          );

          final afterRename = expectRight(await repository.listBuilders());
          final renamed = afterRename.firstWhere(
            (item) => item.id == createdId,
          );
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

      test(
        'partial Aws edit keeps git_providers and image_registries',
        () async {
          final name = 'zz-aws-keep-${_randomToken(Random(7))}';
          String? id;
          try {
            final created = await client.write(
              RpcRequest(
                type: 'CreateBuilder',
                params: <String, dynamic>{
                  'name': name,
                  'config': <String, dynamic>{
                    'type': 'Aws',
                    'params': <String, dynamic>{
                      'region': 'us-east-1',
                      'git_providers': [
                        {
                          'domain': 'github.com',
                          'https': true,
                          'accounts': [
                            {'username': 'zz-user'},
                          ],
                        },
                      ],
                      'image_registries': [
                        {
                          'domain': 'ghcr.io',
                          'accounts': [
                            {'username': 'zz-reg'},
                          ],
                        },
                      ],
                    },
                  },
                },
              ),
            ) as Map<String, dynamic>;
            id = readIdFromMap(created);

            // Same shape the builder editor sends for an unrelated edit.
            expectRight(
              await repository.updateBuilderConfig(
                id: id,
                config: <String, dynamic>{
                  'type': 'Aws',
                  'params': <String, dynamic>{
                    'region': 'us-west-2',
                    'instance_type': 't3.small',
                    'use_https': true,
                  },
                },
              ),
            );

            final json = expectRight(
              await repository.getBuilderJson(builderIdOrName: id),
            );
            final params =
                (json['config'] as Map<String, dynamic>)['params']
                    as Map<String, dynamic>;
            expect(params['region'], 'us-west-2');
            final git = (params['git_providers'] as List).single as Map;
            expect(
              ((git['accounts'] as List).single as Map)['username'],
              'zz-user',
            );
            final reg = (params['image_registries'] as List).single as Map;
            expect(
              ((reg['accounts'] as List).single as Map)['username'],
              'zz-reg',
            );
          } finally {
            if (id != null) await repository.deleteBuilder(id: id);
          }
        },
      );
    },
    skip:
        missingConfigReason ??
        config?.skipReason() ??
        config?.requireResetReason(),
  );
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
