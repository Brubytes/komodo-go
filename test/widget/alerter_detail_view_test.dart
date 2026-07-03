import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/features/alerters/data/models/alerter.dart';
import 'package:komodo_go/features/alerters/presentation/providers/alerters_provider.dart';
import 'package:komodo_go/features/alerters/presentation/views/alerter_detail_view.dart';

void main() {
  testWidgets('detail reload does not clobber unsaved edits', (tester) async {
    var detail = const AlerterDetail(
      id: 'a1',
      name: 'alerts',
      updatedAt: '1',
      config: AlerterConfig(
        enabled: true,
        endpoint: AlerterEndpoint(type: 'Slack', url: 'https://old.example'),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alerterDetailProvider('a1').overrideWith((ref) async => detail),
        ],
        child: const MaterialApp(
          home: AlerterDetailView(alerterIdOrName: 'a1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder editableWithText(String text) => find.byWidgetPredicate(
      (widget) => widget is EditableText && widget.controller.text == text,
    );

    await tester.enterText(
      editableWithText('https://old.example'),
      'https://mine.example',
    );
    await tester.pumpAndSettle();

    // A reload with a new updatedAt arrives (e.g. background refresh or a
    // partially failed save) while the user's edits are unsaved.
    detail = const AlerterDetail(
      id: 'a1',
      name: 'alerts',
      updatedAt: '2',
      config: AlerterConfig(
        enabled: true,
        endpoint: AlerterEndpoint(type: 'Slack', url: 'https://server.example'),
      ),
    );
    ProviderScope.containerOf(
      tester.element(find.byType(AlerterDetailView)),
    ).invalidate(alerterDetailProvider('a1'));
    await tester.pumpAndSettle();

    expect(editableWithText('https://mine.example'), findsOneWidget);
    expect(editableWithText('https://server.example'), findsNothing);
  });
}
