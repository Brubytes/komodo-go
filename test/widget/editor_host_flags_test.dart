import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/async/async_value_x.dart';
import 'package:komodo_go/core/widgets/async/editor_host.dart';
import 'package:komodo_go/core/widgets/async/refresh_progress_bar.dart';
import 'package:komodo_go/core/widgets/async/stale_data_banner.dart';

Widget _host(AsyncValue<String?> value, {required bool flags}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: EditorHost<String>(
        value: value,
        onRetry: () {},
        showProgress: flags,
        showStaleBanner: flags,
        builder: (context, data) => Text(data),
      ),
    ),
  ),
);

void main() {
  final refreshing = asyncWithPrevious<String?>(
    const AsyncLoading(),
    const AsyncData('a'),
  );
  final staleError = asyncWithPrevious<String?>(
    const AsyncError('boom', StackTrace.empty),
    const AsyncData('a'),
  );

  testWidgets('shows progress and stale banner by default', (tester) async {
    await tester.pumpWidget(_host(refreshing, flags: true));
    expect(find.byType(RefreshProgressBar), findsOneWidget);
    expect(find.text('a'), findsOneWidget);
    await tester.pumpWidget(_host(staleError, flags: true));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('a'), findsOneWidget);
    expect(
      tester.widget<StaleDataBanner>(find.byType(StaleDataBanner)).visible,
      isTrue,
    );
  });

  testWidgets('showProgress/showStaleBanner false hide both', (tester) async {
    await tester.pumpWidget(_host(refreshing, flags: false));
    expect(find.byType(RefreshProgressBar), findsNothing);
    await tester.pumpWidget(_host(staleError, flags: false));
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<StaleDataBanner>(find.byType(StaleDataBanner)).visible,
      isFalse,
    );
    expect(find.text('a'), findsOneWidget);
  });
}
