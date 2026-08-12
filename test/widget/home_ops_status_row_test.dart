import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/composition/home/home_ops_pulse.dart';
import 'package:komodo_go/composition/home/widgets/home_sections.dart';

void main() {
  testWidgets('shows compact non-zero status distribution at phone width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeOpsStatusRow(
            title: 'Stacks',
            statuses: const [
              HomeOpsStatusCount(
                label: 'Running',
                count: 23,
                tone: HomeOpsTone.healthy,
              ),
              HomeOpsStatusCount(
                label: 'Stopped',
                count: 1,
                tone: HomeOpsTone.attention,
              ),
              HomeOpsStatusCount(
                label: 'Unhealthy',
                count: 0,
                tone: HomeOpsTone.failed,
              ),
              HomeOpsStatusCount(
                label: 'Unknown',
                count: 0,
                tone: HomeOpsTone.unknown,
              ),
            ],
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Stacks'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    expect(find.text('23 running'), findsOneWidget);
    expect(find.text('1 stopped'), findsOneWidget);
    expect(find.textContaining('unhealthy'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Stacks'));
    expect(tapped, isTrue);
  });
}
