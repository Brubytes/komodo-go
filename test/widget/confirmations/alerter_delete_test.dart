import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/features/alerters/data/models/alerter_list_item.dart';
import 'package:komodo_go/features/alerters/data/repositories/alerter_repository.dart';
import 'package:komodo_go/features/alerters/presentation/providers/alerters_provider.dart';
import 'package:komodo_go/features/alerters/presentation/views/alerters_view.dart';
import 'package:mocktail/mocktail.dart';

class _MockAlerterRepository extends Mock implements AlerterRepository {}

class _TestAlerters extends Alerters {
  _TestAlerters(this._items);

  final List<AlerterListItem> _items;

  @override
  Future<List<AlerterListItem>> build() async => _items;
}

void main() {
  testWidgets('delete confirmation blocks until the user confirms', (
    tester,
  ) async {
    final repository = _MockAlerterRepository();
    final item = AlerterListItem.fromJson(<String, dynamic>{
      'id': 'a1',
      'name': 'Alert One',
      'info': <String, dynamic>{
        'enabled': true,
        'endpoint_type': 'Webhook',
      },
      'template': false,
      'tags': <String>[],
    });
    when(
      () => repository.deleteAlerter(id: 'a1'),
    ).thenAnswer((_) async => const Right(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alerterRepositoryProvider.overrideWithValue(repository),
          alertersProvider.overrideWith(() => _TestAlerters([item])),
        ],
        child: const MaterialApp(home: AlertersView()),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(
      find.byWidgetPredicate((widget) => widget is PopupMenuButton).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();

    expect(find.text('Delete alerter'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete alerter'), findsNothing);
    verifyNever(() => repository.deleteAlerter(id: 'a1'));

    await tester.tap(
      find.byWidgetPredicate((widget) => widget is PopupMenuButton).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => repository.deleteAlerter(id: 'a1')).called(1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
