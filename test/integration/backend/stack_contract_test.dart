import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/data/repositories/stack_repository.dart';

import '../../support/backend_test_config.dart';
import '../../support/backend_test_helpers.dart';

void registerStackContractTests() {
  final config = BackendTestConfig.fromEnvironment();
  final missingConfigReason = config == null
      ? 'Set KOMODO_TEST_BASE_URL, KOMODO_TEST_API_KEY, and '
          'KOMODO_TEST_API_SECRET to run backend tests.'
      : null;

  group('Stack contract CRUD-ish (real backend)', () {
    late StackRepository repository;
    late RpcRecorder recorder;

    setUp(() async {
      await resetBackendIfConfigured(config!);
      recorder = RpcRecorder();
      repository = StackRepository(buildTestClient(config!, recorder));
    });

    test('list/get/update stack config + golden request', () async {
      final stacks = expectRight(await repository.listStacks());
      expect(stacks, isNotEmpty);

      final target = stacks.first;
      final stack = expectRight(await repository.getStack(target.id));
      final originalEnvironment = stack.config.environment;

      final updated = expectRight(
        await repository.updateStackConfig(
          stackId: stack.id,
          partialConfig: <String, dynamic>{'environment': 'komodo-test'},
        ),
      );
      expect(updated.id, stack.id);
      expect(updated.config.environment.trim(), 'komodo-test');

      final requestData = recorder.lastRequest?.data;
      expect(requestData, isA<Map>());

      final normalizedRequest = normalizeStackUpdateRequest(
        (requestData as Map).cast<String, dynamic>(),
      );
      expect(
        normalizedRequest,
        loadGoldenJson('test/golden/stack_update_request.json'),
      );

      final refreshed = expectRight(await repository.getStack(target.id));
      expect(refreshed.config.environment.trim(), 'komodo-test');

      await repository.updateStackConfig(
        stackId: stack.id,
        partialConfig: <String, dynamic>{'environment': originalEnvironment},
      );
    });
  },
      skip: missingConfigReason ??
          config?.skipReason() ??
          config?.requireResetReason());

  group('Stack config property-based (real backend)', () {
    late StackRepository repository;

    setUp(() async {
      await resetBackendIfConfigured(config!);
      repository = StackRepository(
        buildTestClient(config!, RpcRecorder()),
      );
    });

    test('randomized environment values survive update', () async {
      final stacks = expectRight(await repository.listStacks());
      expect(stacks, isNotEmpty);

      final target = stacks.first;
      final original = expectRight(await repository.getStack(target.id));
      final originalEnvironment = original.config.environment;

      final random = Random(2026);

      try {
        for (var i = 0; i < 10; i++) {
          final environment = 'komodo-test-${_randomToken(random)}';
          final updated = expectRight(
            await repository.updateStackConfig(
              stackId: target.id,
              partialConfig: <String, dynamic>{'environment': environment},
            ),
          );
          expect(updated.config.environment.trim(), environment);

          final refreshed = expectRight(await repository.getStack(target.id));
          expect(refreshed.config.environment.trim(), environment);
        }
      } finally {
        await repository.updateStackConfig(
          stackId: target.id,
          partialConfig: <String, dynamic>{'environment': originalEnvironment},
        );
      }
    });
  },
      skip: missingConfigReason ??
          config?.skipReason() ??
          config?.requireResetReason());
}

void main() => registerStackContractTests();

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

Map<String, dynamic> normalizeStackUpdateRequest(Map<String, dynamic> json) {
  final normalized = normalizeJson(json);
  final params = Map<String, dynamic>.from(
    (normalized['params'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{},
  );
  params['id'] = '<id>';
  normalized['params'] = params;
  return normalized;
}
