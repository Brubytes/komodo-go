import 'action_contract_test.dart';
import 'alerter_contract_test.dart';
import 'auth_contract_test.dart';
import 'build_contract_test.dart';
import 'builder_contract_test.dart';
import 'deployment_contract_test.dart';
import 'providers_contract_test.dart';
import 'repo_contract_test.dart';
import 'server_contract_test.dart';
import 'stack_contract_test.dart';
import 'sync_contract_test.dart';
import 'tag_contract_test.dart';
import 'variable_contract_test.dart';
import 'procedure_contract_test.dart';

void main() {
  registerActionContractTests();
  registerAlerterContractTests();
  registerAuthContractTests();
  registerBuildContractTests();
  registerBuilderContractTests();
  registerDeploymentContractTests();
  registerProviderContractTests();
  registerRepoContractTests();
  registerServerContractTests();
  registerTagContractTests();
  registerVariableContractTests();
  registerStackContractTests();
  registerSyncContractTests();
  registerProcedureContractTests();
}
