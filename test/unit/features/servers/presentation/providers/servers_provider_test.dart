import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/data/models/system_information.dart';
import 'package:komodo_go/features/servers/data/models/system_stats.dart';
import 'package:komodo_go/features/servers/data/repositories/server_repository.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../support/provider_test_templates.dart';

class _MockServerRepository extends Mock implements ServerRepository {}

void main() {
  group('Servers provider', () {
    test('returns servers when repository succeeds', () async {
      final repository = _MockServerRepository();
      when(repository.listServers).thenAnswer(
        (_) async => Right([
          Server.fromJson(<String, dynamic>{
            'id': 'srv1',
            'name': 'Server A',
            'info': <String, dynamic>{},
          }),
          Server.fromJson(<String, dynamic>{
            'id': 'srv2',
            'name': 'Server B',
            'info': <String, dynamic>{},
          }),
        ]),
      );

      final container = createProviderContainer(
        overrides: [serverRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, serversProvider);
      addTearDown(subscription.close);

      final servers = await readAsyncProvider(container, serversProvider.future);

      expect(servers, hasLength(2));
      expect(servers.first.name, 'Server A');
    });

    test('returns empty list when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [serverRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, serversProvider);
      addTearDown(subscription.close);

      final servers = await readAsyncProvider(container, serversProvider.future);

      expect(servers, isEmpty);
    });
  });

  group('Server detail providers', () {
    test('returns server detail when repository succeeds', () async {
      final repository = _MockServerRepository();
      when(() => repository.getServer('srv1')).thenAnswer(
        (_) async => Right(
          Server.fromJson(<String, dynamic>{
            'id': 'srv1',
            'name': 'Server A',
            'config': <String, dynamic>{},
          }),
        ),
      );

      final container = createProviderContainer(
        overrides: [serverRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final server = await readAsyncProvider(
        container,
        serverDetailProvider('srv1').future,
      );

      expect(server?.name, 'Server A');
    });

    test('returns null when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [serverRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final server = await readAsyncProvider(
        container,
        serverDetailProvider('srv1').future,
      );

      expect(server, isNull);
    });

    test('returns system stats when repository succeeds', () async {
      final repository = _MockServerRepository();
      when(() => repository.getSystemStats('srv1')).thenAnswer(
        (_) async => Right(
          SystemStats.fromJson(<String, dynamic>{'cpu_perc': 12}),
        ),
      );

      final container = createProviderContainer(
        overrides: [serverRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final stats = await readAsyncProvider(
        container,
        serverStatsProvider('srv1').future,
      );

      expect(stats?.cpuPercent, 12);
    });

    test('returns system information when repository succeeds', () async {
      final repository = _MockServerRepository();
      when(() => repository.getSystemInformation('srv1')).thenAnswer(
        (_) async => Right(
          SystemInformation.fromJson(<String, dynamic>{'name': 'box'}),
        ),
      );

      final container = createProviderContainer(
        overrides: [serverRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final info = await readAsyncProvider(
        container,
        serverSystemInformationProvider('srv1').future,
      );

      expect(info?.name, 'box');
    });
  });

  group('Server actions provider', () {
    test('update config returns null when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [serverRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(serverActionsProvider.notifier);
      final updated = await notifier.updateServerConfig(
        serverId: 'srv1',
        partialConfig: {'enabled': false},
      );

      expect(updated, isNull);
      expectAsyncError(container.read(serverActionsProvider));
    });

    test('update config returns server on success', () async {
      final repository = _MockServerRepository();
      when(
        () => repository.updateServerConfig(
          serverId: 'srv1',
          partialConfig: {'enabled': false},
        ),
      ).thenAnswer(
        (_) async => Right(
          Server.fromJson(<String, dynamic>{
            'id': 'srv1',
            'name': 'Server A',
            'config': <String, dynamic>{},
          }),
        ),
      );

      final container = createProviderContainer(
        overrides: [serverRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(serverActionsProvider.notifier);
      final updated = await notifier.updateServerConfig(
        serverId: 'srv1',
        partialConfig: {'enabled': false},
      );

      expect(updated?.id, 'srv1');
    });
  });
}
