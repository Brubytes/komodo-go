import 'package:flutter_test/flutter_test.dart';

import 'fake_komodo_backend.dart';

enum PatrolBackendMode { fake, real }

class PatrolTestConfig {
  const PatrolTestConfig._({
    required this.mode,
    required this.baseUrl,
    required this.apiKey,
    required this.apiSecret,
    required this.allowDestructive,
    required this.stackName,
    required this.serverName,
    required this.buildName,
    required this.procedureName,
    required this.actionName,
    required this.containerName,
    required this.containerId,
    required this.deploymentName,
  });

  final PatrolBackendMode mode;
  final String baseUrl;
  final String apiKey;
  final String apiSecret;
  final bool allowDestructive;
  final String stackName;
  final String serverName;
  final String buildName;
  final String procedureName;
  final String actionName;
  final String containerName;
  final String containerId;
  final String deploymentName;

  static PatrolTestConfig fromEnvironment() {
    const modeRaw = String.fromEnvironment(
      'KOMODO_TEST_BACKEND_MODE',
      defaultValue: 'fake',
    );
    const baseUrlRaw = String.fromEnvironment(
      'KOMODO_TEST_BASE_URL',
      defaultValue: '',
    );
    const apiKeyRaw = String.fromEnvironment(
      'KOMODO_TEST_API_KEY',
      defaultValue: '',
    );
    const apiSecretRaw = String.fromEnvironment(
      'KOMODO_TEST_API_SECRET',
      defaultValue: '',
    );
    const allowDestructiveRaw = String.fromEnvironment(
      'KOMODO_TEST_ALLOW_DESTRUCTIVE',
      defaultValue: 'false',
    );
    const stackNameRaw = String.fromEnvironment(
      'KOMODO_TEST_STACK_NAME',
      defaultValue: '',
    );
    const serverNameRaw = String.fromEnvironment(
      'KOMODO_TEST_SERVER_NAME',
      defaultValue: '',
    );
    const buildNameRaw = String.fromEnvironment(
      'KOMODO_TEST_BUILD_NAME',
      defaultValue: '',
    );
    const procedureNameRaw = String.fromEnvironment(
      'KOMODO_TEST_PROCEDURE_NAME',
      defaultValue: '',
    );
    const actionNameRaw = String.fromEnvironment(
      'KOMODO_TEST_ACTION_NAME',
      defaultValue: '',
    );
    const containerNameRaw = String.fromEnvironment(
      'KOMODO_TEST_CONTAINER_NAME',
      defaultValue: '',
    );
    const containerIdRaw = String.fromEnvironment(
      'KOMODO_TEST_CONTAINER_ID',
      defaultValue: '',
    );
    const deploymentNameRaw = String.fromEnvironment(
      'KOMODO_TEST_DEPLOYMENT_NAME',
      defaultValue: '',
    );

    final normalizedMode = modeRaw.trim().toLowerCase();
    final mode = normalizedMode == 'real'
        ? PatrolBackendMode.real
        : PatrolBackendMode.fake;

    return PatrolTestConfig._(
      mode: mode,
      baseUrl: baseUrlRaw.trim(),
      apiKey: apiKeyRaw.trim(),
      apiSecret: apiSecretRaw.trim(),
      allowDestructive: _parseBool(allowDestructiveRaw),
      stackName: stackNameRaw.trim(),
      serverName: serverNameRaw.trim(),
      buildName: buildNameRaw.trim(),
      procedureName: procedureNameRaw.trim(),
      actionName: actionNameRaw.trim(),
      containerName: containerNameRaw.trim(),
      containerId: containerIdRaw.trim(),
      deploymentName: deploymentNameRaw.trim(),
    );
  }

  bool get isFake => mode == PatrolBackendMode.fake;
  bool get isReal => mode == PatrolBackendMode.real;

  bool get hasRealCredentials =>
      baseUrl.isNotEmpty && apiKey.isNotEmpty && apiSecret.isNotEmpty;

  String? skipReason({
    bool requiresFake = false,
    bool requiresDestructive = false,
    String? requiredResourceLabel,
    String? requiredResourceValue,
  }) {
    if (requiresFake && isReal) {
      return 'Requires KOMODO_TEST_BACKEND_MODE=fake';
    }
    if (isReal && !hasRealCredentials) {
      return 'Set KOMODO_TEST_BASE_URL, KOMODO_TEST_API_KEY, and KOMODO_TEST_API_SECRET to run Patrol tests in real mode.';
    }
    if (isReal && requiresDestructive && !allowDestructive) {
      return 'Set KOMODO_TEST_ALLOW_DESTRUCTIVE=true to run destructive Patrol tests against a real backend.';
    }
    if (isReal &&
        requiredResourceLabel != null &&
        (requiredResourceValue == null || requiredResourceValue.isEmpty)) {
      return 'Set $requiredResourceLabel to run this test in real backend mode.';
    }
    return null;
  }
}

class PatrolTestBackend {
  PatrolTestBackend._({
    required this.config,
    required this.baseUrl,
    required this.apiKey,
    required this.apiSecret,
    this.fake,
  });

  final PatrolTestConfig config;
  final String baseUrl;
  final String apiKey;
  final String apiSecret;
  final FakeKomodoBackend? fake;

  bool get isFake => fake != null;

  static const String _fakeApiKey = 'test-key';
  static const String _fakeApiSecret = 'test-secret';

  static Future<PatrolTestBackend> start(PatrolTestConfig config) async {
    if (config.isFake) {
      final backend = FakeKomodoBackend(
        expectedApiKey: _fakeApiKey,
        expectedApiSecret: _fakeApiSecret,
        port: 57868,
      );
      await backend.start();
      return PatrolTestBackend._(
        config: config,
        baseUrl: backend.baseUrl,
        apiKey: _fakeApiKey,
        apiSecret: _fakeApiSecret,
        fake: backend,
      );
    }

    if (!config.hasRealCredentials) {
      fail(
        'Missing KOMODO_TEST_BASE_URL/KOMODO_TEST_API_KEY/KOMODO_TEST_API_SECRET for real backend mode.',
      );
    }

    return PatrolTestBackend._(
      config: config,
      baseUrl: config.baseUrl,
      apiKey: config.apiKey,
      apiSecret: config.apiSecret,
    );
  }

  Future<void> stop() async {
    await fake?.stop();
  }
}

bool _parseBool(String raw) {
  final normalized = raw.trim().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}
