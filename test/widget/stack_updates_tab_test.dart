import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/stacks/stack_updates_provider.dart';
import 'package:komodo_go/composition/stacks/stack_updates_tab.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';
import 'package:komodo_go/features/notifications/presentation/providers/updates_provider.dart';

class _LoadingStackUpdates extends StackUpdates {
  final _pending = Completer<UpdatesState>();

  @override
  Future<UpdatesState> build(String stackId) => _pending.future;
}

class _EmptyStackUpdates extends StackUpdates {
  @override
  Future<UpdatesState> build(String stackId) async => const UpdatesState(
    items: <UpdateListItem>[],
    nextPage: null,
  );
}

class _ErrorStackUpdates extends StackUpdates {
  @override
  Future<UpdatesState> build(String stackId) async {
    throw Exception('updates unavailable');
  }
}

void main() {
  Widget nestedTab(StackUpdates Function(String stackId) create) {
    return ProviderScope(
      overrides: [stackUpdatesProvider.overrideWith2(create)],
      child: MaterialApp(
        home: Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                  context,
                ),
                sliver: const SliverAppBar(
                  pinned: true,
                  title: Text('Stack'),
                ),
              ),
            ],
            body: const StackUpdatesTab(stackId: 'stack-1'),
          ),
        ),
      ),
    );
  }

  testWidgets('loading state has one bounded vertical viewport', (
    tester,
  ) async {
    await tester.pumpWidget(
      nestedTab((stackId) => _LoadingStackUpdates()),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state has one bounded vertical viewport', (tester) async {
    await tester.pumpWidget(
      nestedTab((stackId) => _EmptyStackUpdates()),
    );
    await tester.pumpAndSettle();

    expect(find.text('No updates'), findsOneWidget);
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error state has one bounded vertical viewport', (tester) async {
    await tester.pumpWidget(
      nestedTab((stackId) => _ErrorStackUpdates()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to load updates'), findsOneWidget);
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
