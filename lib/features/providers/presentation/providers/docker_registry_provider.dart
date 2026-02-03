import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/error/provider_error.dart';
import 'package:komodo_go/features/providers/data/models/docker_registry_account.dart';
import 'package:komodo_go/features/providers/data/repositories/docker_registry_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'docker_registry_provider.g.dart';

@riverpod
class DockerRegistryAccounts extends _$DockerRegistryAccounts {
  @override
  Future<List<DockerRegistryAccount>> build() async {
    final repository = ref.watch(dockerRegistryRepositoryProvider);
    if (repository == null) return [];

    final result = await repository.listAccounts();
    final accounts = unwrapOrThrow(result);
    accounts.sort(
      (a, b) => a.domain.compareTo(b.domain) != 0
          ? a.domain.compareTo(b.domain)
          : a.username.compareTo(b.username),
    );
    return accounts;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Exception {
      // Ignore refresh errors.
    }
  }
}

@riverpod
class DockerRegistryActions extends _$DockerRegistryActions {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> create({
    required String domain,
    required String username,
    required String token,
  }) async {
    return _execute(
      (repo) =>
          repo.createAccount(domain: domain, username: username, token: token),
    );
  }

  Future<bool> delete(String id) async {
    return _execute((repo) => repo.deleteAccount(id: id));
  }

  Future<bool> update({
    required DockerRegistryAccount original,
    required String domain,
    required String username,
    required String token,
  }) async {
    final repository = ref.read(dockerRegistryRepositoryProvider);
    if (repository == null) {
      state = AsyncValue.error('Not authenticated', StackTrace.current);
      return false;
    }

    final trimmedDomain = domain.trim();
    final trimmedUsername = username.trim();
    final trimmedToken = token.trim();

    final domainChanged =
        trimmedDomain.isNotEmpty && trimmedDomain != original.domain;
    final usernameChanged =
        trimmedUsername.isNotEmpty && trimmedUsername != original.username;
    final hasToken = trimmedToken.isNotEmpty;

    if (!domainChanged && !usernameChanged && !hasToken) {
      return true;
    }

    state = const AsyncValue.loading();
    final result = await repository.updateAccount(
      id: original.id,
      domain: domainChanged ? trimmedDomain : null,
      username: usernameChanged ? trimmedUsername : null,
      token: hasToken ? trimmedToken : null,
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.displayMessage, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        ref.invalidate(dockerRegistryAccountsProvider);
        return true;
      },
    );
  }

  Future<bool> _execute(
    Future<Either<Failure, DockerRegistryAccount>> Function(
      DockerRegistryRepository repo,
    )
    action,
  ) async {
    final repository = ref.read(dockerRegistryRepositoryProvider);
    if (repository == null) {
      state = AsyncValue.error('Not authenticated', StackTrace.current);
      return false;
    }

    state = const AsyncValue.loading();
    final result = await action(repository);

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.displayMessage, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        ref.invalidate(dockerRegistryAccountsProvider);
        return true;
      },
    );
  }
}
