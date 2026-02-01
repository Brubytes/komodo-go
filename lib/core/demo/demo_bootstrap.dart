import 'demo_bootstrap_stub.dart' if (dart.library.io) 'demo_bootstrap_io.dart';

abstract class DemoBootstrap {
  static Future<void> ensureInitialized() =>
      DemoBootstrapImpl.ensureInitialized();
}
