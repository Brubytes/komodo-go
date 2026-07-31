import 'package:komodo_go/core/connections/connection_profile.dart';

const bool demoAvailable = bool.fromEnvironment(
  'KOMODO_DEMO_AVAILABLE',
  defaultValue: true,
);

/// Reserved, stable connection id for the bundled demo connection.
///
/// The demo connection is identified by this id (never by its display
/// name) so a real user connection that happens to be named like the demo
/// can never be deleted or have its credentials overwritten.
const String demoConnectionId = 'komodo-demo-connection';

/// Whether [connection] is the bundled demo connection.
bool isDemoConnection(ConnectionProfile connection) =>
    connection.id == demoConnectionId;

/// Detects demo profiles created by older app versions, which used a
/// random connection id and were matched by display name.
///
/// Only used to find migration/cleanup candidates during demo bootstrap.
/// The loopback requirement guarantees a real remote connection is never
/// matched, even if it shares the demo display name.
bool isLegacyDemoConnection(ConnectionProfile connection) {
  if (connection.name != demoConnectionName) {
    return false;
  }
  final host = Uri.tryParse(connection.baseUrl.trim())?.host ?? '';
  return host == 'localhost' || host == '::1' || host.startsWith('127.');
}

const bool demoAutoConnect = bool.fromEnvironment(
  'KOMODO_DEMO_MODE',
);

const String demoConnectionName = String.fromEnvironment(
  'KOMODO_DEMO_NAME',
  defaultValue: 'Komodo Demo',
);

const String demoApiKey = String.fromEnvironment(
  'KOMODO_DEMO_API_KEY',
  defaultValue: 'demo-key',
);

const String demoApiSecret = String.fromEnvironment(
  'KOMODO_DEMO_API_SECRET',
  defaultValue: 'demo-secret',
);
