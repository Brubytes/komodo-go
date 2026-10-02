import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/shared/resources/data/update_control_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements KomodoApiClient {}

class _FakeRpcRequest extends Fake implements RpcRequest<dynamic> {}

void main() {
  setUpAll(() => registerFallbackValue(_FakeRpcRequest()));

  test('global candidate check suppresses automatic redeployment', () async {
    final client = _MockApiClient();
    final repository = UpdateControlRepository(client);
    when(() => client.execute(any())).thenAnswer(
      (_) async => <String, dynamic>{},
    );

    final result = await repository.checkGlobalCandidates();

    expect(result.isRight(), isTrue);
    final request =
        verify(() => client.execute(captureAny())).captured.single
            as RpcRequest<dynamic>;
    expect(request.type, 'GlobalAutoUpdate');
    expect(request.params, <String, dynamic>{'skip_auto_update': true});
  });
}
