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
}
