import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Tags;
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/resources/resource_advanced_menu.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/komodo_api_capabilities.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';
import 'package:komodo_go/shared/resources/data/resource_management_repository.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_metadata.dart';
import 'package:mocktail/mocktail.dart';

class _MockResourceManagementRepository extends Mock
    implements ResourceManagementRepository {}

class _MockApiClient extends Mock implements KomodoApiClient {}

class _FakeRpcRequest extends Fake implements RpcRequest<dynamic> {}

class _TestTags extends Tags {
  _TestTags(this._tags);

  final List<KomodoTag> _tags;

  @override
  Future<List<KomodoTag>> build() async => _tags;
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const ResourceMetadata(
        kind: ResourceKind.stacks,
        id: '',
        name: '',
        description: '',
        template: false,
        tags: <String>[],
      ),
    );
    registerFallbackValue(
      const ResourceMetadataDraft(
        description: '',
        template: false,
        tags: <String>[],
      ),
    );
    registerFallbackValue(ResourceKind.stacks);
    registerFallbackValue(_FakeRpcRequest());
  });

  late _MockResourceManagementRepository repository;
  late int mutationCount;

  setUp(() {
    repository = _MockResourceManagementRepository();
    mutationCount = 0;
    when(
      () => repository.updateMetadata(
        metadata: any(named: 'metadata'),
        draft: any(named: 'draft'),
      ),
    ).thenAnswer((_) async => const Right<Failure, void>(null));
    when(
      () => repository.copy(
        kind: any(named: 'kind'),
        id: any(named: 'id'),
        name: any(named: 'name'),
      ),
    ).thenAnswer((_) async => const Right<Failure, void>(null));
    when(
      () => repository.rename(
        kind: any(named: 'kind'),
        id: any(named: 'id'),
        name: any(named: 'name'),
      ),
    ).thenAnswer((_) async => const Right<Failure, void>(null));
    when(
      () => repository.delete(
        kind: any(named: 'kind'),
        id: any(named: 'id'),
      ),
    ).thenAnswer((_) async => const Right<Failure, void>(null));
  });

  Future<void> pumpMenu(
    WidgetTester tester, {
    ResourceManagementRepository? repositoryOverride,
  }) async {
    const tags = <KomodoTag>[
      KomodoTag(id: 'old-tag', name: 'Old', owner: 'test', color: TagColor.red),
      KomodoTag(
        id: 'new-tag',
        name: 'New',
        owner: 'test',
        color: TagColor.blue,
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resourceManagementRepositoryProvider.overrideWithValue(
            repositoryOverride ?? repository,
          ),
          tagsProvider.overrideWith(() => _TestTags(tags)),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                ResourceAdvancedMenuButton(
                  metadata: const ResourceMetadata(
                    kind: ResourceKind.stacks,
                    id: 'stack-1',
                    name: 'Production',
                    description: 'Old description',
                    template: false,
                    tags: <String>['old-tag'],
                  ),
                  onMutated: () => mutationCount++,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openAction(
    WidgetTester tester,
    String key,
  ) async {
    await tester.tap(find.byKey(const ValueKey('resource_advanced_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('edits description, template, and exact tag assignment', (
    tester,
  ) async {
    await pumpMenu(tester);
    await openAction(tester, 'resource_edit_metadata');

    expect(find.text('Edit metadata'), findsOneWidget);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('resource_tag_old-tag')),
          )
          .value,
      isTrue,
    );

    await tester.enterText(
      find.byKey(const ValueKey('resource_description_field')),
      'New description',
    );
    await tester.tap(find.byKey(const ValueKey('resource_template_switch')));
    await tester.tap(find.byKey(const ValueKey('resource_tag_old-tag')));
    await tester.tap(find.byKey(const ValueKey('resource_tag_new-tag')));
    await tester.tap(find.byKey(const ValueKey('save_resource_metadata')));
    await tester.pumpAndSettle();

    final invocation = verify(
      () => repository.updateMetadata(
        metadata: captureAny(named: 'metadata'),
        draft: captureAny(named: 'draft'),
      ),
    ).captured;
    final metadata = invocation[0] as ResourceMetadata;
    final draft = invocation[1] as ResourceMetadataDraft;
    expect(metadata.id, 'stack-1');
    expect(draft.description, 'New description');
    expect(draft.template, isTrue);
    expect(draft.tags, <String>['new-tag']);
    expect(mutationCount, 1);
  });

  testWidgets('stays scrollable above an iPhone keyboard inset', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(393, 852)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio()
        ..resetViewInsets();
    });

    await pumpMenu(tester);
    await openAction(tester, 'resource_edit_metadata');
    await tester.tap(find.byKey(const ValueKey('resource_description_field')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 330);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final saveButton = find.byKey(const ValueKey('save_resource_metadata'));
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();

    expect(tester.getBottomRight(saveButton).dy, lessThanOrEqualTo(522));
    expect(tester.takeException(), isNull);
  });

  testWidgets('saves through the tagged resource target from the sheet', (
    tester,
  ) async {
    final client = _MockApiClient();
    when(
      () => client.capabilities,
    ).thenReturn(KomodoApiCapabilities.v23AndNewer);
    when(
      () => client.write(any()),
    ).thenAnswer((_) async => <String, dynamic>{});

    await pumpMenu(
      tester,
      repositoryOverride: ResourceManagementRepository(client),
    );
    await openAction(tester, 'resource_edit_metadata');
    await tester.tap(find.byKey(const ValueKey('save_resource_metadata')));
    await tester.pumpAndSettle();

    final request =
        verify(
              () => client.write(captureAny()),
            ).captured.single
            as RpcRequest<dynamic>;
    expect(request.type, 'UpdateResourceMeta');
    expect(
      (request.params as Map<String, dynamic>)['target'],
      <String, dynamic>{'type': 'Stack', 'id': 'stack-1'},
    );
    expect(mutationCount, 1);
  });

  testWidgets('copies and renames with trimmed names', (tester) async {
    await pumpMenu(tester);
    await openAction(tester, 'resource_copy');
    await tester.enterText(
      find.byKey(const ValueKey('resource_name_field')),
      '  Production copy  ',
    );
    await tester.tap(find.byKey(const ValueKey('confirm_resource_name')));
    await tester.pumpAndSettle();

    verify(
      () => repository.copy(
        kind: ResourceKind.stacks,
        id: 'stack-1',
        name: 'Production copy',
      ),
    ).called(1);

    await openAction(tester, 'resource_rename');
    await tester.enterText(
      find.byKey(const ValueKey('resource_name_field')),
      'Renamed production',
    );
    await tester.tap(find.byKey(const ValueKey('confirm_resource_name')));
    await tester.pumpAndSettle();

    verify(
      () => repository.rename(
        kind: ResourceKind.stacks,
        id: 'stack-1',
        name: 'Renamed production',
      ),
    ).called(1);
    expect(mutationCount, 2);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('requires destructive confirmation before deleting', (
    tester,
  ) async {
    await pumpMenu(tester);
    await openAction(tester, 'resource_delete');

    expect(find.text('Delete Production?'), findsOneWidget);
    verifyNever(
      () => repository.delete(
        kind: any(named: 'kind'),
        id: any(named: 'id'),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('confirm_resource_delete')));
    await tester.pumpAndSettle();

    verify(
      () => repository.delete(
        kind: ResourceKind.stacks,
        id: 'stack-1',
      ),
    ).called(1);
    expect(mutationCount, 1);
  });
}
