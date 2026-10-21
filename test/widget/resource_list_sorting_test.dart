import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Tags;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/widgets/filters/app_filter_chip.dart';
import 'package:komodo_go/core/widgets/filters/tag_filter_sheet.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_list_config.dart';

class _Item {
  const _Item(this.id, this.name, this.severity, this.server);

  final String id;
  final String name;
  final int severity;
  final String server;
}

const _items = [
  _Item('ok', 'zeta', 2, 'nas'),
  _Item('bad', 'beta', 0, 'vps'),
  _Item('warn', 'alpha', 1, 'nas'),
];

ResourceListConfig<_Item> _config() => ResourceListConfig<_Item>(
  kind: ResourceKind.builds,
  title: 'Fakes',
  resourceName: 'fakes',
  icon: Icons.widgets,
  markColor: Colors.teal,
  searchFieldKey: const ValueKey('fakes_search'),
  skeletonTitle: 't',
  skeletonSubtitle: 's',
  skeletonChipLeft: 'l',
  skeletonChipRight: 'r',
  watchList: (ref) => const AsyncValue.data(_items),
  watchTagOptions: (ref) => const AsyncValue.data(<TagOption>[]),
  refreshList: (ref) async {},
  invalidateList: (ref) {},
  watchActionsState: (ref) => const AsyncValue.data(null),
  isTemplate: (item) => false,
  tagsOf: (item) => const [],
  searchFieldsOf: (item) => [item.name],
  nameOf: (item) => item.name,
  severityOf: (item) => item.severity,
  stateLabelOf: (item) => 'S${item.severity}',
  serverNameOf: (item) => item.server,
  cardBuilder: (context, ref, item, displayTags) =>
      Card(key: ValueKey('card_${item.id}'), child: Text(item.name)),
);

double _top(WidgetTester tester, String id) =>
    tester.getTopLeft(find.byKey(ValueKey('card_$id'))).dy;

Widget _app() => ProviderScope(
  child: MaterialApp(home: ResourceListView<_Item>(config: _config())),
);

void main() {
  testWidgets('renders problems first by default', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(_top(tester, 'bad'), lessThan(_top(tester, 'warn')));
    expect(_top(tester, 'warn'), lessThan(_top(tester, 'ok')));
  });

  testWidgets('problems-only filter shows chip row and badge', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('resource_filter_disclosure')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('resource_problems_only_builds')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('card_ok')), findsNothing);
    expect(find.byKey(const ValueKey('card_bad')), findsOneWidget);

    // Collapse the panel and hide search: chip row + badge appear.
    await tester.tap(find.byKey(const ValueKey('resource_filter_disclosure')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hide search'));
    await tester.pumpAndSettle();

    expect(find.text('Problems only'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('card_ok')), findsOneWidget);
    expect(find.text('Problems only'), findsNothing);
  });

  testWidgets('server chip filters items', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('resource_filter_disclosure')));
    await tester.pumpAndSettle();
    final vps = find.widgetWithText(AppFilterChip, 'vps');
    await tester.ensureVisible(vps);
    await tester.tap(vps);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('card_bad')), findsOneWidget);
    expect(find.byKey(const ValueKey('card_warn')), findsNothing);
  });
}
