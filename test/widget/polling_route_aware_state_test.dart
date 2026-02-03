import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/polling_route_aware_state.dart';

class _TestPollingWidget extends ConsumerStatefulWidget {
  const _TestPollingWidget();

  @override
  ConsumerState<_TestPollingWidget> createState() => _TestPollingState();
}

class _TestPollingState extends PollingRouteAwareState<_TestPollingWidget> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  testWidgets('shouldPoll respects visibility and lifecycle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: _TestPollingWidget())),
    );

    final state = tester.state<_TestPollingState>(
      find.byType(_TestPollingWidget),
    );

    void setStateValues({
      required bool isRouteVisible,
      required AppLifecycleState lifecycleState,
    }) {
      state
        ..isRouteVisible = isRouteVisible
        ..lifecycleState = lifecycleState;
    }

    setStateValues(
      isRouteVisible: true,
      lifecycleState: AppLifecycleState.resumed,
    );
    expect(state.shouldPoll(isActiveTab: true), isTrue);

    setStateValues(
      isRouteVisible: false,
      lifecycleState: AppLifecycleState.resumed,
    );
    expect(state.shouldPoll(isActiveTab: true), isFalse);

    setStateValues(
      isRouteVisible: true,
      lifecycleState: AppLifecycleState.paused,
    );
    expect(state.shouldPoll(isActiveTab: true), isFalse);

    state.lifecycleState = AppLifecycleState.resumed;
    expect(state.shouldPoll(isActiveTab: false), isFalse);
  });
}
