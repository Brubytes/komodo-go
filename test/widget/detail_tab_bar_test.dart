import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/widgets/detail/detail_tab_bar.dart';

class _Host extends StatelessWidget {
  const _Host({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: labels.length,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            toolbarHeight: 0,
            bottom: buildDetailTabBar(
              context: context,
              controller: DefaultTabController.of(context),
              tabs: [
                for (final label in labels)
                  Tab(icon: const Icon(Icons.layers), text: label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  const labels = ['Services', 'Config', 'Updates', 'Logs'];

  for (final width in [320.0, 360.0, 402.0, 600.0]) {
    testWidgets('4 tabs at ${width.toInt()}pt never overflow', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: _Host(labels: labels)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      for (final label in labels) {
        expect(find.text(label), findsOneWidget);
      }
    });
  }

  testWidgets('wide screens keep icons inline', (tester) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: _Host(labels: labels)));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.layers), findsNWidgets(4));
  });
}
