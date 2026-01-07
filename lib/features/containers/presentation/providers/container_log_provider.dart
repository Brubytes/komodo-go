import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../data/models/container_log.dart';
import '../../data/repositories/container_repository.dart';

part 'container_log_provider.g.dart';

@riverpod
Future<ContainerLog?> containerLog(
  Ref ref, {
  required String serverIdOrName,
  required String containerIdOrName,
}) async {
  final repository = ref.watch(containerRepositoryProvider);
  if (repository == null) return null;

  final result = await repository.getContainerLog(
    serverIdOrName: serverIdOrName,
    containerIdOrName: containerIdOrName,
  );

  return result.fold(
    (failure) => throw Exception(failure.displayMessage),
    (log) => log,
  );
}
