import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';

void main() {
  testWidgets('long centered titles ellipsize next to actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: SizedBox()),
          ),
          onGenerateInitialRoutes: (navigator, _) => [
            MaterialPageRoute<void>(builder: (_) => const SizedBox()),
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: MainAppBar(
                  title: 'TT Matchday staging deployment action',
                  icon: AppIcons.actions,
                  centerTitle: true,
                  actions: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(AppIcons.edit),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(AppIcons.play),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
