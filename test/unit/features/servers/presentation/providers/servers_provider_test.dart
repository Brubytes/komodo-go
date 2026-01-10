import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/data/repositories/server_repository.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockServerRepository extends Mock implements ServerRepository {}

void main() {
  group('Servers provider', () {
    test('returns servers when repository succeeds', () async {
      final repository = _MockServerRepository();
      when(repository.listServers).thenAnswer(
        (_) async => Right([
          Server.fromJson({
            'id': 'server-1',
            'name': 'alpha',
            'info': {'state': 'Ok', 'address': '10.0.0.1'},
          }),
        ]),
      );

      final container = ProviderContainer(
        overrides: [serverRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        serversProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final servers = await container.read(serversProvider.future);

      expect(servers, hasLength(1));
      expect(servers.first.id, 'server-1');
    });

    test('returns empty list when unauthenticated', () async {
      final container = ProviderContainer(
        overrides: [serverRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        serversProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final servers = await container.read(serversProvider.future);

      expect(servers, isEmpty);
    });
  });
}
