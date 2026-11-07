import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/error/provider_error.dart';
import 'package:komodo_go/core/network/app_lifecycle_provider.dart';
import 'package:komodo_go/core/network/network_status.dart';
import 'package:komodo_go/core/network/refresh_in_place.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/data/repositories/stack_repository.dart';
import 'package:komodo_go/shared/resources/providers/resource_activity_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'stacks_provider.g.dart';

/// Provides the list of all stacks.
@riverpod
class Stacks extends _$Stacks {
  @override
  Future<List<StackListItem>> build() async {
    ref.refreshOnActivity(ActivityScope.stacks);
    final repository = ref.watch(stackRepositoryProvider);
    if (repository == null) {
      return [];
    }

    final result = await repository.listStacks();

    final stacks = unwrapOrThrow(result);
    ref.onDispose(() {
      _pollTimer?.cancel();
      _lifecycleWatched = false; // listeners are closed with the build
    });
    _watchLifecycle();
    _schedulePoll(stacks);
    return stacks;
  }

  Timer? _pollTimer;
  var _lifecycleWatched = false;

  static bool _isTransitioning(StackListItem stack) =>
      switch (stack.info.state) {
        StackState.deploying ||
        StackState.restarting ||
        StackState.removing => true,
        _ => false,
      };

  bool _canPoll() =>
      ref.read(appLifecycleProvider) == AppLifecycleState.resumed &&
      !ref.read(networkStatusProvider).isOffline;

  /// Pause while backgrounded/offline instead of rescheduling forever;
  /// resume (or reconnect) kicks the poll off again.
  void _watchLifecycle() {
    if (_lifecycleWatched) return;
    _lifecycleWatched = true;
    ref
      ..listen(appLifecycleProvider, (previous, next) {
        if (next == AppLifecycleState.resumed && _canPoll()) {
          unawaited(pollRefresh());
        }
      })
      ..listen(networkStatusProvider, (previous, next) {
        if (previous?.isOffline == true && !next.isOffline && _canPoll()) {
          unawaited(pollRefresh());
        }
      });
  }

  /// Schedules the next poll tick while any stack is still transitioning.
  void _schedulePoll(List<StackListItem> stacks) {
    _pollTimer?.cancel();
    if (!stacks.any(_isTransitioning)) return;
    final interval = ref
        .read(networkStatusProvider)
        .scaleInterval(const Duration(seconds: 5));
    if (interval == null) return;
    _pollTimer = Timer(interval, () {
      if (_canPoll()) unawaited(pollRefresh());
    });
  }

  /// Poll tick for transitioning stacks: refetches the list and applies it
  /// only if it changed (no loading flicker). Keeps polling while any stack
  /// is still transitioning. Detail/service providers of transitioning stacks
  /// are polled the same way (silent, in place).
  Future<void> pollRefresh() async {
    final repository = ref.read(stackRepositoryProvider);
    final previous = state.value;
    if (repository == null || previous == null || state.isLoading) return;
    if (!previous.any(_isTransitioning)) return;
    for (final stack in previous.where(_isTransitioning)) {
      // Only providers someone is watching; never build them just to poll.
      if (ref.exists(stackDetailProvider(stack.id))) {
        unawaited(
          ref.read(stackDetailProvider(stack.id).notifier).pollRefresh(),
        );
      }
      if (ref.exists(stackServicesProvider(stack.id))) {
        unawaited(
          ref.read(stackServicesProvider(stack.id).notifier).pollRefresh(),
        );
      }
    }
    await refreshInPlace<List<StackListItem>>(
      current: previous,
      fetch: () async => unwrapOrThrow(await repository.listStacks()),
      apply: (value) => state = AsyncData(value),
      equals: listEq,
      isMounted: () => ref.mounted,
    );
    if (ref.mounted) _schedulePoll(state.value ?? previous);
  }

  /// Refreshes the stacks list.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Exception {
      // Ignore refresh errors.
    }
  }
}

/// Provides details for a specific stack.
@riverpod
class StackDetail extends _$StackDetail {
  @override
  Future<KomodoStack?> build(String stackIdOrName) async {
    ref.refreshOnActivity(ActivityScope.stacks);
    final repository = ref.watch(stackRepositoryProvider);
    if (repository == null) {
      return null;
    }

    final result = await repository.getStack(stackIdOrName);

    return unwrapOrThrow(result);
  }

  /// Poll tick: updates state only when the stack changed, so watchers do not
  /// rebuild (or flash a progress bar) on identical data.
  Future<void> pollRefresh() {
    final repository = ref.read(stackRepositoryProvider);
    if (repository == null || state.isLoading) return Future.value();
    return refreshInPlace<KomodoStack?>(
      current: state.value,
      fetch: () async =>
          unwrapOrThrow(await repository.getStack(stackIdOrName)),
      apply: (value) => state = AsyncData(value),
      isMounted: () => ref.mounted,
    );
  }
}

