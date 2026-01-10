import 'package:komodo_go/core/error/provider_error.dart';
import 'package:komodo_go/features/containers/data/models/container_log.dart';
import 'package:komodo_go/features/containers/data/repositories/container_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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

  return unwrapOrThrow(result);
}
