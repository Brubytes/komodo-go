import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/theme/app_theme.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_metric_grid.dart';

void main() {
  for (final width in [240.0, 320.0, 520.0]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('metrics fit at width $width and text scale $scale', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: width,
                    child: const DetailMetricGrid(
                      items: [
                        DetailMetricTileData(
                          icon: AppIcons.server,
                          label: 'Memory',
                          value: '1.8 / 8.0 GB',
                          tone: DetailMetricTone.primary,
                          progress: 0.225,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('1.8 / 8.0 GB'));
        await tester.pumpAndSettle();
        expect(find.byType(SelectableText), findsOneWidget);
      });
    }
  }
}
