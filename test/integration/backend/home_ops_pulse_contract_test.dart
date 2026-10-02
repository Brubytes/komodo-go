import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/composition/home/home_ops_pulse.dart';
import 'package:komodo_go/features/actions/data/repositories/action_repository.dart';
import 'package:komodo_go/features/builds/data/repositories/build_repository.dart';
import 'package:komodo_go/features/deployments/data/repositories/deployment_repository.dart';
import 'package:komodo_go/features/procedures/data/repositories/procedure_repository.dart';
import 'package:komodo_go/features/repos/data/repositories/repo_repository.dart';
import 'package:komodo_go/features/stacks/data/repositories/stack_repository.dart';
import 'package:komodo_go/features/syncs/data/repositories/sync_repository.dart';

import '../../support/backend_test_config.dart';
import '../../support/backend_test_helpers.dart';

void main() {
  final config = BackendTestConfig.fromEnvironment();
  final missingConfigReason = config == null
      ? 'Set KOMODO_TEST_BASE_URL, KOMODO_TEST_API_KEY, and '
            'KOMODO_TEST_API_SECRET to run backend tests.'
      : null;

  test(
    'Ops pulse represents every listed non-template resource (real backend)',
    () async {
      final client = buildTestClient(requireConfig(config), RpcRecorder());
      final deployments = expectRight(
        await DeploymentRepository(client).listDeployments(),
      );
      final stacks = expectRight(await StackRepository(client).listStacks());
      final builds = expectRight(await BuildRepository(client).listBuilds());
      final repos = expectRight(await RepoRepository(client).listRepos());
      final procedures = expectRight(
        await ProcedureRepository(client).listProcedures(),
      );
      final actions = expectRight(await ActionRepository(client).listActions());
      final syncs = expectRight(await SyncRepository(client).listSyncs());

      final snapshot = buildHomeOpsSnapshot(
        deployments: deployments,
        stacks: stacks,
        builds: builds,
        repos: repos,
        procedures: procedures,
        actions: actions,
        syncs: syncs,
      );
      final expectedTotal =
          deployments.where((item) => !item.template).length +
          stacks.where((item) => !item.template).length +
          builds.where((item) => !item.template).length +
          repos.where((item) => !item.template).length +
          procedures.where((item) => !item.template).length +
          actions.where((item) => !item.template).length +
          syncs.where((item) => !item.template).length;

      expect(snapshot.totalResources, expectedTotal);
      expect(
        HomeOpsTone.values.fold(
          0,
          (sum, tone) => sum + snapshot.count(tone),
        ),
        expectedTotal,
      );
    },
    skip: missingConfigReason,
  );
}
