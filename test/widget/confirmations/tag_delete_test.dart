import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Tags;
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/data/repositories/tag_repository.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';
import 'package:komodo_go/features/tags/presentation/views/tags_view.dart';
import 'package:mocktail/mocktail.dart';

class _MockTagRepository extends Mock implements TagRepository {}

class _TestTags extends Tags {
  _TestTags(this._tags);

  final List<KomodoTag> _tags;

  @override
  Future<List<KomodoTag>> build() async => _tags;
}

void main() {
  setUpAll(() {
    registerFallbackValue(TagColor.slate);
  });

  testWidgets('delete confirmation blocks until the user confirms', (
    tester,
  ) async {
    final repository = _MockTagRepository();
    final tag = KomodoTag.fromJson(<String, dynamic>{
      'id': 't1',
      'name': 'alpha',
      'owner': 'test',
      'color': 'Slate',
    });
    when(
      () => repository.deleteTag(id: 't1'),
    ).thenAnswer((_) async => Right(tag));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagRepositoryProvider.overrideWithValue(repository),
          tagsProvider.overrideWith(() => _TestTags([tag])),
        ],
        child: const MaterialApp(home: TagsView()),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tag_tile_menu_t1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tag_delete_dialog_t1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tag_delete_cancel_t1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tag_delete_dialog_t1')), findsNothing);
    verifyNever(() => repository.deleteTag(id: 't1'));

    await tester.tap(find.byKey(const ValueKey('tag_tile_menu_t1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag_delete_confirm_t1')));
    await tester.pumpAndSettle();

    verify(() => repository.deleteTag(id: 't1')).called(1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
