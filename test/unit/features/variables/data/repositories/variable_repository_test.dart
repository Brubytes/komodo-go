import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/variables/data/repositories/variable_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements KomodoApiClient {}

class _FakeRpcRequest extends Fake implements RpcRequest<dynamic> {}

T _rightOrFail<T>(Either<Failure, T> result) => result.fold(
  (failure) => fail('Expected Right, got $failure'),
  (value) => value,
);

const _variableJson = <String, dynamic>{
  'name': 'API_KEY',
  'description': 'key',
  'value': 'secret',
  'is_secret': true,
};

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRpcRequest());
  });

  group('VariableRepository', () {
    late _MockApiClient client;
    late VariableRepository repository;

    setUp(() {
      client = _MockApiClient();
      repository = VariableRepository(client);
    });

    RpcRequest<dynamic> capturedRead() =>
        verify(() => client.read(captureAny())).captured.single
            as RpcRequest<dynamic>;

    RpcRequest<dynamic> capturedWrite() =>
        verify(() => client.write(captureAny())).captured.single
            as RpcRequest<dynamic>;

    test('listVariables sends ListVariables with empty params', () async {
      when(() => client.read(any())).thenAnswer((_) async => [_variableJson]);

      final result = await repository.listVariables();

      final variables = _rightOrFail(result);
      expect(variables.single.name, 'API_KEY');
      expect(variables.single.isSecret, isTrue);

      final request = capturedRead();
      expect(request.type, 'ListVariables');
      expect(request.params, <String, dynamic>{});
    });

    test('createVariable sends CreateVariable via write with exact payload',
        () async {
      when(() => client.write(any())).thenAnswer((_) async => _variableJson);

      final result = await repository.createVariable(
        name: 'API_KEY',
        value: 'secret',
        description: 'key',
        isSecret: true,
      );

      expect(_rightOrFail(result).name, 'API_KEY');

      final request = capturedWrite();
      expect(request.type, 'CreateVariable');
      expect(request.params, <String, dynamic>{
        'name': 'API_KEY',
        'value': 'secret',
        'description': 'key',
        'is_secret': true,
      });
      verifyNever(() => client.execute(any()));
    });

    test('deleteVariable sends DeleteVariable via write with name param',
        () async {
      when(() => client.write(any())).thenAnswer((_) async => _variableJson);

      final result = await repository.deleteVariable(name: 'API_KEY');

      expect(_rightOrFail(result).name, 'API_KEY');

      final request = capturedWrite();
      expect(request.type, 'DeleteVariable');
      expect(request.params, <String, dynamic>{'name': 'API_KEY'});
      verifyNever(() => client.execute(any()));
    });

    test('updateVariableValue sends UpdateVariableValue with name and value',
        () async {
      when(() => client.write(any())).thenAnswer((_) async => _variableJson);

      final result = await repository.updateVariableValue(
        name: 'API_KEY',
        value: 'new-secret',
      );

      expect(_rightOrFail(result).name, 'API_KEY');

      final request = capturedWrite();
      expect(request.type, 'UpdateVariableValue');
      expect(request.params, <String, dynamic>{
        'name': 'API_KEY',
        'value': 'new-secret',
      });
    });

    test(
        'updateVariableDescription sends UpdateVariableDescription '
        'with name and description', () async {
      when(() => client.write(any())).thenAnswer((_) async => _variableJson);

      final result = await repository.updateVariableDescription(
        name: 'API_KEY',
        description: 'rotated key',
      );

      expect(_rightOrFail(result).name, 'API_KEY');

      final request = capturedWrite();
      expect(request.type, 'UpdateVariableDescription');
      expect(request.params, <String, dynamic>{
        'name': 'API_KEY',
        'description': 'rotated key',
      });
    });

    test(
        'updateVariableIsSecret sends UpdateVariableIsSecret '
        'with name and is_secret', () async {
      when(() => client.write(any())).thenAnswer((_) async => _variableJson);

      final result = await repository.updateVariableIsSecret(
        name: 'API_KEY',
        isSecret: false,
      );

      expect(_rightOrFail(result).name, 'API_KEY');

      final request = capturedWrite();
      expect(request.type, 'UpdateVariableIsSecret');
      expect(request.params, <String, dynamic>{
        'name': 'API_KEY',
        'is_secret': false,
      });
    });
  });
}
