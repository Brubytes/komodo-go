import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/theme/app_theme.dart';

void main() {
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    testWidgets('${theme.brightness} preserves button hierarchy', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Column(
              children: [
                FilledButton(onPressed: () {}, child: const Text('Primary')),
                FilledButton.tonal(
                  onPressed: () {},
                  child: const Text('Secondary'),
                ),
                const FilledButton(onPressed: null, child: Text('Disabled')),
              ],
            ),
          ),
        ),
      );

      Color? surfaceFor(String label) => tester
          .widget<Material>(
            find
                .ancestor(
                  of: find.text(label),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color;

      expect(surfaceFor('Primary'), theme.colorScheme.primary);
      expect(surfaceFor('Secondary'), theme.colorScheme.secondaryContainer);
      expect(surfaceFor('Disabled'), isNot(surfaceFor('Primary')));
    });
  }
}
