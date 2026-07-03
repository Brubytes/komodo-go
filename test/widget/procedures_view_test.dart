import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Tags;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/widgets/resource_list/resource_list_view.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/features/procedures/presentation/providers/procedures_provider.dart';
import 'package:komodo_go/features/procedures/presentation/views/procedures_list_view.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';

class _TestProcedures extends Procedures {
  _TestProcedures(this._procedures);

  final List<ProcedureListItem> _procedures;

  @override
  Future<List<ProcedureListItem>> build() async => _procedures;
}

class _TestTags extends Tags {
  _TestTags(this._tags);

  final List<KomodoTag> _tags;

  @override
  Future<List<KomodoTag>> build() async => _tags;
}

Widget _app(List<ProcedureListItem> procedures) {
  return ProviderScope(
    overrides: [
      proceduresProvider.overrideWith(() => _TestProcedures(procedures)),
      tagsProvider.overrideWith(() => _TestTags(const [])),
    ],
    child: const MaterialApp(home: ProceduresListView()),
  );
}

void main() {
  final procedures = [
    ProcedureListItem.fromJson(<String, dynamic>{
      'id': 'p1',
      'name': 'Procedure One',
      'info': <String, dynamic>{},
    }),
    ProcedureListItem.fromJson(<String, dynamic>{
      'id': 'p2',
      'name': 'Nightly Backup',
      'info': <String, dynamic>{},
    }),
  ];

  testWidgets('Procedures list renders procedure cards via ResourceListView',
      (tester) async {
    await tester.pumpWidget(_app(procedures));
    await tester.pumpAndSettle();

    expect(find.byType(ResourceListView<ProcedureListItem>), findsOneWidget);
    expect(find.text('Procedures'), findsOneWidget);
    expect(find.byKey(const ValueKey('procedure_card_p1')), findsOneWidget);
    expect(find.byKey(const ValueKey('procedure_card_p2')), findsOneWidget);
  });

  testWidgets(
    'search narrows procedures by name via procedures_search field',
    (tester) async {
      await tester.pumpWidget(_app(procedures));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('procedures_search')),
        'backup',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('procedure_card_p2')), findsOneWidget);
      expect(find.byKey(const ValueKey('procedure_card_p1')), findsNothing);
    },
  );
}
