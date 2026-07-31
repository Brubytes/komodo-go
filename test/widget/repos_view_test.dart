import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Tags;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/repos/presentation/views/repos_list_view.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';

class _TestRepos extends Repos {
  _TestRepos(this._repos);

  final List<RepoListItem> _repos;

  @override
  Future<List<RepoListItem>> build() async => _repos;
}

class _TestTags extends Tags {
  _TestTags(this._tags);

  final List<KomodoTag> _tags;

  @override
  Future<List<KomodoTag>> build() async => _tags;
}

Widget _app(List<RepoListItem> repos) {
  return ProviderScope(
    overrides: [
      reposProvider.overrideWith(() => _TestRepos(repos)),
      tagsProvider.overrideWith(() => _TestTags(const [])),
    ],
    child: const MaterialApp(home: ReposListView()),
  );
}

void main() {
  final repos = [
    RepoListItem.fromJson(<String, dynamic>{
      'id': 'r1',
      'name': 'Repo One',
      'info': <String, dynamic>{},
    }),
    RepoListItem.fromJson(<String, dynamic>{
      'id': 'r2',
      'name': 'Infra Config',
      'info': <String, dynamic>{'branch': 'develop'},
    }),
  ];

  testWidgets('Repos list renders repo cards via ResourceListView',
      (tester) async {
    await tester.pumpWidget(_app(repos));
    await tester.pumpAndSettle();

    expect(find.byType(ResourceListView<RepoListItem>), findsOneWidget);
    expect(find.text('Repos'), findsOneWidget);
    expect(find.byKey(const ValueKey('repo_card_r1')), findsOneWidget);
    expect(find.byKey(const ValueKey('repo_card_r2')), findsOneWidget);
  });

  testWidgets('search matches repo info fields (branch) via repos_search',
      (tester) async {
    await tester.pumpWidget(_app(repos));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('repos_search')),
      'develop',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('repo_card_r2')), findsOneWidget);
    expect(find.byKey(const ValueKey('repo_card_r1')), findsNothing);
  });
}
