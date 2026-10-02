import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/features/notifications/data/models/resource_target.dart';
import 'package:komodo_go/features/notifications/data/models/semantic_version.dart';
import 'package:komodo_go/features/notifications/data/models/update_detail.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';
import 'package:komodo_go/features/notifications/presentation/providers/updates_provider.dart';
import 'package:komodo_go/features/notifications/presentation/views/update_detail_view.dart';

void main() {
  const detail = UpdateDetail(
    id: 'update-1',
    operation: 'DeployStack',
    startTs: 1700000000000,
    endTs: 1700000002500,
    success: false,
    operatorName: 'jan',
    target: ResourceTarget(type: ResourceTargetType.stack, id: 'stack-1'),
    logs: <UpdateLog>[
      UpdateLog(
        stage: 'Deploy',
        command: 'docker compose up -d',
        stdout: 'starting services',
        stderr: 'deployment failed',
        success: false,
        startTs: 1700000000000,
        endTs: 1700000002500,
      ),
    ],
    status: UpdateStatus.failed,
    version: SemanticVersion(major: 2, minor: 3, patch: 1),
    commitHash: 'abc123',
    otherData: '{"force":true}',
    previousToml: 'enabled = true',
    currentToml: 'enabled = false',
  );

  testWidgets('renders complete update execution details', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateDetailProvider(
            'update-1',
          ).overrideWith((ref) async => detail),
        ],
        child: const MaterialApp(
          home: UpdateDetailView(updateId: 'update-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('update_detail_content')), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Deploy Stack'), findsOneWidget);
    expect(find.text('jan'), findsOneWidget);
    expect(find.text('2.3.1'), findsOneWidget);
    expect(find.text('Open resource'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('docker compose up -d'),
      find.byType(ListView),
      const Offset(0, -400),
    );
    expect(find.text('starting services'), findsOneWidget);
    expect(find.text('deployment failed'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Previous TOML'),
      find.byType(ListView),
      const Offset(0, -400),
    );
    expect(find.text('enabled = true'), findsOneWidget);
    expect(find.text('Current TOML'), findsOneWidget);
    expect(find.text('enabled = false'), findsOneWidget);
  });

  testWidgets('shows a not-found state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateDetailProvider(
            'missing',
          ).overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: UpdateDetailView(updateId: 'missing')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Update not found'), findsOneWidget);
  });
}
