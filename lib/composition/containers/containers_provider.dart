import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/network/refresh_in_place.dart';
import 'package:komodo_go/features/containers/data/models/container.dart';
import 'package:komodo_go/features/containers/data/repositories/container_repository.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/shared/resources/providers/resource_activity_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'containers_provider.g.dart';

@immutable
class ContainerFetchError {
  const ContainerFetchError({
    required this.serverId,
    required this.serverName,
    required this.message,
  });

  final String serverId;
  final String serverName;
  final String message;

  @override
  bool operator ==(Object other) =>
      other is ContainerFetchError &&
      other.serverId == serverId &&
      other.serverName == serverName &&
      other.message == message;

  @override
  int get hashCode => Object.hash(serverId, serverName, message);
}

@immutable
class ContainerOverviewItem {
  const ContainerOverviewItem({
    required this.serverId,
    required this.serverName,
    required this.container,
  });

  final String serverId;
  final String serverName;
  final ContainerListItem container;

  @override
  bool operator ==(Object other) =>
      other is ContainerOverviewItem &&
      other.serverId == serverId &&
      other.serverName == serverName &&
      other.container == container;

  @override
  int get hashCode => Object.hash(serverId, serverName, container);
}

@immutable
class ContainersResult {
  const ContainersResult({required this.items, required this.errors});

  final List<ContainerOverviewItem> items;
  final List<ContainerFetchError> errors;

  @override
  bool operator ==(Object other) =>
      other is ContainersResult &&
      listEquals(other.items, items) &&
      listEquals(other.errors, errors);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(items), Object.hashAll(errors));
}

/// Provides all docker containers across all servers.
@riverpod
class Containers extends _$Containers {
  static const int _maxConcurrentFetches = 4;

  @override
  Future<ContainersResult> build() async {
    ref.watch(resourceScopeActivityProvider(ActivityScope.containers));
    final repository = ref.watch(containerRepositoryProvider);
    if (repository == null) {
      return const ContainersResult(items: [], errors: []);
    }
    final servers = await ref.watch(serversProvider.future);
    return _load(repository, servers);
  }

  Future<ContainersResult> _load(
    ContainerRepository repository,
    List<Server> servers, {
    ContainersResult? previous,
  }) async {
    if (servers.isEmpty) {
      return const ContainersResult(items: [], errors: []);
    }

    // When polling, skip servers that are known to be down: their request
    // would only time out. Their previous rows are carried over unchanged.
    final reachable = previous == null
        ? servers
        : servers.where((s) => s.state == ServerState.ok).toList();
    final skipped = previous == null
        ? const <Server>[]
        : servers.where((s) => s.state != ServerState.ok).toList();

    final results = await _fetchWithLimit(
      repository,
      reachable,
      _maxConcurrentFetches,
    );

    final items = <ContainerOverviewItem>[];
    final errors = <ContainerFetchError>[];

    for (final result in results) {
      items.addAll(result.items);
      errors.addAll(result.errors);
    }
    if (previous != null) {
      final skippedIds = {for (final s in skipped) s.id};
      items.addAll(
        previous.items.where((i) => skippedIds.contains(i.serverId)),
      );
      errors.addAll(
        previous.errors.where((e) => skippedIds.contains(e.serverId)),
      );
    }

    items.sort(
      (a, b) => a.container.name.toLowerCase().compareTo(
        b.container.name.toLowerCase(),
      ),
    );

    return ContainersResult(items: items, errors: errors);
  }

  /// Poll tick: refetch reachable servers and update state only if the
  /// result differs, so watchers do not rebuild on identical data.
  Future<void> pollRefresh() {
    final previous = state.value;
    final repository = ref.read(containerRepositoryProvider);
    if (previous == null || repository == null || state.isLoading) {
      return Future.value();
    }
    return refreshInPlace<ContainersResult>(
      current: previous,
      fetch: () async => _load(
        repository,
        await ref.read(serversProvider.future),
        previous: previous,
      ),
      apply: (value) => state = AsyncData(value),
      isMounted: () => ref.mounted,
    );
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

    final workers = <Future<void>>[for (var i = 0; i < limit; i++) runNext()];

    await Future.wait(workers);
    return results.whereType<ContainersResult>().toList();
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
    try {
      await future;
    } on Exception {
      // Ignore refresh errors.
    }
  }
}

/// Action state for container operations.
@riverpod
class ContainerActions extends _$ContainerActions {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> stop({
    required String serverIdOrName,
    required String containerIdOrName,
  }) {
    return _executeAction(
      (repo) => repo.stopContainer(
        serverIdOrName: serverIdOrName,
        containerIdOrName: containerIdOrName,
      ),
    );
  }

  Future<bool> restart({
    required String serverIdOrName,
    required String containerIdOrName,
  }) {
    return _executeAction(
      (repo) => repo.restartContainer(
        serverIdOrName: serverIdOrName,
        containerIdOrName: containerIdOrName,
      ),
    );
  }

  Future<bool> start({
    required String serverIdOrName,
    required String containerIdOrName,
  }) => _executeAction(
    (repo) => repo.startContainer(
      serverIdOrName: serverIdOrName,
      containerIdOrName: containerIdOrName,
    ),
  );

  Future<bool> pause({
    required String serverIdOrName,
    required String containerIdOrName,
  }) => _executeAction(
    (repo) => repo.pauseContainer(
      serverIdOrName: serverIdOrName,
      containerIdOrName: containerIdOrName,
    ),
  );

  Future<bool> unpause({
    required String serverIdOrName,
    required String containerIdOrName,
  }) => _executeAction(
    (repo) => repo.unpauseContainer(
      serverIdOrName: serverIdOrName,
      containerIdOrName: containerIdOrName,
    ),
  );

  Future<bool> remove({
    required String serverIdOrName,
    required String containerIdOrName,
  }) => _executeAction(
    (repo) => repo.removeContainer(
      serverIdOrName: serverIdOrName,
      containerIdOrName: containerIdOrName,
    ),
  );

  Future<bool> _executeAction(
    Future<Either<Failure, void>> Function(ContainerRepository repo) action,
  ) async {
    final repository = ref.read(containerRepositoryProvider);
    if (repository == null) {
      state = AsyncValue.error('Not authenticated', StackTrace.current);
      return false;
    }

    state = const AsyncValue.loading();

    final result = await action(repository);

    if (!ref.mounted) return false;

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.displayMessage, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        ref.invalidate(containersProvider);
        ref
            .read(resourceActivityProvider.notifier)
            .markChanged(
              scopes: {ActivityScope.containers},
            );
        return true;
      },
    );
  }
}
