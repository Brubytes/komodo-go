import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/features/variables/data/models/variable.dart';
import 'package:komodo_go/features/variables/data/repositories/variable_repository.dart';
import 'package:komodo_go/features/variables/presentation/providers/variables_provider.dart';
import 'package:komodo_go/features/variables/presentation/views/variables_view.dart';
import 'package:mocktail/mocktail.dart';

class _MockVariableRepository extends Mock implements VariableRepository {}

class _TestVariables extends Variables {
  _TestVariables(this._variables);

  final List<KomodoVariable> _variables;

  @override
  Future<List<KomodoVariable>> build() async => _variables;
}

void main() {
  testWidgets('delete confirmation blocks until the user confirms', (
    tester,
  ) async {
    final repository = _MockVariableRepository();
    final variable = KomodoVariable.fromJson(<String, dynamic>{
      'name': 'VAR_A',
      'description': 'api token',
      'value': 'secret',
      'is_secret': true,
    });
    when(
      () => repository.deleteVariable(name: 'VAR_A'),
    ).thenAnswer((_) async => Right(variable));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          variableRepositoryProvider.overrideWithValue(repository),
          variablesProvider.overrideWith(() => _TestVariables([variable])),
        ],
        child: const MaterialApp(home: VariablesView()),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(
      find.byWidgetPredicate((widget) => widget is PopupMenuButton).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();

    expect(find.text('Delete variable'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete variable'), findsNothing);
    verifyNever(() => repository.deleteVariable(name: 'VAR_A'));

    await tester.tap(
      find.byWidgetPredicate((widget) => widget is PopupMenuButton).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => repository.deleteVariable(name: 'VAR_A')).called(1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
