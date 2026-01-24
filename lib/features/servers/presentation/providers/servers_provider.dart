import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/error/provider_error.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/data/models/system_information.dart';
import 'package:komodo_go/features/servers/data/models/system_stats.dart';
import 'package:komodo_go/features/servers/data/repositories/server_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'servers_provider.g.dart';

/// Provides the list of all servers.
@riverpod
class Servers extends _$Servers {
  @override
  Future<List<Server>> build() async {
    final repository = ref.watch(serverRepositoryProvider);

    // Not authenticated yet - return empty list and wait for auth
    if (repository == null) {
      return [];
    }

    final result = await repository.listServers();

    return unwrapOrThrow(result);
  }

  /// Refreshes the server list.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {}
  }
}

/// Provides details for a specific server.
@riverpod
Future<Server?> serverDetail(Ref ref, String serverId) async {
  final repository = ref.watch(serverRepositoryProvider);
  if (repository == null) {
    return null;
  }

  final result = await repository.getServer(serverId);

  return unwrapOrThrow(result);
}

/// Provides system stats for a specific server.
@riverpod
Future<SystemStats?> serverStats(Ref ref, String serverId) async {
  final repository = ref.watch(serverRepositoryProvider);
  if (repository == null) {
    return null;
  }

  final result = await repository.getSystemStats(serverId);

  return unwrapOrThrow(result);
}

/// Provides system information for a specific server.
@riverpod
Future<SystemInformation?> serverSystemInformation(
  Ref ref,
  String serverId,
) async {
  final repository = ref.watch(serverRepositoryProvider);
  if (repository == null) {
    return null;
  }

  final result = await repository.getSystemInformation(serverId);

  return unwrapOrThrow(result);
}

/// Action state for server operations.
@riverpod
class ServerActions extends _$ServerActions {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<Server?> updateServerConfig({
    required String serverId,
    required Map<String, dynamic> partialConfig,
  }) => _executeRequest(
    (repo) => repo.updateServerConfig(
      serverId: serverId,
      partialConfig: partialConfig,
    ),
  );

  Future<T?> _executeRequest<T>(
    Future<Either<Failure, T>> Function(ServerRepository repo) request,
  ) async {
    final repository = ref.read(serverRepositoryProvider);
    if (repository == null) {
      state = AsyncValue.error('Not authenticated', StackTrace.current);
      return null;
    }

    state = const AsyncValue.loading();

    final result = await request(repository);

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.displayMessage, StackTrace.current);
        return null;
      },
      (value) {
        state = const AsyncValue.data(null);
        ref.invalidate(serversProvider);
        return value;
      },
    );
  }
}
