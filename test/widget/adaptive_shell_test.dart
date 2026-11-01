import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/settings/settings_view.dart';
import 'package:komodo_go/core/connections/connection_profile.dart';
import 'package:komodo_go/core/platform/vertical_bar_info.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/router/split_aware_page.dart';
import 'package:komodo_go/core/storage/secure_storage_service.dart';
import 'package:komodo_go/core/ui/breakpoints.dart';
import 'package:komodo_go/core/widgets/layout/list_detail_layout.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/auth/data/models/auth_state.dart';
import 'package:komodo_go/features/auth/presentation/providers/auth_provider.dart';
import 'package:komodo_go/features/notifications/presentation/providers/alerts_provider.dart';
import 'package:komodo_go/features/notifications/presentation/providers/notifications_tab_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubAlerts extends Alerts {
  @override
  Future<AlertsState> build() => Completer<AlertsState>().future;
}

class _List extends StatelessWidget {
  const _List({this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MainAppBar(title: 'Items'),
      body: ListView(
        children: [
          for (final id in const ['1', '2'])
            SelectionHighlight(
              selected: selectedId == id,
              child: Material(
                child: ListTile(
                  title: Text('item $id'),
                  onTap: () => context.openDetail('/res/$id'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Detail extends StatefulWidget {
  const _Detail({required this.id});

  final String id;

  @override
  State<_Detail> createState() => _DetailState();
}

class _DetailState extends State<_Detail> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MainAppBar(title: 'Detail ${widget.id}'),
      body: TextButton(
        onPressed: () => setState(() => _count++),
        child: Text('count $_count'),
      ),
    );
  }
}

GoRouter _router() => GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => MainShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const Text('home page')),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/res',
              pageBuilder: (context, state) => const NoTransitionPage<void>(
                child: ListDetailLayout(
                  list: _List(),
                ),
              ),
              routes: [
                GoRoute(
                  path: ':id',
                  pageBuilder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return SplitAwarePage(
                      key: state.pageKey,
                      child: ListDetailLayout(
                        list: _List(selectedId: id),
                        detail: _Detail(id: id),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        for (final path in const ['/c', '/n', '/s'])
          StatefulShellBranch(
            routes: [
              GoRoute(path: path, builder: (_, _) => Text('page $path')),
            ],
          ),
      ],
    ),
  ],
);

Future<GoRouter> _pump(
  WidgetTester tester,
  Size size, {
  VerticalBarInfo? bar,
}) async {
  final router = _router();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [alertsProvider.overrideWith(_StubAlerts.new)],
      child: MaterialApp.router(
        routerConfig: router,
        // Mirrors the root of KomodoApp.
        builder: (context, child) => VerticalBarScope(
          info: bar,
          child: Builder(
            builder: (context) {
              final strip = verticalBarSides(context);
              return SafeArea(
                top: false,
                bottom: false,
                left: !strip.left,
                right: !strip.right,
                child: child!,
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

void main() {
  const outer = Size(466, 678);
  const inner = Size(951, 669);

  test('WindowSizeClass thresholds', () {
    expect(WindowSizeClass.fromWidth(599), WindowSizeClass.compact);
    expect(WindowSizeClass.fromWidth(600), WindowSizeClass.medium);
    expect(WindowSizeClass.fromWidth(839), WindowSizeClass.medium);
    expect(WindowSizeClass.fromWidth(840), WindowSizeClass.expanded);
  });

  testWidgets('compact shows the bottom bar, wide shows the rail', (
    tester,
  ) async {
    await _pump(tester, outer);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await _resize(tester, inner);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isFalse,
    );

    await _resize(tester, const Size(1366, 1024));
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isTrue,
    );

    await _resize(tester, outer);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('rail keeps destination keys and selection behaviour', (
    tester,
  ) async {
    await _pump(tester, inner);
    expect(find.text('home page'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bottom_nav_resources')).first);
    await tester.pumpAndSettle();
    expect(find.text('item 1'), findsOneWidget);
    expect(find.text('Select an item'), findsOneWidget);
  });

  testWidgets('selected detail, branch and state survive fold/unfold', (
    tester,
  ) async {
    await _pump(tester, outer);
    await tester.tap(find.byKey(const ValueKey('bottom_nav_resources')));
    await tester.pumpAndSettle();
    // Compact: one pane (the list).
    expect(find.text('item 1'), findsOneWidget);
    expect(find.text('Select an item'), findsNothing);

    await tester.tap(find.text('item 1'));
    await tester.pumpAndSettle();
    // Compact: only the detail is visible.
    expect(find.text('Detail 1'), findsOneWidget);
    expect(find.text('item 1'), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);

    await tester.tap(find.text('count 0'));
    await tester.pump();
    expect(find.text('count 1'), findsOneWidget);

    // Unfold: list and detail side by side, detail state preserved.
    await _resize(tester, inner);
    expect(find.text('item 1'), findsOneWidget);
    expect(find.text('Detail 1'), findsOneWidget);
    expect(find.text('count 1'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    // Selecting another item replaces the detail in place.
    await tester.tap(find.text('item 2'));
    await tester.pumpAndSettle();
    expect(find.text('Detail 2'), findsOneWidget);
    expect(find.text('Detail 1'), findsNothing);

    // Fold again: only the detail, still the same branch and route.
    await _resize(tester, outer);
    expect(find.text('Detail 2'), findsOneWidget);
    expect(find.text('item 1'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);

    // Back returns to the list, not to a previous detail.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('item 1'), findsOneWidget);
    expect(find.text('Detail 2'), findsNothing);
  });

  testWidgets('closing the split detail pane shows the placeholder', (
    tester,
  ) async {
    await _pump(tester, inner);
    await tester.tap(find.byKey(const ValueKey('bottom_nav_resources')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('item 1'));
    await tester.pumpAndSettle();
    expect(find.text('Detail 1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Detail 1'), findsNothing);
    expect(find.text('Select an item'), findsOneWidget);
  });

  testWidgets('cross-branch go lands on the split with the item selected', (
    tester,
  ) async {
    final router = await _pump(tester, inner);
    expect(find.text('home page'), findsOneWidget);

    router.go('/res/2');
    await tester.pumpAndSettle();
    expect(find.text('Detail 2'), findsOneWidget);
    expect(find.text('item 1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Select an item'), findsOneWidget);
  });

  testWidgets('split is disabled by the screen without losing list state', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = inner;
    addTearDown(tester.view.reset);
    final enabled = ValueNotifier(false);
    addTearDown(enabled.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: enabled,
          builder: (context, value, _) => ListDetailLayout(
            list: const _Detail(id: 'list'),
            splitEnabled: value,
            singlePaneMaxWidth: 500,
          ),
        ),
      ),
    );
    await tester.tap(find.text('count 0'));
    await tester.pump();
    expect(find.text('Select an item'), findsNothing);
    expect(tester.getSize(find.byType(Scaffold)).width, 500);

    enabled.value = true;
    await tester.pumpAndSettle();
    expect(find.text('Select an item'), findsOneWidget);
    expect(find.text('count 1'), findsOneWidget);
    expect(
      tester.getSize(find.byType(Scaffold).first).width,
      closeTo(380.4, 0.1),
    );
  });

  test('notifications tab provider defaults to alerts', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(notificationsTabIndexProvider), 0);
    container.read(notificationsTabIndexProvider.notifier).index = 1;
    expect(container.read(notificationsTabIndexProvider), 1);
  });

  for (final width in [320.0, 380.0]) {
    testWidgets('settings index renders at ${width}pt without exceptions', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.reset);
      final profile = ConnectionProfile(
        id: 'c1',
        name: 'Production',
        baseUrl: 'https://komodo.example.com',
        createdAt: DateTime(2026),
        lastUsedAt: DateTime(2026),
      );
      const credentials = ApiCredentials(
        baseUrl: 'https://komodo.example.com',
        apiKey: 'key',
        apiSecret: 'secret',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              () => _TestAuth(
                AuthState.authenticated(
                  connection: profile,
                  credentials: credentials,
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: SettingsView()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Connections'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  group('vertical bar strip', () {
    const bar = VerticalBarInfo(
      edge: VerticalBarEdge.trailing,
      occludedRegions: [Rect.fromLTWH(867, 0, 84, 100)],
    );

    void inset(WidgetTester tester) {
      tester.view.padding = const FakeViewPadding(right: 84, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(right: 84, bottom: 34);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
    }

    testWidgets('rail moves into the trailing strip below the camera', (
      tester,
    ) async {
      inset(tester);
      await _pump(tester, inner, bar: bar);
      final rail = find.byType(NavigationRail);
      expect(tester.getTopLeft(rail).dx, 867);
      expect(tester.getSize(rail).width, 84);
      expect(tester.getTopLeft(find.text('home page')).dx, lessThan(867));
      expect(
        tester.getTopLeft(find.byType(NavigationRail)).dy,
        greaterThanOrEqualTo(100),
      );
      // First destination starts below the occluded region.
      final first = tester.getTopLeft(
        find.byKey(const ValueKey('bottom_nav_home')).first,
      );
      expect(first.dy, greaterThanOrEqualTo(100));
      // Nothing is left of the content and selection still works.
      await tester.tap(
        find.byKey(const ValueKey('bottom_nav_resources')).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('item 1'), findsOneWidget);
      expect(tester.getTopLeft(find.text('item 1')).dx, lessThan(300));
    });

    testWidgets('without info the rail stays on the left', (tester) async {
      inset(tester);
      await _pump(tester, inner);
      expect(tester.getTopLeft(find.byType(NavigationRail)).dx, 0);
    });

    testWidgets('state survives fold with a strip', (tester) async {
      inset(tester);
      await _pump(tester, inner, bar: bar);
      await tester.tap(
        find.byKey(const ValueKey('bottom_nav_resources')).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('item 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('count 0'));
      await tester.pump();
      // Folded: the strip keeps the rail, no bottom bar.
      await _resize(tester, outer);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('count 1'), findsOneWidget);
      await _resize(tester, inner);
      expect(tester.getTopLeft(find.byType(NavigationRail)).dx, 867);
      expect(find.text('count 1'), findsOneWidget);
    });

    testWidgets('compact trailing strip: rail at 466x678 R84', (tester) async {
      inset(tester);
      await _pump(
        tester,
        outer,
        bar: const VerticalBarInfo(
          edge: VerticalBarEdge.trailing,
          occludedRegions: [Rect.fromLTWH(382, 0, 84, 90)],
        ),
      );
      expect(find.byType(NavigationBar), findsNothing);
      final rail = find.byType(NavigationRail);
      expect(tester.getTopLeft(rail).dx, 382);
      expect(tester.getSize(rail).width, 84);
      // All five destinations are reachable (rail scrolls if needed).
      await tester.tap(
        find.byKey(const ValueKey('bottom_nav_resources')).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('item 1'), findsOneWidget);
      expect(tester.getTopLeft(find.text('item 1')).dx, lessThan(382));
    });

    testWidgets('content reaches the bottom edge in strip mode', (
      tester,
    ) async {
      inset(tester);
      await _pump(
        tester,
        outer,
        bar: const VerticalBarInfo(
          edge: VerticalBarEdge.trailing,
          occludedRegions: [Rect.fromLTWH(382, 0, 84, 90)],
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('bottom_nav_resources')).first,
      );
      await tester.pumpAndSettle();
      // The scroll view runs to the physical edge (no padded band); the inset
      // stays available to it via MediaQuery.
      expect(tester.getBottomLeft(find.byType(ListView)).dy, outer.height);
      expect(
        MediaQuery.paddingOf(tester.element(find.byType(ListView))).bottom,
        34,
      );
    });

    testWidgets('leading strip: rail at 678x466 L84', (tester) async {
      tester.view.padding = const FakeViewPadding(left: 84, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(left: 84, bottom: 34);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      await _pump(
        tester,
        const Size(678, 466),
        bar: const VerticalBarInfo(
          edge: VerticalBarEdge.leading,
          occludedRegions: [Rect.fromLTWH(0, 0, 84, 90)],
        ),
      );
      expect(find.byType(NavigationBar), findsNothing);
      final rail = find.byType(NavigationRail);
      expect(tester.getTopLeft(rail).dx, 0);
      expect(tester.getSize(rail).width, 84);
      expect(
        tester.getTopLeft(find.text('home page')).dx,
        greaterThanOrEqualTo(84),
      );
      // Short display: every destination stays reachable.
      for (final key in const [
        'bottom_nav_home',
        'bottom_nav_resources',
        'bottom_nav_containers',
        'bottom_nav_notifications',
        'bottom_nav_settings',
      ]) {
        expect(find.byKey(ValueKey(key)), findsWidgets);
      }
    });

    testWidgets('without strip info compact shows the bottom bar', (
      tester,
    ) async {
      inset(tester);
      await _pump(tester, outer);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });
  });
}

class _TestAuth extends Auth {
  _TestAuth(this.initialState);

  final AuthState initialState;

  @override
  Future<AuthState> build() async => initialState;
}
