import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Tags;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';
import 'package:komodo_go/features/tags/presentation/views/tags_view.dart';

class _TestTags extends Tags {
  _TestTags(this._tags);

  final List<KomodoTag> _tags;

  @override
  Future<List<KomodoTag>> build() async => _tags;
}

void main() {
  testWidgets('Tags view shows list and opens editor sheet', (tester) async {
    final tags = [
      KomodoTag.fromJson(<String, dynamic>{
        'id': 't1',
        'name': 'alpha',
        'owner': 'test',
        'color': 'Slate',
      }),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tagsProvider.overrideWith(() => _TestTags(tags))],
        child: const MaterialApp(home: TagsView()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tag_tile_t1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tags_add')));
    await tester.pumpAndSettle();

    expect(find.text('New tag'), findsOneWidget);
    expect(find.byKey(const ValueKey('tag_editor_name')), findsOneWidget);
  });

  testWidgets('Tags view shows empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tagsProvider.overrideWith(() => _TestTags(const []))],
        child: const MaterialApp(home: TagsView()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No tags found'), findsOneWidget);
  });
}
