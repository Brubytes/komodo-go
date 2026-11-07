import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/async/async_value_x.dart';
import 'package:komodo_go/core/widgets/async/action_busy_overlay.dart';
import 'package:komodo_go/core/widgets/async/async_content.dart';
import 'package:komodo_go/core/widgets/async/editor_host.dart';
import 'package:komodo_go/core/widgets/async/refresh_progress_bar.dart';
import 'package:komodo_go/core/widgets/async/stale_data_banner.dart';
import 'package:komodo_go/core/widgets/empty_error_state.dart';

class _Probe extends StatefulWidget {
  const _Probe({required this.label});
  final String label;

  static int created = 0;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _Probe.created++;
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}

Widget _host(AsyncValue<String> value) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: AsyncContent<String>(
        value: value,
        onRetry: () {},
        skeletonBuilder: (_) => const Text('skeleton'),
        builder: (context, data) => _Probe(label: data),
      ),
    ),
  ),
);

AsyncValue<String> _refreshing(String v) =>
    asyncWithPrevious<String>(const AsyncLoading(), AsyncData(v));
AsyncValue<String> _reloading(String v) => asyncWithPrevious<String>(
  const AsyncLoading(),
  AsyncData(v),
  isRefresh: false,
);
AsyncValue<String> _staleError(String v) => asyncWithPrevious<String>(
  const AsyncError('boom', StackTrace.empty),
  AsyncData(v),
);

