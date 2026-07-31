import 'package:flutter/material.dart' hide Actions;
import 'package:flutter_test/flutter_test.dart' hide Tags;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/actions/presentation/providers/actions_provider.dart';
import 'package:komodo_go/features/actions/presentation/views/actions_list_view.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';

class _TestActions extends Actions {
  _TestActions(this._actions);

  final List<ActionListItem> _actions;

  @override
  Future<List<ActionListItem>> build() async => _actions;
}

class _TestTags extends Tags {
  _TestTags(this._tags);

  final List<KomodoTag> _tags;

  @override
  Future<List<KomodoTag>> build() async => _tags;
}

Widget _app(List<ActionListItem> actions) {
  return ProviderScope(
    overrides: [
      actionsProvider.overrideWith(() => _TestActions(actions)),
      tagsProvider.overrideWith(() => _TestTags(const [])),
    ],
    child: const MaterialApp(home: ActionsListView()),
  );
}

void main() {
  final actions = [
    ActionListItem.fromJson(<String, dynamic>{
      'id': 'a1',
      'name': 'Action One',
      'info': <String, dynamic>{},
    }),
    ActionListItem.fromJson(<String, dynamic>{
      'id': 'a2',
      'name': 'Cleanup Job',
      'info': <String, dynamic>{},
    }),
  ];

  testWidgets('Actions list renders action cards via ResourceListView',
      (tester) async {
    await tester.pumpWidget(_app(actions));
    await tester.pumpAndSettle();

    expect(find.byType(ResourceListView<ActionListItem>), findsOneWidget);
    expect(find.text('Actions'), findsOneWidget);
    expect(find.byKey(const ValueKey('action_card_a1')), findsOneWidget);
    expect(find.byKey(const ValueKey('action_card_a2')), findsOneWidget);
  });

  testWidgets('search narrows actions by name via actions_search field',
      (tester) async {
    await tester.pumpWidget(_app(actions));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('actions_search')),
      'cleanup',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('action_card_a2')), findsOneWidget);
    expect(find.byKey(const ValueKey('action_card_a1')), findsNothing);
  });
}
