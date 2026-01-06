import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/app.dart';

void main() {
  testWidgets('App renders without error', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KomodoApp(),
      ),
    );

    // Allow the app to settle
    await tester.pump();

    // Verify the app renders
    expect(find.byType(KomodoApp), findsOneWidget);
  });
}
