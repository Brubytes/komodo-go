import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/api/komodo_api_capabilities.dart';
import 'package:komodo_go/features/builders/presentation/views/builders/builder_config_editor_sheet.dart';

import '../support/fixtures.dart';

void main() {
  Future<BuilderConfigEditorResult?> pumpAndSave(
    WidgetTester tester, {
    required String fixture,
    required String type,
    Future<void> Function()? edit,
  }) async {
    final json = loadKomodoFixture(fixture);
    BuilderConfigEditorResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await BuilderConfigEditorSheet.show(
                  context,
                  builderName: json['name'] as String,
                  builderType: type,
                  builderJson: json,
                  capabilities: KomodoApiCapabilities.v23AndNewer,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await edit?.call();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('Komodo 2.x {type, params} Url builder shows its fields', (
    tester,
  ) async {
    await pumpAndSave(
      tester,
      fixture: 'get_builder_url',
      type: 'Url',
      edit: () async {
        expect(find.text('https://builder.example.com:8120'), findsOneWidget);
      },
    );
  });

  testWidgets('saving keeps the {type, params} shape and applies edits', (
    tester,
  ) async {
    final result = await pumpAndSave(
      tester,
      fixture: 'get_builder_url',
      type: 'Url',
      edit: () async {
        await tester.enterText(
          find.byWidgetPredicate(
            (w) =>
                w is EditableText &&
                w.controller.text == 'https://builder.example.com:8120',
          ),
          'https://changed.example.com:8120',
        );
        await tester.pumpAndSettle();
      },
    );

    expect(result, isNotNull);
    expect(result!.config['type'], 'Url');
    final params = result.config['params']! as Map<String, dynamic>;
    expect(params['address'], 'https://changed.example.com:8120');
    // Core merges partial configs: untouched fields and secrets are not sent.
    expect(params.keys, ['address']);
    expect(params.containsKey('passkey'), isFalse);
  });

  testWidgets('Url builder sends passkey only when the user changed it', (
    tester,
  ) async {
    final result = await pumpAndSave(
      tester,
      fixture: 'get_builder_url',
      type: 'Url',
      edit: () async {
        await tester.enterText(
          find.byWidgetPredicate(
            (w) => w is EditableText && w.controller.text == 'pk',
          ),
          'new-pk',
        );
        await tester.pumpAndSettle();
      },
    );

    final params = result!.config['params']! as Map<String, dynamic>;
    expect(params['passkey'], 'new-pk');
  });

  testWidgets('Server builder keeps server_ids inside params', (tester) async {
    final result = await pumpAndSave(
      tester,
      fixture: 'get_builder_server',
      type: 'Server',
      edit: () async {
        expect(find.text('697519a44d3b178d5a7e2f84'), findsOneWidget);
      },
    );

    expect(result!.config['type'], 'Server');
    expect(
      (result.config['params']! as Map<String, dynamic>)['server_ids'],
      ['697519a44d3b178d5a7e2f84'],
    );
  });

  testWidgets('Aws builder shows region and volume from params', (
    tester,
  ) async {
    final result = await pumpAndSave(
      tester,
      fixture: 'get_builder_aws',
      type: 'Aws',
      edit: () async {
        expect(find.text('eu-central-1'), findsOneWidget);
        expect(find.text('t3.small'), findsOneWidget);
        expect(find.text('30'), findsOneWidget);
      },
    );

    final params = result!.config['params']! as Map<String, dynamic>;
    expect(result.config['type'], 'Aws');
    expect(params['volume_gb'], 30);
    // Only editable scalars are sent; nested lists that hold account entries
    // (git_providers / image_registries) must never be echoed back.
    expect(params.keys.toSet(), {
      'region',
      'instance_type',
      'volume_gb',
      'port',
      'use_https',
      'assign_public_ip',
      'use_public_ip',
    });
  });

  testWidgets('Aws unrelated edit sends no git_providers/image_registries', (
    tester,
  ) async {
    final result = await pumpAndSave(
      tester,
      fixture: 'get_builder_aws',
      type: 'Aws',
      edit: () async {
        await tester.enterText(
          find.byWidgetPredicate(
            (w) => w is EditableText && w.controller.text == 'eu-central-1',
          ),
          'us-west-2',
        );
        await tester.pumpAndSettle();
      },
    );

    final params = result!.config['params']! as Map<String, dynamic>;
    expect(params['region'], 'us-west-2');
    expect(params.containsKey('git_providers'), isFalse);
    expect(params.containsKey('image_registries'), isFalse);
    expect(params.containsKey('docker_registries'), isFalse);
    expect(params.containsKey('secrets'), isFalse);
  });
}
