import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/composition/containers/containers_provider.dart';
import 'package:komodo_go/core/theme/app_theme.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/features/containers/data/models/container.dart';
import 'package:komodo_go/features/containers/presentation/widgets/container_card.dart';

void main() {
  test('container states map to consistent pill tones', () {
    for (final (state, status, label, tone) in [
      (ContainerState.running, null, 'Running', PillTone.success),
      (ContainerState.exited, 'Exited (0) 2h ago', 'Exited', PillTone.neutral),
      (ContainerState.exited, 'Exited (1) 2h ago', 'Exited', PillTone.alert),
      (ContainerState.dead, null, 'Dead', PillTone.alert),
      (ContainerState.restarting, null, 'Restarting', PillTone.warning),
      (ContainerState.removing, null, 'Removing', PillTone.warning),
      (ContainerState.unknown, null, 'Unknown', PillTone.neutral),
    ]) {
      final spec = containerStatusSpec(
        ContainerListItem(name: 'web', state: state, status: status),
      );
      expect(spec.label, label);
      expect(spec.tone, tone, reason: '$state $status');
    }
  });

  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    testWidgets('${theme.brightness} renders every state without errors', (
      tester,
    ) async {
      for (final state in ContainerState.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: ContainerCard(
                item: ContainerOverviewItem(
                  serverId: 'server',
                  serverName: 'Server',
                  container: ContainerListItem(name: 'web', state: state),
                ),
              ),
            ),
          ),
        );
        expect(find.text('web'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
