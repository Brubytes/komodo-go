import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/variables/data/models/variable.dart';
import 'package:komodo_go/features/variables/data/repositories/variable_repository.dart';

import '../../support/backend_test_config.dart';
import '../../support/backend_test_helpers.dart';

void registerVariableContractTests() {
  final config = BackendTestConfig.fromEnvironment();
  final missingConfigReason = config == null
      ? 'Set KOMODO_TEST_BASE_URL, KOMODO_TEST_API_KEY, and '
          'KOMODO_TEST_API_SECRET to run backend tests.'
      : null;

  group('Variable contract CRUD (real backend)', () {
    late VariableRepository repository;
    late RpcRecorder recorder;

    setUp(() async {
      await resetBackendIfConfigured(config!);
      recorder = RpcRecorder();
      repository = VariableRepository(buildTestClient(config!, recorder));
    });

    test('create/update/delete variable + goldens', () async {
      KomodoVariable? created;
      const name = 'Contract Variable';

      try {
        final createResult = await repository.createVariable(
          name: name,
          value: 'Contract Value',
          description: 'Contract Description',
          isSecret: false,
        );
        created = expectRight(createResult);

        final requestData = recorder.lastRequest?.data;
        final responseData = recorder.lastResponse?.data;

        expect(requestData, isA<Map>());
        expect(responseData, isA<Map>());

        final normalizedRequest = normalizeJson(
          (requestData as Map).cast<String, dynamic>(),
        );
        expect(
          normalizedRequest,
          loadGoldenJson('test/golden/variable_create_request.json'),
        );

        final normalizedResponse = normalizeVariableResponse(
          (responseData as Map).cast<String, dynamic>(),
        );
        expect(
          normalizedResponse,
          loadGoldenJson('test/golden/variable_create_response.json'),
        );

        final listed = expectRight(await repository.listVariables());
        final listedVar = listed.firstWhere((v) => v.name == name);
        expect(listedVar.description, isNotNull);

        final updatedValue = expectRight(
          await repository.updateVariableValue(
            name: name,
            value: 'Updated Value',
          ),
        );
        expect(updatedValue.name, name);

        final updatedDescription = expectRight(
          await repository.updateVariableDescription(
            name: name,
            description: 'Updated Description',
          ),
        );
        expect(updatedDescription.description, 'Updated Description');

        final updatedSecret = expectRight(
          await repository.updateVariableIsSecret(
            name: name,
            isSecret: true,
          ),
        );
        expect(updatedSecret.isSecret, true);

        expectRight(await repository.deleteVariable(name: name));
        final afterDelete = expectRight(await repository.listVariables());
        expect(afterDelete.any((v) => v.name == name), isFalse);
      } finally {
        if (created != null) {
          await repository.deleteVariable(name: created.name);
        }
      }
    });

    test('update missing variable returns server failure', () async {
      final missingName = 'missing-var-${_randomToken(Random(991))}';
      final result = await repository.updateVariableValue(
        name: missingName,
        value: 'noop',
      );
      expectServerFailure(result);
    });
  },
      skip: missingConfigReason ??
          config?.skipReason() ??
          config?.requireResetReason());

  group('Variable CRUD property-based (real backend)', () {
    late VariableRepository repository;

    setUp(() async {
      await resetBackendIfConfigured(config!);
      repository = VariableRepository(
        buildTestClient(config!, RpcRecorder()),
      );
    });

    test('randomized variables survive CRUD roundtrip', () async {
      final random = Random(4242);
      final createdNames = <String>[];

      try {
        for (var i = 0; i < 20; i++) {
          final name = 'prop-var-$i-${_randomToken(random)}';
          final value = 'val-${_randomToken(random)}';
          final description = 'desc-${_randomToken(random)}';
          final isSecret = random.nextBool();

          final created = expectRight(
            await repository.createVariable(
              name: name,
              value: value,
              description: description,
              isSecret: isSecret,
            ),
          );
          createdNames.add(created.name);

          final listed = expectRight(await repository.listVariables());
          final fromList = listed.firstWhere((v) => v.name == name);
          expect(fromList.name, name);
          expect(fromList.isSecret, isSecret);

          final updatedValue = 'val-${_randomToken(random)}';
          final updatedDescription = 'desc-${_randomToken(random)}';

          expectRight(
            await repository.updateVariableValue(
              name: name,
              value: updatedValue,
            ),
          );
          expectRight(
            await repository.updateVariableDescription(
              name: name,
              description: updatedDescription,
            ),
          );

          expectRight(await repository.deleteVariable(name: name));
          final afterDelete = expectRight(await repository.listVariables());
          expect(afterDelete.any((v) => v.name == name), isFalse);
        }
      } finally {
        for (final name in createdNames) {
          await repository.deleteVariable(name: name);
        }
      }
    });
  },
      skip: missingConfigReason ??
          config?.skipReason() ??
          config?.requireResetReason());
}

void main() => registerVariableContractTests();

T expectRight<T>(Either<Failure, T> result) {
  return result.fold(
    (failure) => fail('Expected success, got $failure'),
    (value) => value,
  );
}

String _randomToken(Random random) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final buffer = StringBuffer();
  for (var i = 0; i < 6; i++) {
    buffer.write(chars[random.nextInt(chars.length)]);
  }
  return buffer.toString();
}

Map<String, dynamic> normalizeVariableResponse(Map<String, dynamic> json) {
  final normalized = Map<String, dynamic>.from(json);
  normalized['description'] = '<description>';
  normalized['value'] = '<value>';
  if (!normalized.containsKey('is_secret')) {
    normalized['is_secret'] = false;
  }
  return normalizeJson(normalized);
}
