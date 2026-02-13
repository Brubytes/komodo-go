import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/tags/data/repositories/tag_repository.dart';

import '../../support/backend_test_config.dart';
import '../../support/backend_test_helpers.dart';

void registerAuthContractTests() {
  final config = BackendTestConfig.fromEnvironment();
  final missingConfigReason = config == null
      ? 'Set KOMODO_TEST_BASE_URL, KOMODO_TEST_API_KEY, and '
          'KOMODO_TEST_API_SECRET to run backend tests.'
      : null;

  group('Auth failures (real backend)', () {
    test('invalid api secret returns auth failure', () async {
      final requiredConfig = requireConfig(config);
      final badConfig = BackendTestConfig(
        baseUrl: requiredConfig.baseUrl,
        apiKey: requiredConfig.apiKey,
        apiSecret: 'invalid-secret',
        allowDestructive: requiredConfig.allowDestructive,
        resetCommand: requiredConfig.resetCommand,
      );

      final repository = TagRepository(
        buildTestClient(badConfig, RpcRecorder()),
      );

      final result = await repository.listTags();
      expectAuthFailure(result);
    });
  }, skip: missingConfigReason ?? config?.skipReason());
}

void main() => registerAuthContractTests();