void main() {
  setUp(() => _Probe.created = 0);

  testWidgets('skeleton only on first load, then content stays mounted', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const AsyncLoading()));
    expect(find.text('skeleton'), findsOneWidget);
    expect(find.byType(ErrorStateView), findsNothing);

    await tester.pumpWidget(_host(const AsyncData('one')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('skeleton'), findsNothing);
    expect(find.text('one'), findsOneWidget);
    expect(_Probe.created, 1);

    for (final next in [
      _refreshing('one'),
      _reloading('one'),
      _staleError('one'),
      const AsyncData('two'),
    ]) {
      await tester.pumpWidget(_host(next));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('skeleton'), findsNothing, reason: '$next');
      expect(find.byType(ErrorStateView), findsNothing, reason: '$next');
      expect(find.byType(_Probe), findsOneWidget, reason: '$next');
    }
    expect(find.text('two'), findsOneWidget);
    expect(_Probe.created, 1, reason: 'content state was never recreated');
  });

  testWidgets('error view only without a value', (tester) async {
    await tester.pumpWidget(_host(const AsyncError('boom', StackTrace.empty)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ErrorStateView), findsOneWidget);
    expect(find.byType(_Probe), findsNothing);
  });

  testWidgets('progress bar shows (after delay) only while loading', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const AsyncData('one')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.pumpWidget(_host(_refreshing('one')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pumpWidget(_host(const AsyncData('one')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('stale banner appears with a value and an error', (tester) async {
    await tester.pumpWidget(_host(const AsyncData('one')));
    expect(find.text('Retry'), findsNothing);

    await tester.pumpWidget(_host(_staleError('one')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(StaleDataBanner), findsOneWidget);
    expect(find.text('one'), findsOneWidget);
  });

  testWidgets('fill mode: first-load and error states are scrollable', (
    tester,
  ) async {
    Widget fillHost(AsyncValue<String> v) => MaterialApp(
      home: Scaffold(
        body: RefreshIndicator(
          onRefresh: () async {},
          child: AsyncContent<String>(
            value: v,
            fill: true,
            onRetry: () {},
            builder: (context, d) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [Text(d)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(fillHost(const AsyncLoading()));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.pumpWidget(fillHost(const AsyncError('x', StackTrace.empty)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byType(ErrorStateView), findsOneWidget);
    await tester.pumpWidget(fillHost(const AsyncData('ok')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('ok'), findsOneWidget);
  });

  testWidgets('SliverAsyncContent keeps content through refresh/error', (
    tester,
  ) async {
    Widget host(AsyncValue<String> v) => MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAsyncContent<String>(
              value: v,
              onRetry: () {},
              skeletonBuilder: (_) => const Text('skeleton'),
              builder: (context, d) =>
                  SliverToBoxAdapter(child: _Probe(label: d)),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(host(const AsyncLoading()));
    expect(find.text('skeleton'), findsOneWidget);
    await tester.pumpWidget(host(const AsyncData('a')));
    await tester.pumpWidget(host(_reloading('a')));
    await tester.pumpWidget(host(_staleError('a')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_Probe.created, 1);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('RefreshProgressBar reserves height and honours delay', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topCenter,
          child: RefreshProgressBar(active: true),
        ),
      ),
    );
    expect(tester.getSize(find.byType(RefreshProgressBar)).height, 2);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('ActionBusyOverlay blocks input at once, shows visuals late', (
    tester,
  ) async {
    var taps = 0;
    Widget host({required bool busy}) => MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Center(
              child: TextButton(
                onPressed: () => taps++,
                child: const Text('go'),
              ),
            ),
            ActionBusyOverlay(busy: busy),
          ],
        ),
      ),
    );
    await tester.pumpWidget(host(busy: false));
    await tester.tap(find.text('go'));
    expect(taps, 1);

    await tester.pumpWidget(host(busy: true));
    await tester.tap(find.text('go'), warnIfMissed: false);
    expect(taps, 1, reason: 'input is blocked immediately');
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(host(busy: false));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('go'));
    expect(taps, 2);
  });

  testWidgets('EditorHost stays mounted and holds back data while dirty', (
    tester,
  ) async {
    var dirty = false;
    Widget host(AsyncValue<String?> v) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: EditorHost<String>(
            value: v,
            onRetry: () {},
            isDirty: () => dirty,
            skeletonBuilder: (_) => const Text('skeleton'),
            builder: (context, d) => _Probe(label: d),
          ),
        ),
      ),
    );
    await tester.pumpWidget(host(const AsyncLoading()));
    expect(find.text('skeleton'), findsOneWidget);
    await tester.pumpWidget(host(const AsyncData('v1')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('v1'), findsOneWidget);

    // Loading without any value (a plain AsyncLoading) must not unmount it.
    await tester.pumpWidget(host(const AsyncLoading()));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('v1'), findsOneWidget);
    expect(find.text('skeleton'), findsNothing);

    dirty = true;
    await tester.pumpWidget(host(const AsyncData('v2')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('v1'), findsOneWidget, reason: 'draft wins while dirty');

    dirty = false;
    await tester.pumpWidget(host(const AsyncData('v2')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('v2'), findsOneWidget);
    expect(_Probe.created, 1);
  });

  testWidgets('retry on the first-load error page shows the progress bar', (
    tester,
  ) async {
    const error = AsyncError<String>('boom', StackTrace.empty);
    await tester.pumpWidget(_host(error));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ErrorStateView), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    // Retry tapped: error + loading. Layout stays, the bar appears.
    await tester.pumpWidget(
      _host(asyncWithPrevious<String>(const AsyncLoading(), error)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ErrorStateView), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('EditorHost shows emptyBuilder after the value settles to null', (
    tester,
  ) async {
    var dirty = false;
    Widget host(AsyncValue<String?> v) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: EditorHost<String>(
            value: v,
            onRetry: () {},
            isDirty: () => dirty,
            emptyBuilder: (_) => const Text('gone'),
            builder: (context, d) => _Probe(label: d),
          ),
        ),
      ),
    );
    await tester.pumpWidget(host(const AsyncData('v1')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('v1'), findsOneWidget);

    // Dirty editor survives a deletion.
    dirty = true;
    await tester.pumpWidget(host(const AsyncData(null)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('v1'), findsOneWidget);
    expect(find.text('gone'), findsNothing);

    dirty = false;
    await tester.pumpWidget(host(const AsyncData(null)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('gone'), findsOneWidget);
    expect(find.text('v1'), findsNothing);
  });
}
