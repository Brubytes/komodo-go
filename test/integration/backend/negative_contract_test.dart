import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/actions/data/repositories/action_repository.dart';
import 'package:komodo_go/features/alerters/data/repositories/alerter_repository.dart';
import 'package:komodo_go/features/builders/data/repositories/builder_repository.dart';
import 'package:komodo_go/features/builds/data/repositories/build_repository.dart';
import 'package:komodo_go/features/deployments/data/repositories/deployment_repository.dart';
import 'package:komodo_go/features/procedures/data/repositories/procedure_repository.dart';
import 'package:komodo_go/features/providers/data/repositories/docker_registry_repository.dart';
import 'package:komodo_go/features/providers/data/repositories/git_provider_repository.dart';
import 'package:komodo_go/features/repos/data/repositories/repo_repository.dart';
import 'package:komodo_go/features/servers/data/repositories/server_repository.dart';
import 'package:komodo_go/features/stacks/data/repositories/stack_repository.dart';
import 'package:komodo_go/features/syncs/data/repositories/sync_repository.dart';
import 'package:komodo_go/features/tags/data/repositories/tag_repository.dart';
import 'package:komodo_go/features/variables/data/repositories/variable_repository.dart';

import '../../support/backend_test_config.dart';
import '../../support/backend_test_helpers.dart';

