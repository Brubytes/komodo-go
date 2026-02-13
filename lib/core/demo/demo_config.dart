const bool demoAvailable = bool.fromEnvironment(
  'KOMODO_DEMO_AVAILABLE',
  defaultValue: true,
);

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
