import 'resource_flows/actions_run_test.dart' as actions_run;
import 'resource_flows/builds_run_cancel_test.dart' as builds_run_cancel;
import 'resource_flows/containers_logs_actions_test.dart'
    as containers_logs_actions;
import 'resource_flows/deployments_deploy_test.dart' as deployments_deploy;
import 'resource_flows/deployments_destroy_test.dart' as deployments_destroy;
import 'resource_flows/procedures_run_test.dart' as procedures_run;
import 'resource_flows/repos_pull_test.dart' as repos_pull;
import 'resource_flows/servers_detail_test.dart' as servers_detail;
import 'resource_flows/stacks_deploy_test.dart' as stacks_deploy;
import 'resource_flows/stacks_destroy_test.dart' as stacks_destroy;
import 'resource_flows/stacks_list_loads_test.dart' as stacks_list_loads;
import 'resource_flows/stacks_services_logs_test.dart' as stacks_services_logs;
import 'resource_flows/syncs_run_test.dart' as syncs_run;
import 'resource_flows/tags_crud_test.dart' as tags_crud;
import 'unhappy/login_unauthorized_test.dart' as login_unauthorized;
import 'unhappy/login_unreachable_server_test.dart' as login_unreachable;
import 'unhappy/stack_not_found_test.dart' as stack_not_found;

void main() {
  // Keep this file as the single entrypoint for `patrol test`.
  // Each test file also remains runnable standalone.
  stacks_destroy.registerStacksDestroyTests();
  stacks_list_loads.registerStacksListLoadsTests();
  stacks_services_logs.registerStacksServicesLogsTests();
  stacks_deploy.registerStacksDeployTests();
  deployments_destroy.registerDeploymentsDestroyTests();
  deployments_deploy.registerDeploymentsDeployTests();
  repos_pull.registerReposPullTests();
  syncs_run.registerSyncsRunTests();
  tags_crud.registerTagsCrudTests();
  servers_detail.registerServersDetailTests();
  builds_run_cancel.registerBuildsRunCancelTests();
  procedures_run.registerProceduresRunTests();
  actions_run.registerActionsRunTests();
  containers_logs_actions.registerContainersLogsActionsTests();
  login_unreachable.registerLoginUnreachableServerTests();
  login_unauthorized.registerLoginUnauthorizedTests();
  stack_not_found.registerStackNotFoundTests();
}
