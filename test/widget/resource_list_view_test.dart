import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Tags;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/widgets/filters/tag_filter_sheet.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_list_config.dart';

class _FakeItem {
  const _FakeItem({
    required this.id,
    required this.name,
    this.template = false,
    this.tags = const [],
  });

  final String id;
  final String name;
  final bool template;
  final List<String> tags;
}

ResourceListConfig<_FakeItem> _config({
  required AsyncValue<List<_FakeItem>> Function(WidgetRef ref) watchList,
  void Function(WidgetRef ref)? invalidateList,
}) {
  return ResourceListConfig<_FakeItem>(
    kind: ResourceKind.builds,
    title: 'Fakes',
    resourceName: 'fakes',
    icon: Icons.widgets,
    markColor: Colors.teal,
    searchFieldKey: const ValueKey('fakes_search'),
    skeletonTitle: 'Fake name',
    skeletonSubtitle: 'Fake subtitle',
    skeletonChipLeft: 'Idle',
    skeletonChipRight: 'Last run 1h',
    watchList: watchList,
    watchTagOptions: (ref) => const AsyncValue.data(<TagOption>[]),
    refreshList: (ref) async {},
    invalidateList: invalidateList ?? (ref) {},
    watchActionsState: (ref) => const AsyncValue.data(null),
    isTemplate: (item) => item.template,
    tagsOf: (item) => item.tags,
    searchFieldsOf: (item) => [item.name],
    cardBuilder: (context, ref, item, displayTags) => Card(
      key: ValueKey('fake_card_${item.id}'),
      child: ListTile(
        title: Text(item.name),
        subtitle: Text(displayTags.join(',')),
      ),
    ),
  );
}

Widget _app(ResourceListConfig<_FakeItem> config) {
  return ProviderScope(
    child: MaterialApp(home: ResourceListView<_FakeItem>(config: config)),
  );
}

void main() {
  const items = [
    _FakeItem(id: 'f1', name: 'Alpha One', tags: ['t1']),
    _FakeItem(id: 'f2', name: 'Beta Two'),
    _FakeItem(id: 'f3', name: 'Tmpl', template: true),
  ];

  testWidgets('renders title and cards; excludes templates by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_config(watchList: (ref) => const AsyncValue.data(items))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fakes'), findsOneWidget);
    expect(find.byKey(const ValueKey('fake_card_f1')), findsOneWidget);
    expect(find.byKey(const ValueKey('fake_card_f2')), findsOneWidget);
    expect(find.byKey(const ValueKey('fake_card_f3')), findsNothing);
    // Display tags flow through to the card builder (raw fallback).
    expect(find.text('t1'), findsOneWidget);
  });

  testWidgets('search filters cards; Clear filters restores them', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_config(watchList: (ref) => const AsyncValue.data(items))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('resource_filter_disclosure')),
      findsOneWidget,
    );
    expect(find.byTooltip('Filters'), findsNothing);
    expect(find.byTooltip('More actions'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('resource_filter_disclosure')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Templates'), findsOneWidget);
    expect(find.text('Tags'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('fakes_search')), 'beta');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('fake_card_f2')), findsOneWidget);
    expect(find.byKey(const ValueKey('fake_card_f1')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('fakes_search')), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('No fakes found'), findsOneWidget);
    expect(find.text('No fakes match your filters.'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('fake_card_f1')), findsOneWidget);
    expect(find.byKey(const ValueKey('fake_card_f2')), findsOneWidget);
  });

  testWidgets('empty data without filters shows create-in-web copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _config(
          watchList: (ref) => const AsyncValue.data(<_FakeItem>[]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No fakes found'), findsOneWidget);
    expect(
      find.text('Create fakes in the Komodo web interface.'),
      findsOneWidget,
    );
    expect(find.text('Clear filters'), findsNothing);
  });

  testWidgets('error state shows retry and invokes invalidateList', (
    tester,
  ) async {
    var invalidated = false;
    await tester.pumpWidget(
      _app(
        _config(
          watchList: (ref) =>
              AsyncValue.error(Exception('boom'), StackTrace.empty),
          invalidateList: (ref) => invalidated = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to load fakes'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    expect(invalidated, isTrue);
  });

  testWidgets('loading state shows skeleton placeholders', (tester) async {
    await tester.pumpWidget(
      _app(_config(watchList: (ref) => const AsyncValue.loading())),
    );
    await tester.pump();

    expect(find.text('Fake name'), findsWidgets);
    expect(find.text('Fake subtitle'), findsWidgets);
  });
}
