import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/widgets/async/refresh_helpers.dart';

void main() {
  testWidgets('refreshProviders completes only after the new data arrived', (
    tester,
  ) async {
    var gate = Completer<int>();
    final slow = FutureProvider<int>((ref) => gate.future);
    final failing = FutureProvider<int>((ref) => throw StateError('x'));
    var done = false;

    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            ref
              ..watch(slow)
              ..watch(failing);
            return const SizedBox();
          },
        ),
      ),
    );
    gate.complete(1);
    await tester.pump();

    gate = Completer<int>();
    unawaited(
      refreshProviders(widgetRef, [slow.future, failing.future]).then((_) {
        done = true;
      }),
    );
    await tester.pump();
    expect(done, isFalse, reason: 'still waiting for the slow provider');
    expect(widgetRef.read(slow).value, 1, reason: 'old value kept');

    gate.complete(2);
    await tester.pump();
    await tester.pump();
    expect(done, isTrue);
    expect(widgetRef.read(slow).value, 2);
  });
}
