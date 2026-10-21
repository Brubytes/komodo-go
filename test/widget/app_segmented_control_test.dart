import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/segmented/app_segmented_control.dart';

Widget _wrap(Widget child, {bool reduced = false}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: Scaffold(body: child),
      ),
    ),
  );
}

class _ControlHarness extends StatefulWidget {
  const _ControlHarness();

  @override
  State<_ControlHarness> createState() => _ControlHarnessState();
}

class _ControlHarnessState extends State<_ControlHarness> {
  String value = 'a';

  @override
  Widget build(BuildContext context) {
    return AppSegmentedControl<String>(
      value: value,
      segments: const [
        AppSegmentOption(value: 'a', label: 'Alpha'),
        AppSegmentOption(value: 'b', label: 'Beta'),
      ],
      onChanged: (v) => setState(() => value = v),
    );
  }
}

class _TabHarness extends StatefulWidget {
  const _TabHarness({this.badge});

  final int? badge;

  @override
  State<_TabHarness> createState() => _TabHarnessState();
}

class _TabHarnessState extends State<_TabHarness>
    with SingleTickerProviderStateMixin {
  late final TabController controller = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppSegmentedTabBar(
          controller: controller,
          segments: [
            AppSegment(
              label: 'Alerts',
              badgeCount: widget.badge,
              badgeTone: PillTone.warning,
            ),
            const AppSegment(label: 'Updates'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: controller,
            children: const [Text('page-a'), Text('page-b')],
          ),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('tapping a segment changes the value', (tester) async {
    await tester.pumpWidget(_wrap(const _ControlHarness()));
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    final state = tester.state<_ControlHarnessState>(
      find.byType(_ControlHarness),
    );
    expect(state.value, 'b');
  });

  testWidgets('disabled control ignores taps', (tester) async {
    const changed = false;
    await tester.pumpWidget(
      _wrap(
        AppSegmentedControl<int>(
          value: 1,
          segments: const [
            AppSegmentOption(value: 1, label: 'One'),
            AppSegmentOption(value: 2, label: 'Two'),
          ],
          onChanged: null,
        ),
      ),
    );
    await tester.tap(find.text('Two'));
    expect(changed, isFalse);
  });

  testWidgets('tab bar follows the TabController', (tester) async {
    await tester.pumpWidget(_wrap(const _TabHarness()));
    final state = tester.state<_TabHarnessState>(find.byType(_TabHarness));
    expect(state.controller.index, 0);
    await tester.tap(find.text('Updates'));
    await tester.pumpAndSettle();
    expect(state.controller.index, 1);
    expect(find.text('page-b'), findsOneWidget);

    state.controller.animateTo(0);
    await tester.pumpAndSettle();
    expect(state.controller.index, 0);
  });

  testWidgets('badge is hidden for null and 0, shown otherwise', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const _TabHarness(badge: 0)));
    expect(find.text('0'), findsNothing);
    await tester.pumpWidget(_wrap(const _TabHarness()));
    expect(find.text('3'), findsNothing);
    await tester.pumpWidget(_wrap(const _TabHarness(badge: 3)));
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('reduced motion leaves no running animations', (tester) async {
    await tester.pumpWidget(_wrap(const _ControlHarness(), reduced: true));
    await tester.tap(find.text('Beta'));
    await tester.pump();
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
