import 'resource_flows/stacks_destroy_test.dart' as stacks_destroy;
import 'resource_flows/stacks_list_loads_test.dart' as stacks_list_loads;
import 'resource_flows/deployments_destroy_test.dart' as deployments_destroy;
import 'resource_flows/tags_crud_test.dart' as tags_crud;
import 'unhappy/login_unreachable_server_test.dart' as login_unreachable;

void main() {
  // Keep this file as the single entrypoint for `patrol test`.
  // Each test file also remains runnable standalone.
  stacks_destroy.registerStacksDestroyTests();
  stacks_list_loads.registerStacksListLoadsTests();
  deployments_destroy.registerDeploymentsDestroyTests();
  tags_crud.registerTagsCrudTests();
  login_unreachable.registerLoginUnreachableServerTests();
}
