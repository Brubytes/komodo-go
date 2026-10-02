import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/notifications/data/models/update_detail.dart';
import 'package:komodo_go/features/notifications/data/repositories/notifications_repository.dart';

import '../../support/backend_test_config.dart';
import '../../support/backend_test_helpers.dart';

void registerUpdateDetailContractTests() {
  final config = BackendTestConfig.fromEnvironment();
  final missingConfigReason = config == null
      ? 'Set KOMODO_TEST_BASE_URL, KOMODO_TEST_API_KEY, and '
            'KOMODO_TEST_API_SECRET to run backend tests.'
      : null;

  group('Update detail contract (real backend, read-only)', () {
    late NotificationsRepository repository;

    setUp(() {
      repository = NotificationsRepository(
        buildTestClient(requireConfig(config), RpcRecorder()),
      );
    });

    test('ListUpdates result round-trips through GetUpdate', () async {
      final page = expectRight(await repository.listUpdates(page: 0));
      expect(page.updates, isNotEmpty);

      final listItem = page.updates.firstWhere((item) => item.id.isNotEmpty);
      final detail = expectRight(await repository.getUpdate(listItem.id));

      expect(detail.id, listItem.id);
      expect(detail.operation, isNotEmpty);
      expect(detail.startTs, greaterThan(0));
      expect(detail.startedAt.millisecondsSinceEpoch, greaterThan(0));
      expect(detail.logs, everyElement(isA<UpdateLog>()));
      for (final log in detail.logs) {
        expect(log.startTs, greaterThanOrEqualTo(0));
        expect(log.endTs, greaterThanOrEqualTo(0));
        expect(log.duration, isA<Duration>());
      }
      if (detail.endTs != null) {
        expect(detail.duration, isA<Duration>());
      }
    });
  }, skip: missingConfigReason);
}

void main() => registerUpdateDetailContractTests();