/// Provides services (containers) for a specific stack.
@riverpod
class StackServices extends _$StackServices {
  @override
  Future<List<StackService>> build(String stackIdOrName) async {
    ref.refreshOnActivity(ActivityScope.stacks);
    final repository = ref.watch(stackRepositoryProvider);
    if (repository == null) {
      return [];
    }

    final result = await repository.listStackServices(stackIdOrName);

    return unwrapOrThrow(result);
  }

  /// Poll tick: updates state only when the services changed.
  Future<void> pollRefresh() {
    final repository = ref.read(stackRepositoryProvider);
    if (repository == null || state.isLoading) return Future.value();
    return refreshInPlace<List<StackService>>(
      current: state.value,
      fetch: () async =>
          unwrapOrThrow(await repository.listStackServices(stackIdOrName)),
      apply: (value) => state = AsyncData(value),
      equals: listEq,
      isMounted: () => ref.mounted,
    );
  }
}

/// Provides a recent log snapshot for a stack.
@riverpod
Future<StackLog?> stackLog(Ref ref, String stackIdOrName) async {
  final repository = ref.watch(stackRepositoryProvider);
  if (repository == null) {
    return null;
  }

  final result = await repository.getStackLog(stackIdOrName: stackIdOrName);

  return unwrapOrThrow(result);
}

/// Action state for stack operations.
@riverpod
class StackActions extends _$StackActions {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> deploy(String stackIdOrName) =>
      _executeAction((repo) => repo.deployStack(stackIdOrName));

  Future<bool> deployIfChanged(String stackIdOrName) =>
      _executeAction((repo) => repo.deployStackIfChanged(stackIdOrName));

  Future<List<StackServiceWithUpdate>?> checkForUpdates(
    String stackIdOrName,
  ) => _executeRequest((repo) => repo.checkForUpdates(stackIdOrName));

  Future<bool> pullImages(String stackIdOrName) =>
      _executeAction((repo) => repo.pullStackImages(stackIdOrName));

  Future<bool> restart(String stackIdOrName) =>
      _executeAction((repo) => repo.restartStack(stackIdOrName));

  Future<bool> pause(String stackIdOrName) =>
      _executeAction((repo) => repo.pauseStack(stackIdOrName));

  Future<bool> start(String stackIdOrName) =>
      _executeAction((repo) => repo.startStack(stackIdOrName));

  Future<bool> stop(String stackIdOrName) =>
      _executeAction((repo) => repo.stopStack(stackIdOrName));

  Future<bool> destroy(String stackIdOrName) =>
      _executeAction((repo) => repo.destroyStack(stackIdOrName));

  Future<bool> writeStackFileContents({
    required String stackIdOrName,
    required String filePath,
    required String contents,
  }) => _executeAction(
    (repo) => repo.writeStackFileContents(
      stackIdOrName: stackIdOrName,
      filePath: filePath,
      contents: contents,
    ),
  );

  Future<KomodoStack?> updateStackConfig({
    required String stackId,
    required Map<String, dynamic> partialConfig,
  }) => _executeRequest(
    (repo) => repo.updateStackConfig(
      stackId: stackId,
      partialConfig: partialConfig,
    ),
  );

  Future<bool> _executeAction(
    Future<Either<Failure, void>> Function(StackRepository repo) action,
  ) async {
    final repository = ref.read(stackRepositoryProvider);
    if (repository == null) {
      state = AsyncValue.error('Not authenticated', StackTrace.current);
      return false;
    }

    state = const AsyncValue.loading();

    final result = await action(repository);

    if (!ref.mounted) return false;

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.displayMessage, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        ref.invalidate(stacksProvider);
        ref
            .read(resourceActivityProvider.notifier)
            .markChanged(
              scopes: {ActivityScope.stacks, ActivityScope.containers},
            );
        return true;
      },
    );
  }

  Future<T?> _executeRequest<T>(
    Future<Either<Failure, T>> Function(StackRepository repo) request,
  ) async {
    final repository = ref.read(stackRepositoryProvider);
    if (repository == null) {
      state = AsyncValue.error('Not authenticated', StackTrace.current);
      return null;
    }

    state = const AsyncValue.loading();

    final result = await request(repository);

    if (!ref.mounted) return null;

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.displayMessage, StackTrace.current);
        return null;
      },
      (value) {
        state = const AsyncValue.data(null);
        ref.invalidate(stacksProvider);
        ref
            .read(resourceActivityProvider.notifier)
            .markChanged(
              scopes: {ActivityScope.stacks, ActivityScope.containers},
            );
        return value;
      },
    );
  }
}
