import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/alerters/data/models/alerter.dart';
import 'package:komodo_go/features/alerters/data/models/alerter_list_item.dart';
import 'package:komodo_go/features/alerters/data/repositories/alerter_repository.dart';
import 'package:komodo_go/features/alerters/presentation/providers/alerters_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../support/provider_test_templates.dart';

class _MockAlerterRepository extends Mock implements AlerterRepository {}

void main() {
  group('Alerters provider', () {
    test('returns sorted alerters when repository succeeds', () async {
      final repository = _MockAlerterRepository();
      when(repository.listAlerters).thenAnswer(
        (_) async => Right([
          AlerterListItem.fromJson(<String, dynamic>{
            'id': 'a2',
            'name': 'B Alert',
            'info': <String, dynamic>{},
          }),
          AlerterListItem.fromJson(<String, dynamic>{
            'id': 'a1',
            'name': 'A Alert',
            'info': <String, dynamic>{},
          }),
        ]),
      );

      final container = createProviderContainer(
        overrides: [alerterRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, alertersProvider);
      addTearDown(subscription.close);

      final alerters = await readAsyncProvider(
        container,
        alertersProvider.future,
      );

      expect(alerters, hasLength(2));
      expect(alerters.first.name, 'A Alert');
    });

    test('returns empty list when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [alerterRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, alertersProvider);
      addTearDown(subscription.close);

      final alerters = await readAsyncProvider(
        container,
        alertersProvider.future,
      );

      expect(alerters, isEmpty);
    });

    test('throws when repository returns failure', () async {
      final repository = _MockAlerterRepository();
      when(repository.listAlerters).thenAnswer(
        (_) async => const Left(Failure.server(message: 'boom')),
      );

      final container = createProviderContainer(
        overrides: [alerterRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = listenProvider(container, alertersProvider);
      addTearDown(subscription.close);

      await expectLater(
        container.read(alertersProvider.future),
        throwsA(isA<Exception>()),
      );

      expectAsyncError(container.read(alertersProvider));
    });
  });

  group('Alerter detail provider', () {
    test('returns alerter detail when repository succeeds', () async {
      final repository = _MockAlerterRepository();
      when(
        () => repository.getAlerterDetail(alerterIdOrName: 'a1'),
      ).thenAnswer(
        (_) async => Right(
          AlerterDetail.fromApiJson(<String, dynamic>{
            'id': 'a1',
            'name': 'Alert A',
            'updated_at': 'now',
            'config': <String, dynamic>{'enabled': true},
          }),
        ),
      );

      final container = createProviderContainer(
        overrides: [alerterRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final detail = await readAsyncProvider(
        container,
        alerterDetailProvider('a1').future,
      );

      expect(detail?.name, 'Alert A');
    });

    test('returns null when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [alerterRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final detail = await readAsyncProvider(
        container,
        alerterDetailProvider('a1').future,
      );

      expect(detail, isNull);
    });
  });

  group('Alerter actions provider', () {
    test('delete returns false when unauthenticated', () async {
      final container = createProviderContainer(
        overrides: [alerterRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(alerterActionsProvider.notifier);
      final ok = await notifier.delete(id: 'a1');

      expect(ok, isFalse);
      expectAsyncError(container.read(alerterActionsProvider));
    });

    test('test returns true on success', () async {
      final repository = _MockAlerterRepository();
      when(() => repository.testAlerter(idOrName: 'a1'))
          .thenAnswer((_) async => const Right(null));

      final container = createProviderContainer(
        overrides: [alerterRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(alerterActionsProvider.notifier);
      final ok = await notifier.test(idOrName: 'a1');

      expect(ok, isTrue);
      expect(container.read(alerterActionsProvider).hasError, isFalse);
    });
  });
}
