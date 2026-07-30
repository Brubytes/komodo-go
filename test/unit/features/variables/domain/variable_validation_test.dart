import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/variables/domain/variable_validation.dart';

void main() {
  test('accepts Komodo v2.3 variable identifiers', () {
    expect(validateVariableName('DEPLOY_TOKEN_2'), isNull);
    expect(validateVariableName('_private'), isNull);
  });

  test('rejects spaces, hyphens, numeric starts, and overlong names', () {
    expect(validateVariableName('DEPLOY TOKEN'), isNotNull);
    expect(validateVariableName('deploy-token'), isNotNull);
    expect(validateVariableName('2_DEPLOY'), isNotNull);
    expect(validateVariableName(List.filled(501, 'A').join()), isNotNull);
  });
}
