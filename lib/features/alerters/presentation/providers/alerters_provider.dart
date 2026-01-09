import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/alerters/data/models/alerter_list_item.dart';
import 'package:komodo_go/features/alerters/data/repositories/alerter_repository.dart';

part 'alerters_provider.g.dart';

@riverpod
class Alerters extends _$Alerters {
  @override
  Future<List<AlerterListItem>> build() async {
    final repository = ref.watch(alerterRepositoryProvider);
    if (repository == null) return [];

    final result = await repository.listAlerters();
    return result.fold(
      (failure) => throw Exception(failure.displayMessage),
      (items) => items..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

@riverpod
Future<Map<String, dynamic>?> alerterJson(
  Ref ref,
  String alerterIdOrName,
) async {
  final repository = ref.watch(alerterRepositoryProvider);
  if (repository == null) return null;

  final result = await repository.getAlerterJson(
    alerterIdOrName: alerterIdOrName,
  );
  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (json) => json,
  );
}

@riverpod
class AlerterActions extends _$AlerterActions {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> rename({required String id, required String name}) async {
    return _execute((repo) => repo.renameAlerter(id: id, name: name));
  }

  Future<bool> delete({required String id}) async {
    return _execute((repo) => repo.deleteAlerter(id: id));
  }

  Future<bool> setEnabled({required String id, required bool enabled}) async {
    return _execute((repo) => repo.setEnabled(id: id, enabled: enabled));
  }

  Future<bool> updateConfig({
    required String id,
    required Map<String, dynamic> config,
  }) async {
    return _execute((repo) => repo.updateAlerterConfig(id: id, config: config));
  }

  Future<bool> test({required String idOrName}) async {
    return _execute((repo) => repo.testAlerter(idOrName: idOrName));
  }

  Future<bool> _execute(
    Future<Either<Failure, void>> Function(AlerterRepository repo) action,
  ) async {
    final repository = ref.read(alerterRepositoryProvider);
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
        ref.invalidate(alertersProvider);
        return true;
      },
    );
  }
}
