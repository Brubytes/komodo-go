import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Tags;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';
import 'package:komodo_go/features/syncs/presentation/providers/syncs_provider.dart';
import 'package:komodo_go/features/syncs/presentation/views/syncs_list_view.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';

class _TestSyncs extends Syncs {
  _TestSyncs(this._syncs);

  final List<ResourceSyncListItem> _syncs;

  @override
  Future<List<ResourceSyncListItem>> build() async => _syncs;
}

class _TestTags extends Tags {
  _TestTags(this._tags);

  final List<KomodoTag> _tags;

  @override
  Future<List<KomodoTag>> build() async => _tags;
}

Widget _app(List<ResourceSyncListItem> syncs) {
  return ProviderScope(
    overrides: [
      syncsProvider.overrideWith(() => _TestSyncs(syncs)),
      tagsProvider.overrideWith(() => _TestTags(const [])),
    ],
    child: const MaterialApp(home: SyncsListView()),
  );
}

void main() {
  final syncs = [
    ResourceSyncListItem.fromJson(<String, dynamic>{
      'id': 'sy1',
      'name': 'Sync One',
      'info': <String, dynamic>{},
    }),
    ResourceSyncListItem.fromJson(<String, dynamic>{
      'id': 'sy2',
      'name': 'Cluster State',
      'info': <String, dynamic>{'branch': 'release'},
    }),
  ];

  testWidgets('Syncs list renders sync cards via ResourceListView',
      (tester) async {
    await tester.pumpWidget(_app(syncs));
    await tester.pumpAndSettle();

    expect(find.byType(ResourceListView<ResourceSyncListItem>), findsOneWidget);
    expect(find.text('Syncs'), findsOneWidget);
    expect(find.text('Sync One'), findsOneWidget);
    expect(find.text('Cluster State'), findsOneWidget);
  });

  testWidgets('search matches sync info fields via syncs_search',
      (tester) async {
    await tester.pumpWidget(_app(syncs));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('syncs_search')),
      'release',
    );
    await tester.pumpAndSettle();

    expect(find.text('Cluster State'), findsOneWidget);
    expect(find.text('Sync One'), findsNothing);
  });
}
