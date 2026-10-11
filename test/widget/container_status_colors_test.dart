import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/composition/containers/containers_provider.dart';
import 'package:komodo_go/core/theme/app_theme.dart';
import 'package:komodo_go/core/theme/status_colors.dart';
import 'package:komodo_go/features/containers/data/models/container.dart';
import 'package:komodo_go/features/containers/presentation/widgets/container_card.dart';

void main() {
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    testWidgets('${theme.brightness} distinguishes stopped from failed', (
      tester,
    ) async {
      final scheme = theme.colorScheme;
      for (final (state, label, color) in [
        (ContainerState.running, 'RUNNING', scheme.statusSuccess),
        (ContainerState.exited, 'EXITED', scheme.onSurfaceVariant),
        (ContainerState.dead, 'DEAD', scheme.error),
        (ContainerState.restarting, 'RESTARTING', scheme.statusWarning),
        (ContainerState.removing, 'REMOVING', scheme.primary),
        (ContainerState.unknown, 'UNKNOWN', scheme.onSurfaceVariant),
      ]) {
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
        expect(tester.widget<Text>(find.text(label)).style?.color, color);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
