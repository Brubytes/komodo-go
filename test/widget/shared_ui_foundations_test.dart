import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/error/provider_error.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/dialogs/confirm_destructive_dialog.dart';
import 'package:komodo_go/core/widgets/empty_error_state.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_card.dart';
import 'package:komodo_go/core/widgets/sheets/editor_sheet_scaffold.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('confirmDestructive', () {
    Future<bool?> run(
      WidgetTester tester, {
      bool destructive = true,
      String tap = 'Delete',
    }) async {
      bool? result;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await confirmDestructive(
                  context,
                  title: 'Delete?',
                  message: 'Gone forever',
                  confirmLabel: 'Delete',
                  destructive: destructive,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Gone forever'), findsOneWidget);
      await tester.tap(find.text(tap));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('returns true on confirm', (tester) async {
      expect(await run(tester), isTrue);
    });

    testWidgets('returns false on cancel', (tester) async {
      expect(await run(tester, tap: 'Cancel'), isFalse);
    });

    testWidgets('non-destructive variant works', (tester) async {
      expect(await run(tester, destructive: false), isTrue);
    });
  });

  group('DetailSubCard collapsible', () {
    testWidgets('toggles body and shows summary when collapsed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const DetailSubCard(
            title: 'Env',
            icon: Icons.settings,
            collapsible: true,
            initiallyExpanded: false,
            summary: '3 variables',
            modified: true,
            child: Text('body'),
          ),
        ),
      );
      expect(find.text('body'), findsNothing);
      expect(find.text('3 variables'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('detail_sub_card_modified_dot')),
        findsOneWidget,
      );

      await tester.tap(find.text('Env'));
      await tester.pumpAndSettle();
      expect(find.text('body'), findsOneWidget);
      expect(find.text('3 variables'), findsNothing);
    });

    testWidgets('non-collapsible keeps old behaviour', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DetailSubCard(
            title: 'Env',
            icon: Icons.settings,
            child: Text('body'),
          ),
        ),
      );
      expect(find.text('body'), findsOneWidget);
    });
  });

  group('DetailActionBar', () {
    testWidgets('More menu groups destructive last and fires callbacks', (
      tester,
    ) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _wrap(
          DetailActionBar(
            primary: DetailActionButton(
              label: 'Deploy',
              icon: Icons.rocket,
              onPressed: () => calls.add('deploy'),
            ),
            moreGroups: [
              DetailActionGroup(
                label: 'Lifecycle',
                items: [
                  DetailActionItem(
                    label: 'Destroy',
                    icon: Icons.delete,
                    destructive: true,
                    onSelected: () => calls.add('destroy'),
                  ),
                  DetailActionItem(
                    label: 'Restart',
                    icon: Icons.refresh,
                    onSelected: () => calls.add('restart'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Deploy'));
      expect(calls, ['deploy']);

      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      final restartY = tester.getTopLeft(find.text('Restart')).dy;
      final destroyY = tester.getTopLeft(find.text('Destroy')).dy;
      expect(destroyY, greaterThan(restartY));

      await tester.tap(find.text('Destroy'));
      await tester.pumpAndSettle();
      expect(calls, ['deploy', 'destroy']);
    });
  });

  group('EditorSheetScaffold', () {
    Future<void> open(WidgetTester tester, {required bool dirty}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showEditorSheet<void>(
                  context,
                  (_) => EditorSheetScaffold(
                    title: 'Edit',
                    dirty: dirty,
                    onSave: () {},
                    child: const Text('form'),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('cancel closes immediately when clean', (tester) async {
      await open(tester, dirty: false);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('form'), findsNothing);
    });

    testWidgets('cancel asks to discard when dirty', (tester) async {
      await open(tester, dirty: true);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('form'), findsOneWidget);

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('form'), findsNothing);
    });

    testWidgets('save disabled when canSave is false', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EditorSheetScaffold(
            title: 'Edit',
            canSave: false,
            onSave: () {},
            child: const Text('form'),
          ),
        ),
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });

  group('ResourceCard', () {
    testWidgets('long press opens same menu as trailing button', (
      tester,
    ) async {
      var restarted = false;
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          ResourceCard(
            title: 'web',
            subtitle: 'repo · main',
            status: const ResourceStatusSpec(
              label: 'Unhealthy',
              icon: Icons.error,
              tone: PillTone.alert,
            ),
            meta: const [
              ResourceIconLabel(icon: Icons.dns, label: 'server-1'),
            ],
            onTap: () => tapped = true,
            menu: [
              DetailActionGroup(
                items: [
                  DetailActionItem(
                    label: 'Restart',
                    icon: Icons.refresh,
                    onSelected: () => restarted = true,
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      expect(find.text('Unhealthy'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('resource_card_accent')),
        findsOneWidget,
      );

      await tester.longPress(find.text('web'));
      await tester.pumpAndSettle();
      expect(find.text('Restart'), findsOneWidget);
      await tester.tap(find.text('Restart'));
      await tester.pumpAndSettle();
      expect(restarted, isTrue);

      await tester.tap(find.text('web'));
      expect(tapped, isTrue);
    });

    testWidgets('no accent bar for healthy status', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ResourceCard(
            title: 'web',
            status: ResourceStatusSpec(
              label: 'Running',
              icon: Icons.check,
              tone: PillTone.success,
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('resource_card_accent')),
        findsNothing,
      );
    });
  });

  group('friendlyErrorMessage', () {
    test('unwraps failures and strips prefixes', () {
      expect(
        friendlyErrorMessage(const Failure.auth()),
        'Authentication failed. Please log in again.',
      );
      expect(
        friendlyErrorMessage(
          const FailureException(Failure.server(message: 'boom')),
        ),
        'boom',
      );
      expect(friendlyErrorMessage(Exception('oops')), 'oops');
    });
  });

  group('UnsavedChangesGuard', () {
    testWidgets('bar shows change count', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DetailUnsavedChangesBar(
            changeCount: 3,
            onDiscard: () {},
            onSave: () {},
          ),
        ),
      );
      expect(find.text('3 changes'), findsOneWidget);
    });
  });
}
