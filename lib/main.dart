import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/app.dart';
import 'package:komodo_go/core/demo/demo_bootstrap.dart';
import 'package:komodo_go/core/error/provider_error.dart';
import 'package:komodo_go/core/syntax_highlight/app_syntax_highlight.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSyntaxHighlight.ensureInitialized();
  await DemoBootstrap.ensureInitialized();

  runApp(
    const ProviderScope(
      retry: providerRetry,
      child: KomodoApp(),
    ),
  );
}
