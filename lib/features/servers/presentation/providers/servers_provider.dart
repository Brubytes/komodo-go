import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../data/models/server.dart';
import '../../data/models/system_stats.dart';
import '../../data/repositories/server_repository.dart';

part 'servers_provider.g.dart';

/// Provides the list of all servers.
@riverpod
class Servers extends _$Servers {
  @override
  Future<List<Server>> build() async {
    final repository = ref.watch(serverRepositoryProvider);
    final result = await repository.listServers();

    return result.fold(
      (failure) => throw Exception(failure.displayMessage),
      (servers) => servers,
    );
  }

  /// Refreshes the server list.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

/// Provides details for a specific server.
@riverpod
Future<Server> serverDetail(Ref ref, String serverId) async {
  final repository = ref.watch(serverRepositoryProvider);
  final result = await repository.getServer(serverId);

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (server) => server,
  );
}

/// Provides system stats for a specific server.
@riverpod
Future<SystemStats> serverStats(Ref ref, String serverId) async {
  final repository = ref.watch(serverRepositoryProvider);
  final result = await repository.getSystemStats(serverId);

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (stats) => stats,
  );
}