void registerNegativeContractTests() {
  final config = BackendTestConfig.fromEnvironment();
  final missingConfigReason = config == null
      ? 'Set KOMODO_TEST_BASE_URL, KOMODO_TEST_API_KEY, and '
            'KOMODO_TEST_API_SECRET to run backend tests.'
      : null;

  group(
    'Backend auth errors (real backend)',
    () {
      test('invalid credentials return auth or rate-limit failures', () async {
        final requiredConfig = requireConfig(config);
        final badConfig = BackendTestConfig(
          baseUrl: requiredConfig.baseUrl,
          apiKey: requiredConfig.apiKey,
          apiSecret: 'invalid-secret',
          coreVersion: requiredConfig.coreVersion,
          allowDestructive: requiredConfig.allowDestructive,
          resetCommand: requiredConfig.resetCommand,
        );

        _expectAuthOrRateLimitFailure(
          await TagRepository(
            buildTestClient(badConfig, RpcRecorder()),
          ).listTags(),
        );
        _expectAuthOrRateLimitFailure(
          await StackRepository(
            buildTestClient(badConfig, RpcRecorder()),
          ).listStacks(),
        );
        _expectAuthOrRateLimitFailure(
          await DeploymentRepository(
            buildTestClient(badConfig, RpcRecorder()),
          ).listDeployments(),
        );
        _expectAuthOrRateLimitFailure(
          await RepoRepository(
            buildTestClient(badConfig, RpcRecorder()),
          ).listRepos(),
        );
        _expectAuthOrRateLimitFailure(
          await SyncRepository(
            buildTestClient(badConfig, RpcRecorder()),
          ).listSyncs(),
        );
        _expectAuthOrRateLimitFailure(
          await BuildRepository(
            buildTestClient(badConfig, RpcRecorder()),
          ).listBuilds(),
        );
        _expectAuthOrRateLimitFailure(
          await ActionRepository(
            buildTestClient(badConfig, RpcRecorder()),
          ).listActions(),
        );
        _expectAuthOrRateLimitFailure(
          await ProcedureRepository(
            buildTestClient(badConfig, RpcRecorder()),
          ).listProcedures(),
        );
        _expectAuthOrRateLimitFailure(
          await ServerRepository(
            buildTestClient(badConfig, RpcRecorder()),
          ).listServers(),
        );
        _expectAuthOrRateLimitFailure(
          await AlerterRepository(
            buildTestClient(badConfig, RpcRecorder()),
          ).listAlerters(),
        );
        _expectAuthOrRateLimitFailure(
          await BuilderRepository(
            buildTestClient(badConfig, RpcRecorder()),
          ).listBuilders(),
        );
        _expectAuthOrRateLimitFailure(
          await GitProviderRepository(
            buildTestClient(badConfig, RpcRecorder()),
          ).listAccounts(),
        );
        _expectAuthOrRateLimitFailure(
          await DockerRegistryRepository(
            buildTestClient(badConfig, RpcRecorder()),
          ).listAccounts(),
        );
        _expectAuthOrRateLimitFailure(
          await VariableRepository(
            buildTestClient(badConfig, RpcRecorder()),
          ).listVariables(),
        );
      });
    },
    skip: missingConfigReason ?? config?.skipReason(),
  );

  group(
    'Backend not-found errors (real backend)',
    () {
      test('missing ids return server failure across repositories', () async {
        final random = Random(20261);
        final token = _randomToken(random);
        final requiredConfig = requireConfig(config);

        final stackRepository = StackRepository(
          buildTestClient(requiredConfig, RpcRecorder()),
        );
        expectServerFailure(
          await stackRepository.getStack('missing-stack-$token'),
        );

        final deploymentRepository = DeploymentRepository(
          buildTestClient(requiredConfig, RpcRecorder()),
        );
        expectServerFailure(
          await deploymentRepository.getDeployment('missing-deploy-$token'),
        );

        final repoRepository = RepoRepository(
          buildTestClient(requiredConfig, RpcRecorder()),
        );
        expectServerFailure(
          await repoRepository.getRepo('missing-repo-$token'),
        );

        final syncRepository = SyncRepository(
          buildTestClient(requiredConfig, RpcRecorder()),
        );
        expectServerFailure(
          await syncRepository.getSync('missing-sync-$token'),
        );

        final buildRepository = BuildRepository(
          buildTestClient(requiredConfig, RpcRecorder()),
        );
        expectServerFailure(
          await buildRepository.getBuild('missing-build-$token'),
        );

        final actionRepository = ActionRepository(
          buildTestClient(requiredConfig, RpcRecorder()),
        );
        expectServerFailure(
          await actionRepository.getAction('missing-action-$token'),
        );

        final procedureRepository = ProcedureRepository(
          buildTestClient(requiredConfig, RpcRecorder()),
        );
        expectServerFailure(
          await procedureRepository.getProcedure('missing-proc-$token'),
        );

        final serverRepository = ServerRepository(
          buildTestClient(requiredConfig, RpcRecorder()),
        );
        expectServerFailure(
          await serverRepository.getServer('missing-srv-$token'),
        );

        final alerterRepository = AlerterRepository(
          buildTestClient(requiredConfig, RpcRecorder()),
        );
        expectServerFailure(
          await alerterRepository.getAlerterDetail(
            alerterIdOrName: 'missing-alerter-$token',
          ),
        );

        final builderRepository = BuilderRepository(
          buildTestClient(requiredConfig, RpcRecorder()),
        );
        expectServerFailure(
          await builderRepository.getBuilderJson(
            builderIdOrName: 'missing-builder-$token',
          ),
        );
      });
    },
    skip:
        missingConfigReason ??
        config?.skipReason() ??
        config?.requireResetReason(),
  );

  group(
    'Backend validation/server errors (real backend)',
    () {
      test('invalid write payload returns 4xx error', () async {
        final dio = buildTestDio(requireConfig(config));
        dio.options.validateStatus = (status) => true;
        // Missing required 'params' field triggers 422 Unprocessable Entity
        final response = await dio.post<Map<String, dynamic>>(
          '/write',
          data: <String, dynamic>{
            'type': 'CreateTag',
          },
        );

        final statusCode = response.statusCode;
        expect(statusCode, isNotNull);
        expect(statusCode, inInclusiveRange(400, 499));
      });

      test('invalid read query returns a backend error', () async {
        final dio = buildTestDio(requireConfig(config));
        dio.options.validateStatus = (status) => true;
        Response<Map<String, dynamic>>? response;
        for (var attempt = 0; attempt < 3; attempt++) {
          response = await dio.post<Map<String, dynamic>>(
            '/read',
            data: <String, dynamic>{
              'type': 'ListStacks',
              'params': <String, dynamic>{'query': 'invalid'},
            },
          );
          if (response.statusCode != 429) break;

          final retryAfter = int.tryParse(
            response.headers.value('retry-after') ?? '',
          );
          await Future<void>.delayed(
            Duration(seconds: (retryAfter ?? 15) + 1),
          );
        }

        final statusCode = response?.statusCode;
        expect(statusCode, isNotNull);
        expect(statusCode, inInclusiveRange(400, 599));
        expect(statusCode, isNot(429));
      });
    },
    skip: missingConfigReason ?? config?.skipReason(),
  );
}

void main() => registerNegativeContractTests();

void _expectAuthOrRateLimitFailure<T>(Either<Failure, T> result) {
  final failure = expectLeft(result);
  switch (failure) {
    case AuthFailure():
      return;
    case ServerFailure(statusCode: 429):
      return;
    default:
      fail('Expected auth or rate-limit failure, got $failure');
  }
}

String _randomToken(Random random) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final buffer = StringBuffer();
  for (var i = 0; i < 6; i++) {
    buffer.write(chars[random.nextInt(chars.length)]);
  }
  return buffer.toString();
}
