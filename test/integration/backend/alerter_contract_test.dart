import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/alerters/data/models/alerter.dart';
import 'package:komodo_go/features/alerters/data/models/alerter_list_item.dart';
import 'package:komodo_go/features/alerters/data/repositories/alerter_repository.dart';

import '../../support/backend_test_config.dart';
import '../../support/backend_test_helpers.dart';

void registerAlerterContractTests() {
  final config = BackendTestConfig.fromEnvironment();
  final missingConfigReason = config == null
      ? 'Set KOMODO_TEST_BASE_URL, KOMODO_TEST_API_KEY, and '
          'KOMODO_TEST_API_SECRET to run backend tests.'
      : null;

  group('Alerter CRUD (real backend)', () {
    late AlerterRepository repository;
    late KomodoApiClient client;

    setUp(() async {
      await resetBackendIfConfigured(requireConfig(config));
      client = buildTestClient(requireConfig(config), RpcRecorder());
      repository = AlerterRepository(client);
    });

    test('create/update/delete alerter', () async {
      AlerterListItem? created;

      try {
        final alerters = expectRight(await repository.listAlerters());
        expect(alerters, isNotEmpty);

        final seed = alerters.first;
        final detail = expectRight(
          await repository.getAlerterDetail(alerterIdOrName: seed.id),
        );

        final name = 'contract-alerter-${_randomToken(Random(6021))}';
        final createdJson = await client.write(
          RpcRequest(
            type: 'CreateAlerter',
            params: <String, dynamic>{
              'name': name,
              'config': _alerterConfigToMap(detail.config),
            },
          ),
        );
        final createdMap = createdJson as Map<String, dynamic>;
        final createdId = readIdFromMap(createdMap);

        final afterCreate = expectRight(await repository.listAlerters());
        created = afterCreate.firstWhere(
          (item) => item.id == createdId,
          orElse: () => AlerterListItem.fromJson(createdMap),
        );

        expectRight(
          await repository.renameAlerter(
            id: createdId,
            name: '$name-renamed',
          ),
        );

        expectRight(await repository.setEnabled(id: createdId, enabled: false));

        final afterUpdate = expectRight(await repository.listAlerters());
        final updated = afterUpdate.firstWhere((item) => item.id == createdId);
        expect(updated.name, '$name-renamed');

        expectRight(await repository.deleteAlerter(id: createdId));
        await expectEventuallyServerFailure(
          () => repository.getAlerterDetail(alerterIdOrName: createdId),
        );
        final afterDelete = expectRight(await repository.listAlerters());
        expect(afterDelete.any((item) => item.id == createdId), isFalse);
      } finally {
        if (created != null) {
          await repository.deleteAlerter(id: created.id);
        }
      }
    });
  },
      skip: missingConfigReason ??
          config?.skipReason() ??
          config?.requireResetReason());
}

void main() => registerAlerterContractTests();

T expectRight<T>(Either<Failure, T> result) {
  return result.fold(
    (failure) => fail('Expected success, got $failure'),
    (value) => value,
  );
}

Map<String, dynamic> _alerterConfigToMap(AlerterConfig config) {
  return <String, dynamic>{
    'enabled': config.enabled,
    'endpoint': config.endpoint?.toApiPayload(),
    'alert_types': config.alertTypes,
    'resources': config.resources.map((r) => r.toJson()).toList(),
    'except_resources': config.exceptResources.map((r) => r.toJson()).toList(),
    'maintenance_windows':
        config.maintenanceWindows.map((m) => m.toApiMap()).toList(),
  };
}

String _randomToken(Random random) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final buffer = StringBuffer();
  for (var i = 0; i < 6; i++) {
    buffer.write(chars[random.nextInt(chars.length)]);
  }
  return buffer.toString();
}
