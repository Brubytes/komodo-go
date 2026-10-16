import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/theme/app_theme.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';

void main() {
  Widget host({required double width, required double scale, Widget? child}) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: SingleChildScrollView(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );
  }

  for (final width in [240.0, 360.0, 600.0]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('header fits at width $width and text scale $scale', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(
            width: width,
            scale: scale,
            child: DetailResourceHeader(
              banner: DetailAttentionBanner(
                icon: AppIcons.warning,
                message: 'Repo has new commits',
                actionLabel: 'Deploy',
                onAction: () {},
              ),
              facts: [
                DetailFact(
                  icon: AppIcons.server,
                  label: 'Server',
                  value: 'nas',
                  onTap: () {},
                ),
                const DetailFact(
                  icon: AppIcons.package,
                  label: 'Directory',
                  value: '…/stacks/a-very-long-directory-name',
                ),
              ],
              stats: const [
                DetailStat(label: 'Services', value: '12'),
                DetailStat(label: 'Image updates', value: '3', progress: 0.4),
                DetailStat(label: 'Missing', value: '0'),
              ],
              tags: const ['bulk-update'],
              description: 'NAS services',
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('linked fact runs onTap; plain fact opens full value', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      host(
        width: 360,
        scale: 1,
        child: DetailResourceHeader(
          facts: [
            DetailFact(
              icon: AppIcons.server,
              label: 'Server',
              value: 'nas',
              onTap: () => tapped = true,
            ),
            const DetailFact(
              icon: AppIcons.package,
              label: 'Directory',
              value: '…/bento-pdf',
              fullValue: '/srv/stacks/bento-pdf',
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('nas'));
    expect(tapped, isTrue);

    await tester.tap(find.text('…/bento-pdf'));
    await tester.pumpAndSettle();
    expect(find.text('/srv/stacks/bento-pdf'), findsOneWidget);
  });

  testWidgets('empty header renders nothing but tags', (tester) async {
    await tester.pumpWidget(
      host(
        width: 360,
        scale: 1,
        child: const DetailResourceHeader(tags: ['prod']),
      ),
    );
    expect(find.byType(Divider), findsNothing);
    expect(find.text('prod'), findsOneWidget);
  });
}
