import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/settings/presentation/views/credits_view.dart';

void main() {
  testWidgets('Logo follows theme changes', (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const CreditsView(),
        ),
      );
      await tester.pumpAndSettle();

      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as AssetImage).assetName,
        brightness == Brightness.dark
            ? 'assets/komodo-go-logo_rounded_dark.png'
            : 'assets/komodo-go-logo_rounded.png',
      );
      expect(tester.takeException(), isNull);
    }
  });
}
