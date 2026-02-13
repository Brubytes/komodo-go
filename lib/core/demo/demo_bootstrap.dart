import 'package:komodo_go/core/demo/demo_bootstrap_stub.dart'
    if (dart.library.io) 'package:komodo_go/core/demo/demo_bootstrap_io.dart';

abstract class DemoBootstrap {
  static Future<void> ensureInitialized() =>
      DemoBootstrapImpl.ensureInitialized();
}
