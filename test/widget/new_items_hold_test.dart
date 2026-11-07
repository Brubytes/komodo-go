import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/stacks/stack_updates_provider.dart';
import 'package:komodo_go/composition/stacks/stack_updates_tab.dart';
import 'package:komodo_go/core/widgets/scroll/new_items_hold.dart';
import 'package:komodo_go/features/notifications/data/models/alert.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';
import 'package:komodo_go/features/notifications/presentation/providers/alerts_provider.dart';
import 'package:komodo_go/features/notifications/presentation/providers/updates_provider.dart';
import 'package:komodo_go/features/notifications/presentation/views/notifications/notifications_sections.dart';

UpdateListItem _update(int n) => UpdateListItem.fromJson({
  'id': 'u$n',
  'operation': 'RunBuild',
  'start_ts': 1700000000000 + n,
  'success': true,
  'username': 'user',
  'operator': 'op',
  'status': 'Complete',
  'version': {'major': 0, 'minor': 0, 'patch': 0},
  'other_data': '',
});

Alert _alert(int n) => Alert.fromJson({
  'id': 'a$n',
  'ts': 1700000000000 + n,
  'resolved': false,
  'level': 'Warning',
  'data': {
    'type': 'ServerUnreachable',
    'data': {'server_name': 'node-$n'},
  },
});

/// Newest first: ids u(count) .. u1.
List<UpdateListItem> _updates(int count) => [
  for (var n = count; n >= 1; n--) _update(n),
];

List<Alert> _alerts(int count) => [
  for (var n = count; n >= 1; n--) _alert(n),
];

class _Updates extends Updates {
  _Updates(this.initial);

  final List<UpdateListItem> initial;

  @override
  Future<UpdatesState> build() async =>
      UpdatesState(items: initial, nextPage: null);

  void setItems(List<UpdateListItem> items) =>
      state = AsyncData(UpdatesState(items: items, nextPage: null));
}

class _Alerts extends Alerts {
  _Alerts(this.initial);

  final List<Alert> initial;

  @override
  Future<AlertsState> build() async =>
      AlertsState(items: initial, nextPage: null);

  void setItems(List<Alert> items) =>
      state = AsyncData(AlertsState(items: items, nextPage: null));
}

class _StackUpdates extends StackUpdates {
  _StackUpdates(this.initial);

  final List<UpdateListItem> initial;

  @override
  Future<UpdatesState> build(String stackId) async =>
      UpdatesState(items: initial, nextPage: null);

  void setItems(List<UpdateListItem> items) =>
      state = AsyncData(UpdatesState(items: items, nextPage: null));
}

Widget _host({
  required Widget child,
  List<Override> overrides = const [],
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    home: Scaffold(body: SizedBox(height: 600, child: child)),
  ),
);

void main() {
  testWidgets(
    'updates: prepend while scrolled keeps visible content in place',
    (
      tester,
    ) async {
      final notifier = _Updates(_updates(30));
      await tester.pumpWidget(
        _host(
          overrides: [updatesProvider.overrideWith(() => notifier)],
          child: const UpdatesTab(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await tester.pumpAndSettle();

      // First fully visible tile is whatever sits at the top after scrolling.
      final before =
          find.byType(UpdateTile).evaluate().first.widget as UpdateTile;
      final id = before.update.id;
      final finder = find.byWidgetPredicate(
        (w) => w is UpdateTile && w.update.id == id,
      );
      final topBefore = tester.getTopLeft(finder).dy;

      notifier.setItems([_update(32), _update(31), ...notifier.initial]);
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(finder).dy, topBefore);
      expect(find.byKey(const ValueKey('new_items_pill')), findsOneWidget);
      expect(find.text('2 new updates'), findsOneWidget);

      // Tapping the pill scrolls to the top and reveals the new items.
      await tester.tap(find.byKey(const ValueKey('new_items_pill')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('new_items_pill')), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is UpdateTile && w.update.id == 'u32',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('updates: prepend at the top shows new items immediately', (
    tester,
  ) async {
    final notifier = _Updates(_updates(30));
    await tester.pumpWidget(
      _host(
        overrides: [updatesProvider.overrideWith(() => notifier)],
        child: const UpdatesTab(),
      ),
    );
    await tester.pumpAndSettle();

    notifier.setItems([_update(31), ...notifier.initial]);
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate((w) => w is UpdateTile && w.update.id == 'u31'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('new_items_pill')), findsNothing);
  });

  testWidgets('alerts: prepend while scrolled keeps visible content in place', (
    tester,
  ) async {
    final notifier = _Alerts(_alerts(30));
    await tester.pumpWidget(
      _host(
        overrides: [alertsProvider.overrideWith(() => notifier)],
        child: const AlertsTab(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(
      tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            ),
          )
          .position
          .pixels,
      greaterThan(500),
    );

    final id =
        (find.byType(AlertTile).evaluate().first.widget as AlertTile).alert.id;
    final finder = find.byWidgetPredicate(
      (w) => w is AlertTile && w.alert.id == id,
    );
    final topBefore = tester.getTopLeft(finder).dy;

    notifier.setItems([_alert(31), ...notifier.initial]);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(finder).dy, topBefore);
    expect(find.text('1 new alert'), findsOneWidget);
  });

  testWidgets('stack updates: prepend while scrolled keeps content in place', (
    tester,
  ) async {
    final notifier = _StackUpdates(_updates(30));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stackUpdatesProvider.overrideWith2((stackId) => notifier),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverOverlapAbsorber(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                    context,
                  ),
                  sliver: const SliverAppBar(pinned: true, title: Text('S')),
                ),
              ],
              body: const StackUpdatesTab(stackId: 'stack-1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
    await tester.pumpAndSettle();

    final id = (find.byType(UpdateTile).evaluate().first.widget as UpdateTile)
        .update
        .id;
    final finder = find.byWidgetPredicate(
      (w) => w is UpdateTile && w.update.id == id,
    );
    expect(id, isNot('u30'));
    final topBefore = tester.getTopLeft(finder).dy;

    notifier.setItems([_update(31), ...notifier.initial]);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(finder).dy, topBefore);
    expect(find.text('1 new update'), findsOneWidget);
  });

  test('NewItemsHold holds items above the anchor only while scrolled', () {
    final hold = NewItemsHold();
    String idOf(String s) => s;

    expect(hold.apply(['c', 'b', 'a'], idOf, 0), ['c', 'b', 'a']);
    expect(hold.apply(['e', 'd', 'c', 'b', 'a'], idOf, 300), ['c', 'b', 'a']);
    expect(hold.pending, 2);
    // Idempotent.
    expect(hold.apply(['e', 'd', 'c', 'b', 'a'], idOf, 300), ['c', 'b', 'a']);
    // Back at the top: released.
    expect(
      hold.apply(['e', 'd', 'c', 'b', 'a'], idOf, 0),
      ['e', 'd', 'c', 'b', 'a'],
    );
    expect(hold.pending, 0);
    // Anchor vanished (e.g. filter change): reset, nothing held.
    expect(hold.apply(['x', 'y'], idOf, 300), ['x', 'y']);
    expect(hold.pending, 0);
  });
}
