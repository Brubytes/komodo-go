import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/router/split_aware_page.dart';
import 'package:komodo_go/features/notifications/data/models/alert.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';
import 'package:komodo_go/features/notifications/presentation/providers/alerts_provider.dart';
import 'package:komodo_go/features/notifications/presentation/providers/updates_provider.dart';

class _Alerts extends Alerts {
  @override
  Future<AlertsState> build() async => AlertsState(
    items: [
      Alert.fromJson({
        'id': 'a1',
        'ts': 1700000000000,
        'resolved': false,
        'level': 'Warning',
        'target': {'Server': 's1'},
        'data': {
          'type': 'ServerUnreachable',
          'data': {'server_name': 'Staging Node'},
        },
      }),
      Alert.fromJson({
        'id': 'a2',
        'ts': 1700000100000,
        'resolved': true,
        'level': 'Ok',
        'data': {
          'type': 'Custom',
          'data': {'message': 'No destination'},
        },
      }),
    ],
    nextPage: null,
  );
}

class _Updates extends Updates {
  @override
  Future<UpdatesState> build() async =>
      const UpdatesState(items: <UpdateListItem>[], nextPage: null);
}

GoRouter _router(String initial) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(
      path: '/notifications',
      builder: (_, _) => const NotificationsPane(),
      routes: [
        GoRoute(
          path: 'alerts/:id',
          pageBuilder: (_, state) => SplitAwarePage(
            key: state.pageKey,
            child: NotificationsPane(alertId: state.pathParameters['id']),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/resources/servers/:id',
      builder: (_, state) => Text('server ${state.pathParameters['id']}'),
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  Size size, {
  String initial = '/notifications',
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        alertsProvider.overrideWith(_Alerts.new),
        updatesProvider.overrideWith(_Updates.new),
      ],
      child: MaterialApp.router(routerConfig: _router(initial)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const inner = Size(951, 669);
  const outer = Size(466, 678);

  testWidgets('split: alert opens in the detail pane with an action', (
    tester,
  ) async {
    await _pump(tester, inner);
    expect(find.text('Select an alert'), findsOneWidget);

    await tester.tap(find.text('Server Unreachable'));
    await tester.pumpAndSettle();
    expect(find.text('Alert details'), findsOneWidget);
    // The list stays beside the detail.
    expect(find.text('Server Unreachable'), findsWidgets);
    expect(find.byKey(const ValueKey('alert_open_target')), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('alert_open_target')));
    await tester.pumpAndSettle();
    expect(find.text('server s1'), findsOneWidget);
  });

  testWidgets('split: alert without destination has no action button', (
    tester,
  ) async {
    await _pump(tester, inner);
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(find.text('Alert details'), findsOneWidget);
    expect(find.byKey(const ValueKey('alert_open_target')), findsNothing);
  });

  testWidgets('tab switch keeps the split and follows the placeholder', (
    tester,
  ) async {
    await _pump(tester, inner);
    expect(find.text('Select an alert'), findsOneWidget);
    await tester.tap(find.text('Updates'));
    await tester.pumpAndSettle();
    expect(find.text('Select an update'), findsOneWidget);
    expect(find.text('Select an alert'), findsNothing);
  });

  testWidgets("switching tabs closes the other tab's detail", (tester) async {
    await _pump(tester, inner);
    await tester.tap(find.text('Server Unreachable'));
    await tester.pumpAndSettle();
    expect(find.text('Alert details'), findsOneWidget);

    await tester.tap(find.text('Updates'));
    await tester.pumpAndSettle();
    expect(find.text('Alert details'), findsNothing);
    expect(find.text('Select an update'), findsOneWidget);
  });

  testWidgets('narrow: alert tap goes straight to the target', (tester) async {
    await _pump(tester, outer);
    await tester.tap(find.text('Server Unreachable'));
    await tester.pumpAndSettle();
    expect(find.text('server s1'), findsOneWidget);
    expect(find.text('Alert details'), findsNothing);
  });

  testWidgets('narrow: an open alert page renders as a full page', (
    tester,
  ) async {
    await _pump(tester, outer, initial: '/notifications/alerts/a1');
    expect(find.text('Alert details'), findsOneWidget);
    expect(find.byKey(const ValueKey('alert_open_target')), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('unknown alert id shows an empty state', (tester) async {
    await _pump(tester, inner, initial: '/notifications/alerts/gone');
    expect(find.text('Alert not found'), findsOneWidget);
  });
}
