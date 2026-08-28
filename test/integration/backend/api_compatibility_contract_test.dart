import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';
import 'package:komodo_go/features/auth/data/repositories/auth_repository.dart';
import 'package:komodo_go/features/containers/data/repositories/container_repository.dart';
import 'package:komodo_go/features/providers/data/repositories/docker_registry_repository.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/data/models/system_stats.dart';
import 'package:komodo_go/features/servers/data/repositories/server_repository.dart';

import '../../support/backend_test_config.dart';
import '../../support/backend_test_helpers.dart';

void main() {
  final config = BackendTestConfig.fromEnvironment();
  final missingConfigReason = config == null
      ? 'Set KOMODO_TEST_BASE_URL, KOMODO_TEST_API_KEY, and '
            'KOMODO_TEST_API_SECRET to run backend tests.'
      : null;

  group('API generation compatibility (real backend)', () {
    late KomodoApiClient client;

    setUp(() {
      client = buildTestClient(requireConfig(config), RpcRecorder());
    });

    test('reports the expected Core version', () async {
      final response = await client.read(
        const RpcRequest<dynamic>(
          type: 'GetVersion',
          params: <String, dynamic>{},
        ),
      );

      expect(response, isA<Map<String, dynamic>>());
      expect(
        (response as Map<String, dynamic>)['version'],
        config?.coreVersion,
      );
    });

    test('authentication discovers the Core version', () async {
      final requiredConfig = requireConfig(config);
      final result = await AuthRepository().validateCredentials(
        ApiCredentials(
          baseUrl: requiredConfig.baseUrl,
          apiKey: requiredConfig.apiKey,
          apiSecret: requiredConfig.apiSecret,
        ),
      );

      final version = expectRight(result);
      expect(version.raw, requiredConfig.coreVersion);
    });

    test(
      'lists resources, containers, networks, and registry accounts',
      () async {
        final serverRepository = ServerRepository(client);
        final servers = expectRight(await serverRepository.listServers());
        expect(servers, isNotEmpty);
        final server = servers.first;

        expectRight(
          await ContainerRepository(client).listDockerContainers(server.id),
        );
        expectRight(await serverRepository.listDockerNetworks(server.id));
        expectRight(await DockerRegistryRepository(client).listAccounts());
      },
    );

    test('supports monitoring and container inspection APIs', () async {
      final serverRepository = ServerRepository(client);
      final containerRepository = ContainerRepository(client);
      final servers = expectRight(await serverRepository.listServers());
      expect(servers, isNotEmpty);
      final historyServer = servers.first;

      final history = expectRight(
        await serverRepository.getHistoricalSystemStats(
          serverIdOrName: historyServer.id,
          granularity: ServerStatsGranularity.oneMinute,
        ),
      );
      expect(history.stats, isA<List<HistoricalSystemStats>>());

      Server? server;
      for (final candidate in servers) {
        if (candidate.state == ServerState.ok) {
          server = candidate;
          break;
        }
      }
      if (server == null) return;

      final processes = expectRight(
        await serverRepository.listSystemProcesses(server.id),
      );
      expect(processes, isA<List<SystemProcess>>());

      final containers = expectRight(
        await containerRepository.listDockerContainers(server.id),
      );
      if (containers.isEmpty) return;

      final container = containers.first;
      final containerIdOrName = container.id ?? container.name;
      final inspection = expectRight(
        await containerRepository.inspectContainer(
          serverIdOrName: server.id,
          containerIdOrName: containerIdOrName,
        ),
      );
      expect(inspection.raw, isNotEmpty);

      expectRight(
        await containerRepository.getResourceMatchingContainer(
          serverIdOrName: server.id,
          containerIdOrName: containerIdOrName,
        ),
      );
    });
  }, skip: missingConfigReason);
}
