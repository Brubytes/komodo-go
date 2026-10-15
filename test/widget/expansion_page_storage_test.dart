import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression: an ExpansionTile without its own PageStorageKey computes the
/// same PageStorage identifier as an ancestor scrollable keyed with a
/// PageStorageKey, so initState read a scroll offset (double) as bool?.
void main() {
  Widget app({required bool keyed, required bool showTab}) {
    return MaterialApp(
      home: PageStorage(
        bucket: _bucket,
        child: Scaffold(
          body: showTab
              ? ListView(
                  key: const PageStorageKey<String>('inspect'),
                  children: [
                    for (var i = 0; i < 40; i++) Text('row $i'),
                    ExpansionTile(
                      key: keyed
                          ? const PageStorageKey<String>('raw_expanded')
                          : null,
                      title: const Text('Raw'),
                      children: const [Text('body')],
                    ),
                  ],
                )
              : const SizedBox(),
        ),
      ),
    );
  }

  Future<void> run(WidgetTester tester, {required bool keyed}) async {
    await tester.pumpWidget(app(keyed: keyed, showTab: true));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
    await tester.pumpWidget(app(keyed: keyed, showTab: false));
    await tester.pumpWidget(app(keyed: keyed, showTab: true));
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pump();
  }

  setUp(() => _bucket = PageStorageBucket());

  testWidgets('keyed ExpansionTile survives tab switches', (tester) async {
    await run(tester, keyed: true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unkeyed ExpansionTile collides (documents the bug)', (
    tester,
  ) async {
    await run(tester, keyed: false);
    expect(tester.takeException(), isNotNull);
  });
}

PageStorageBucket _bucket = PageStorageBucket();
