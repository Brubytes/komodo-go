import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Tags;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/builds/presentation/providers/builds_provider.dart';
import 'package:komodo_go/features/builds/presentation/views/builds_list_view.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';

class _TestBuilds extends Builds {
  _TestBuilds(this._builds);

  final List<BuildListItem> _builds;

  @override
  Future<List<BuildListItem>> build() async => _builds;
}

class _TestTags extends Tags {
  _TestTags(this._tags);

  final List<KomodoTag> _tags;

  @override
  Future<List<KomodoTag>> build() async => _tags;
}

Widget _app(List<BuildListItem> builds) {
  return ProviderScope(
    overrides: [
      buildsProvider.overrideWith(() => _TestBuilds(builds)),
      tagsProvider.overrideWith(() => _TestTags(const [])),
    ],
    child: const MaterialApp(home: BuildsListView()),
  );
}

void main() {
  final builds = [
    BuildListItem.fromJson(<String, dynamic>{
      'id': 'b1',
      'name': 'Build One',
      'info': <String, dynamic>{},
    }),
    BuildListItem.fromJson(<String, dynamic>{
      'id': 'b2',
      'name': 'Api Image',
      'info': <String, dynamic>{},
    }),
  ];

  testWidgets('Builds list renders build cards via ResourceListView',
      (tester) async {
    await tester.pumpWidget(_app(builds));
    await tester.pumpAndSettle();

    expect(find.byType(ResourceListView<BuildListItem>), findsOneWidget);
    expect(find.text('Builds'), findsOneWidget);
    expect(find.byKey(const ValueKey('build_card_b1')), findsOneWidget);
    expect(find.byKey(const ValueKey('build_card_b2')), findsOneWidget);
  });

  testWidgets('search narrows builds by name via builds_search field',
      (tester) async {
    await tester.pumpWidget(_app(builds));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('builds_search')), 'api');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('build_card_b2')), findsOneWidget);
    expect(find.byKey(const ValueKey('build_card_b1')), findsNothing);
  });
}
