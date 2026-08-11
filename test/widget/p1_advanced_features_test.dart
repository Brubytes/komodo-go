import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/resources/resource_creation_view.dart';
import 'package:komodo_go/composition/syncs/advanced_sync_section.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_batch_sheet.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';
import 'package:komodo_go/shared/resources/data/resource_batch_repository.dart';
import 'package:komodo_go/shared/resources/models/resource_batch.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements KomodoApiClient {}

class _FakeBatchRepository extends ResourceBatchRepository {
  _FakeBatchRepository() : super(_MockApiClient());

  ResourceBatchAction? action;
  List<ResourceBatchItem> selected = const [];

  @override
  Future<Either<Failure, List<ResourceBatchResult>>> execute({
    required ResourceKind kind,
    required ResourceBatchAction action,
    required List<ResourceBatchItem> items,
  }) async {
    this.action = action;
    selected = items;
    return Right([
      ResourceBatchResult(
        item: items[0],
        success: true,
        updateId: 'update-1',
      ),
      ResourceBatchResult(
        item: items[1],
        success: false,
        error: 'permission denied',
      ),
    ]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('creation prioritizes template/copy and validates full form', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ResourceCreationView(kind: ResourceKind.servers),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Template'), findsWidgets);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Full form'), findsOneWidget);
    expect(find.text('No templates are available.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('create_resource')));
    await tester.pump();
    expect(find.text('Enter a resource name.'), findsOneWidget);

    await tester.tap(find.text('Full form'));
    await tester.pumpAndSettle();
    expect(find.text('Address'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('batch sheet returns an individual row for every result', (
    tester,
  ) async {
    final repository = _FakeBatchRepository();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resourceBatchRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                ResourceListActionsMenu(
                  kind: ResourceKind.stacks,
                  items: const [
                    ResourceBatchItem(id: 's1', name: 'one'),
                    ResourceBatchItem(id: 's2', name: 'two'),
                  ],
                  onCreate: () {},
                  onRefresh: () async {},
                  onBatchCompleted: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    expect(find.text('Create Stack'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'opening resource menu');
    await tester.tap(find.text('Batch operations'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'opening batch sheet');
    expect(find.text('s1'), findsNothing);
    expect(find.text('s2'), findsNothing);
    await tester.tap(find.text('Select all'));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'selecting batch items');
    await tester.tap(find.byKey(const ValueKey('run_batch')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'showing batch results');

    expect(repository.action, ResourceBatchAction.deploy);
    expect(repository.selected.map((item) => item.id), ['s1', 's2']);
    expect(find.text('1 succeeded, 1 failed'), findsOneWidget);
    expect(find.text('one'), findsOneWidget);
    expect(find.text('Update update-1'), findsOneWidget);
    expect(find.text('two'), findsOneWidget);
    expect(find.text('permission denied'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sync plan renders diffs and opens a bounded file editor', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const sync = KomodoResourceSync(
      id: 'sync-1',
      name: 'main',
      config: ResourceSyncConfig(
        managed: true,
        resourcePath: ['resources'],
      ),
      info: ResourceSyncInfo(
        pendingHash: 'abc123',
        pendingMessage: 'Update production',
        resourceUpdates: [
          ResourceSyncDiff(
            target: SyncResourceTarget(type: 'Stack', id: 'stack-1'),
            data: SyncDiffData(
              operation: SyncDiffOperation.update,
              current: 'name = "old"',
              proposed: 'name = "new"',
            ),
          ),
        ],
        remoteContents: [
          SyncFileContents(
            resourcePath: 'resources',
            path: 'stacks.toml',
            contents: '[[stack]]',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AdvancedSyncSection(
                syncResource: sync,
                onUpdated: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'rendering sync plan');

    expect(find.text('Proposed sync plan'), findsOneWidget);
    expect(find.text('Update Stack'), findsOneWidget);
    expect(find.text('Commit abc123'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'selecting sync diff');
    expect(find.text('Apply 1 selected'), findsOneWidget);

    await tester.tap(find.text('Update Stack'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'expanding sync diff');
    expect(find.text('name = "old"'), findsOneWidget);
    expect(find.text('name = "new"'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('edit_sync_file')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'opening sync editor');
    expect(find.text('stacks.toml'), findsOneWidget);
    expect(find.text('[[stack]]'), findsOneWidget);
  });
}
