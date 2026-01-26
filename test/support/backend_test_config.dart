import 'dart:io';

class BackendTestConfig {
  BackendTestConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.apiSecret,
    required this.allowDestructive,
    required this.resetCommand,
  });

  final String baseUrl;
  final String apiKey;
  final String apiSecret;
  final bool allowDestructive;
  final String? resetCommand;

  static BackendTestConfig? fromEnvironment() {
    final env = Platform.environment;
    final baseUrl = (env['KOMODO_TEST_BASE_URL'] ?? '').trim();
    final apiKey = (env['KOMODO_TEST_API_KEY'] ?? '').trim();
    final apiSecret = (env['KOMODO_TEST_API_SECRET'] ?? '').trim();
    final allowDestructive = _readBool(env['KOMODO_TEST_ALLOW_DESTRUCTIVE']);
    final resetCommand = (env['KOMODO_TEST_RESET_COMMAND'] ?? '').trim();

    if (baseUrl.isEmpty || apiKey.isEmpty || apiSecret.isEmpty) {
      return null;
    }

    return BackendTestConfig(
      baseUrl: baseUrl,
      apiKey: apiKey,
      apiSecret: apiSecret,
      allowDestructive: allowDestructive,
      resetCommand: resetCommand.isEmpty ? null : resetCommand,
    );
  }

  String? skipReason() {
    if (!allowDestructive) {
      return 'Set KOMODO_TEST_ALLOW_DESTRUCTIVE=true to run backend tests.';
    }
    return null;
  }

  String? requireResetReason() {
    if (resetCommand == null) {
      return 'Set KOMODO_TEST_RESET_COMMAND to run tests that require backend reset.';
    }
    return null;
  }
}

bool _readBool(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}
