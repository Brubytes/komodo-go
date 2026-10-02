import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/shared/logs/server_log.dart';
import 'package:komodo_go/shared/logs/server_log_explorer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('searches on the server and saves the active filter', (
    tester,
  ) async {
    final requests = <ServerLogRequest>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ServerLogExplorer(
              autoRefresh: false,
              loader: (request) async {
                requests.add(request);
                return ServerLogSnapshot(
                  stdout: request.isSearch ? 'matching line' : 'recent line',
                  success: true,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Search logs'), findsOneWidget);
    expect(find.text('Match all'), findsOneWidget);
    expect(find.text('Options'), findsOneWidget);
    expect(find.byTooltip('How log search works'), findsOneWidget);

    await tester.tap(find.byTooltip('How log search works'));
    await tester.pumpAndSettle();
    expect(find.text('How log search works'), findsOneWidget);
    expect(
      find.text('Separate multiple search terms with commas.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('server_log_search')),
      'error, timeout',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('run_server_log_search')));
    await tester.pumpAndSettle();

    expect(requests.last.terms, ['error', 'timeout']);
    expect(requests.last.combinator, LogSearchCombinator.and);
    expect(find.text('matching line'), findsOneWidget);

    await tester.tap(find.text('Match all'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is CheckedPopupMenuItem<LogSearchCombinator> &&
            widget.value == LogSearchCombinator.or,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('run_server_log_search')));
    await tester.pumpAndSettle();
    expect(requests.last.combinator, LogSearchCombinator.or);

    await tester.tap(find.byTooltip('Save filter'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('saved_log_filter_name')),
      'Failures',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('komodo.saved_log_filters.v1'),
      contains('Failures'),
    );
  });

  testWidgets('keeps secondary guidance hidden at phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ServerLogExplorer(
              autoRefresh: false,
              loader: (_) async => const ServerLogSnapshot(
                stdout: 'recent line',
                success: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Search logs'), findsOneWidget);
    expect(find.byTooltip('How log search works'), findsOneWidget);
    expect(
      find.text('Separate multiple search terms with commas.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
