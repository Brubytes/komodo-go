import 'package:dio/dio.dart';

import 'api_exception.dart';

/// RPC request structure for Komodo API.
class RpcRequest<T> {
  const RpcRequest({
    required this.type,
    required this.params,
  });

  final String type;
  final T params;

  Map<String, dynamic> toJson() => {
        'type': type,
        'params': params,
      };
}

/// Client for interacting with the Komodo API.
///
/// Komodo uses an RPC-like API where all requests are POST requests
/// to module endpoints (/auth, /read, /write, /execute) with a JSON body
/// containing the operation type and parameters.
class KomodoApiClient {
  KomodoApiClient(this._dio);

  final Dio _dio;

  /// Sends a request to the auth module.
  Future<Map<String, dynamic>> auth(RpcRequest<dynamic> request) =>
      _post('/auth', request);

  /// Sends a request to the read module.
  Future<Map<String, dynamic>> read(RpcRequest<dynamic> request) =>
      _post('/read', request);

  /// Sends a request to the write module.
  Future<Map<String, dynamic>> write(RpcRequest<dynamic> request) =>
      _post('/write', request);

  /// Sends a request to the execute module.
  Future<Map<String, dynamic>> execute(RpcRequest<dynamic> request) =>
      _post('/execute', request);

  Future<Map<String, dynamic>> _post(
    String path,
    RpcRequest<dynamic> request,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: request.toJson(),
      );
      return response.data ?? {};
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
