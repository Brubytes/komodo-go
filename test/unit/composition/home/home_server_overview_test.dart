import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/home/home_server_overview_provider.dart';
import 'package:komodo_go/composition/home/home_view.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/data/models/system_stats.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';

class _FakeServers extends Servers {
  @override
  Future<List<Server>> build() async => const [
    Server(
      id: 's1',
      name: 'one',
      info: ServerInfo(state: ServerState.ok),
    ),
  ];
}

void main() {
  const online = Server(
    id: 's1',
    name: 'one',
    info: ServerInfo(state: ServerState.ok),
  );
  const down = Server(
    id: 's2',
    name: 'two',
    info: ServerInfo(state: ServerState.notOk),
  );

  test('overview summarises server states without stats', () {
    final overview = buildHomeServerOverview(
      [online, down],
      const [AsyncData(null), AsyncLoading()],
    );
    expect(overview.serverCount, '2');
    expect(overview.serverSubtitle, '1 online · 1 down');
    expect(overview.cpuValue, '—');
    expect(overview.cpuSubtitle, 'Loading stats');
  });

  test('equal overviews compare equal so sections skip rebuilds', () {
    final a = buildHomeServerOverview([online], const [AsyncData(null)]);
    final b = buildHomeServerOverview([online], const [AsyncData(null)]);
    expect(a, b);
  });

  testWidgets('server overview section renders metric cards', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serversProvider.overrideWith(_FakeServers.new),
          serverStatsProvider.overrideWith2((_) => _NullServerStats()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: HomeServerOverviewSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Server overview'), findsOneWidget);
    expect(find.text('CPU Avg'), findsOneWidget);
    expect(find.text('Servers'), findsOneWidget);
    expect(find.text('1 online'), findsOneWidget);
  });
}

class _NullServerStats extends ServerStats {
  @override
  Future<SystemStats?> build(String serverId) async => null;
}
