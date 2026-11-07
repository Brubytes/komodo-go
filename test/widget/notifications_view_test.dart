import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/features/notifications/data/models/alert.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';
import 'package:komodo_go/features/notifications/presentation/providers/alerts_provider.dart';
import 'package:komodo_go/features/notifications/presentation/providers/updates_provider.dart';
import 'package:komodo_go/features/notifications/presentation/views/notifications_view.dart';

class _TestAlertsSuccess extends Alerts {
  _TestAlertsSuccess(this._state);

  final AlertsState _state;

  @override
  Future<AlertsState> build() async => _state;
}

class _TestAlertsError extends Alerts {
  @override
  Future<AlertsState> build() async => throw Exception('permission denied');
}

/// Loads once, then fails on every rebuild (a failing refresh).
class _TestAlertsFailsOnRefresh extends Alerts {
  var _calls = 0;

  @override
  Future<AlertsState> build() async {
    if (_calls++ == 0) {
      return const AlertsState(items: <Alert>[], nextPage: null);
    }
    throw Exception('network down');
  }
}

class _TestUpdates extends Updates {
  _TestUpdates(this._state);

  final UpdatesState _state;

  @override
  Future<UpdatesState> build() async => _state;
}

void main() {
  testWidgets('keeps Alerts as default tab when alerts load', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alertsProvider.overrideWith(
            () => _TestAlertsSuccess(
              const AlertsState(items: <Alert>[], nextPage: null),
            ),
          ),
          updatesProvider.overrideWith(
            () => _TestUpdates(
              const UpdatesState(items: <UpdateListItem>[], nextPage: null),
            ),
          ),
        ],
        child: const MaterialApp(home: NotificationsView()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No alerts'), findsOneWidget);
    expect(find.text('No updates'), findsNothing);
  });

  testWidgets('switches to Updates when alerts fail to load', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alertsProvider.overrideWith(_TestAlertsError.new),
          updatesProvider.overrideWith(
            () => _TestUpdates(
              const UpdatesState(items: <UpdateListItem>[], nextPage: null),
            ),
          ),
        ],
        child: const MaterialApp(home: NotificationsView()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No updates'), findsOneWidget);
    expect(find.text('No alerts'), findsNothing);
  });

  testWidgets('stays on Alerts and keeps data when a refresh fails', (
    tester,
  ) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alertsProvider.overrideWith(_TestAlertsFailsOnRefresh.new),
          updatesProvider.overrideWith(
            () => _TestUpdates(
              const UpdatesState(items: <UpdateListItem>[], nextPage: null),
            ),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const MaterialApp(home: NotificationsView());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No alerts'), findsOneWidget);

    container.invalidate(alertsProvider);
    await tester.pumpAndSettle();

    expect(find.text('No alerts'), findsOneWidget);
    expect(find.text('No updates'), findsNothing);
    expect(find.textContaining("Couldn't refresh"), findsOneWidget);
  });
}
