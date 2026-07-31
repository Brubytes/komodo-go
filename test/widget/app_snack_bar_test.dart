import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';

void main() {
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return hostContext;
  }

  testWidgets('snackbar auto-dismisses after the default duration', (
    tester,
  ) async {
    final context = await pumpHost(tester);

    AppSnackBar.show(context, 'hello');
    await tester.pump();
    expect(find.text('hello'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('hello'), findsNothing);
  });

  testWidgets(
    'second snackbar shown while the first is visible still auto-dismisses',
    (tester) async {
      final context = await pumpHost(tester);

      AppSnackBar.show(context, 'first');
      await tester.pump();
      expect(find.text('first'), findsOneWidget);

      AppSnackBar.show(context, 'second');
      // Let the first snackbar finish its exit animation so its `closed`
      // future completes while the second is on screen.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('second'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('second'), findsNothing);
    },
  );
}
