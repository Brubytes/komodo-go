import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../../servers/data/models/server.dart';
import '../../../servers/presentation/providers/servers_provider.dart';
import '../../data/models/container.dart';
import '../../data/repositories/container_repository.dart';

part 'containers_provider.g.dart';

class ContainerFetchError {
  const ContainerFetchError({
    required this.serverId,
    required this.serverName,
    required this.message,
  });

  final String serverId;
  final String serverName;
  final String message;
}

class ContainerOverviewItem {
  const ContainerOverviewItem({
    required this.serverId,
    required this.serverName,
    required this.container,
  });

  final String serverId;
  final String serverName;
  final ContainerListItem container;
}

class ContainersResult {
  const ContainersResult({required this.items, required this.errors});

  final List<ContainerOverviewItem> items;
  final List<ContainerFetchError> errors;
}

/// Provides all docker containers across all servers.
@riverpod
class Containers extends _$Containers {
  static const int _maxConcurrentFetches = 4;

  @override
  Future<ContainersResult> build() async {
    final repository = ref.watch(containerRepositoryProvider);
    if (repository == null) {
      return const ContainersResult(items: [], errors: []);
    }

    final servers = await ref.watch(serversProvider.future);
    if (servers.isEmpty) {
      return const ContainersResult(items: [], errors: []);
    }

    final results = await _fetchWithLimit(
      repository,
      servers,
      _maxConcurrentFetches,
    );

    final items = <ContainerOverviewItem>[];
    final errors = <ContainerFetchError>[];

    for (final result in results) {
      items.addAll(result.items);
      errors.addAll(result.errors);
    }

    items.sort(
      (a, b) => a.container.name.toLowerCase().compareTo(
        b.container.name.toLowerCase(),
      ),
    );

    return ContainersResult(items: items, errors: errors);
  }

  Future<List<ContainersResult>> _fetchWithLimit(
    ContainerRepository repository,
    List<Server> servers,
    int concurrency,
  ) async {
    if (servers.isEmpty) return const <ContainersResult>[];
    final limit = concurrency.clamp(1, servers.length);
    final results = List<ContainersResult?>.filled(servers.length, null);
    var index = 0;

    Future<void> runNext() async {
      final nextIndex = index++;
      if (nextIndex >= servers.length) return;
      results[nextIndex] = await _fetchForServer(
        repository,
        servers[nextIndex],
      );
      if (index < servers.length) {
        await runNext();
      }
    }

    final workers = <Future<void>>[
      for (var i = 0; i < limit; i++) runNext(),
    ];

    await Future.wait(workers);
    return [for (final result in results) if (result != null) result];
  }

  Future<ContainersResult> _fetchForServer(
    ContainerRepository repository,
    Server server,
  ) async {
    final result = await repository.listDockerContainers(server.id);

    return result.fold(
      (failure) => ContainersResult(
        items: const [],
        errors: [
          ContainerFetchError(
            serverId: server.id,
            serverName: server.name,
            message: failure.displayMessage,
          ),
        ],
      ),
      (containers) => ContainersResult(
        items: [
          for (final container in containers)
            ContainerOverviewItem(
              serverId: server.id,
              serverName: server.name,
              container: container.copyWith(
                serverId: container.serverId ?? server.id,
              ),
            ),
        ],
        errors: const [],
      ),
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
