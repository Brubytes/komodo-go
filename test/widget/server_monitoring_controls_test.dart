import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/servers/data/models/system_stats.dart';
import 'package:komodo_go/features/servers/presentation/views/server_detail/server_detail_sections.dart';

void main() {
  testWidgets('chart scale survives a sample interval reload', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 912));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: _StatsControlHarness()));
    await tester.pumpAndSettle();

    expect(find.text('1 min'), findsOneWidget);
    expect(find.text('Auto'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('Auto'), findsOneWidget);

    await tester.tap(find.text('5 min'));
    await tester.pumpAndSettle();

    expect(find.text('Auto'), findsOneWidget);
    final control = tester.widget<SegmentedButton<ServerStatsGranularity>>(
      find.byType(SegmentedButton<ServerStatsGranularity>),
    );
    expect(control.selected, {ServerStatsGranularity.fiveMinutes});
    expect(tester.takeException(), isNull);
  });

  testWidgets('process expansion state does not collide with scroll offset', (
    tester,
  ) async {
    final bucket = PageStorageBucket();
    final processes = List.generate(
      30,
      (index) => SystemProcess(
        pid: index + 1,
        name: 'process-$index',
        executable: '/bin/process-$index',
        command: ['process-$index'],
        startTime: 0,
        cpuPercent: index.toDouble(),
        memoryMb: 64,
        diskReadKb: 0,
        diskWriteKb: 0,
      ),
    );

    Widget buildProcesses() => MaterialApp(
      home: PageStorage(
        bucket: bucket,
        child: CustomScrollView(
          key: const PageStorageKey<String>('server_system'),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SystemProcessesContent(processes: processes),
              ),
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(buildProcesses());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    // Disposing the scroll view stores its double offset in PageStorage.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();

    // Recreating process ExpansionTiles must read their own bool storage slot,
    // not the parent scroll view's double slot.
    await tester.pumpWidget(buildProcesses());
    await tester.pumpAndSettle();

    expect(find.text('Processes (30)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected process sort label stays on one line', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 912));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: SystemProcessesContent(processes: []),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mem'));
    await tester.pumpAndSettle();

    final memoryLabelSize = tester.getSize(find.text('Mem'));
    final readLabelSize = tester.getSize(find.text('Read'));
    final selector = find.byWidgetPredicate(
      (widget) => widget is SegmentedButton,
    );
    expect(memoryLabelSize.height, closeTo(readLabelSize.height, 0.1));
    expect(
      tester.getCenter(selector).dx,
      closeTo(tester.getCenter(find.byType(SystemProcessesContent)).dx, 0.1),
    );
    expect(find.byIcon(Icons.check), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _StatsControlHarness extends StatefulWidget {
  const _StatsControlHarness();

  @override
  State<_StatsControlHarness> createState() => _StatsControlHarnessState();
}

class _StatsControlHarnessState extends State<_StatsControlHarness> {
  ServerStatsGranularity _granularity = ServerStatsGranularity.oneMinute;
  bool _fixedScale = true;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const CircularProgressIndicator()
            : StatsHistoryContent(
                history: const [],
                latestStats: const SystemStats(),
                granularity: _granularity,
                useFixedPercentScale: _fixedScale,
                onScaleChanged: (value) {
                  setState(() => _fixedScale = value);
                },
                onGranularityChanged: (value) {
                  setState(() {
                    _granularity = value;
                    _loading = true;
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _loading = false);
                  });
                },
              ),
      ),
    );
  }
}
