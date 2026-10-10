import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/shared/logs/server_log.dart';
import 'package:komodo_go/shared/logs/server_log_explorer.dart';
import 'package:komodo_go/shared/logs/widgets/server_log_viewer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<List<ServerLogRequest>> pumpExplorer(WidgetTester tester) async {
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
                  stdout: request.isSearch
                      ? 'an error line\nanother error'
                      : 'recent line',
                  success: true,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return requests;
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(
      find.byKey(const ValueKey('server_log_search')),
      text,
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  Future<void> openFilters(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('server_log_filters')));
    await tester.pumpAndSettle();
  }

  testWidgets('searches on submit and highlights matches', (tester) async {
    final requests = await pumpExplorer(tester);
    expect(find.textContaining('recent line', findRichText: true), findsOne);
    expect(find.text('1 line', findRichText: true), findsNothing);

    await search(tester, 'error, timeout');

    expect(requests.last.terms, ['error', 'timeout']);
    expect(requests.last.combinator, LogSearchCombinator.and);
    expect(find.textContaining('an error line', findRichText: true), findsOne);
    expect(find.textContaining('2 lines'), findsOneWidget);
  });

  testWidgets('filter sheet changes apply and show as resettable chips', (
    tester,
  ) async {
    final requests = await pumpExplorer(tester);
    await search(tester, 'error');

    await openFilters(tester);
    await tester.tap(find.text('Any term'));
    await tester.pumpAndSettle();
    expect(requests.last.combinator, LogSearchCombinator.or);
    await tester.tap(find.text('500'));
    await tester.pumpAndSettle();
    expect(requests.last.tail, 500);

    Navigator.of(tester.element(find.text('Log filters'))).pop();
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputChip, 'Any term'), findsOneWidget);
    expect(find.widgetWithText(InputChip, '500 lines'), findsOneWidget);

    await tester.tap(find.widgetWithText(InputChip, '500 lines'));
    await tester.pumpAndSettle();
    expect(requests.last.tail, 200);
    expect(find.widgetWithText(InputChip, '500 lines'), findsNothing);
  });

  testWidgets('saves, applies and deletes saved filters', (tester) async {
    final requests = await pumpExplorer(tester);
    await search(tester, 'error');

    await openFilters(tester);
    await tester.tap(find.byKey(const ValueKey('server_log_save_filter')));
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

    Navigator.of(tester.element(find.text('Log filters'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(requests.last.isSearch, isFalse);

    await openFilters(tester);
    await tester.tap(find.text('Failures'));
    await tester.pumpAndSettle();
    expect(requests.last.terms, ['error']);

    await openFilters(tester);
    await tester.drag(find.text('Failures'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Failures'), findsNothing);
    expect(
      prefs.getString('komodo.saved_log_filters.v1'),
      isNot(contains('Failures')),
    );
  });

  testWidgets('opens full screen with shared state', (tester) async {
    await pumpExplorer(tester);
    await search(tester, 'error');

    await tester.ensureVisible(find.byKey(const ValueKey('server_log_expand')));
    await tester.tap(find.byKey(const ValueKey('server_log_expand')));
    await tester.pumpAndSettle();

    final fields = find.byKey(const ValueKey('server_log_search'));
    // The inline explorer is offstage behind the route; only one is visible.
    expect(find.byType(BackButton), findsNothing);
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(tester.widget<TextField>(fields).controller?.text, 'error');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(fields, findsOneWidget);
  });

  testWidgets('fits phone width without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpExplorer(tester);
    await search(tester, 'error');
    await openFilters(tester);
    expect(tester.takeException(), isNull);
  });

  test('highlightLogTerms marks case-insensitive matches', () {
    const style = TextStyle(fontWeight: FontWeight.bold);
    final spans = highlightLogTerms('Error: timeout ERROR', [
      'error',
      'timeout',
    ], style);
    expect(spans.map((span) => span.text), [
      'Error',
      ': ',
      'timeout',
      ' ',
      'ERROR',
    ]);
    expect(spans.where((span) => span.style == style), hasLength(3));
    expect(highlightLogTerms('plain', const [], style), hasLength(1));
  });
}
