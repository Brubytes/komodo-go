import 'package:dio/dio.dart';

import 'api_exception.dart';

/// RPC request structure for Komodo API.
class RpcRequest<T> {
  const RpcRequest({required this.type, required this.params});

  final String type;
  final T params;

  Map<String, dynamic> toJson() => {'type': type, 'params': params};
}

/// Client for interacting with the Komodo API.
///
/// Komodo uses an RPC-like API where all requests are POST requests
/// to module endpoints (/auth, /read, /write, /execute) with a JSON body
/// containing the operation type and parameters.
///
/// Note: The API can return either a Map or a List depending on the endpoint.
/// - Single object endpoints return Map<String, dynamic>
/// - List endpoints return List<dynamic> directly
class KomodoApiClient {
  KomodoApiClient(this._dio);

  final Dio _dio;

  /// Sends a request to the auth module.
  Future<dynamic> auth(RpcRequest<dynamic> request) => _post('/auth', request);

  /// Sends a request to the read module.
  Future<dynamic> read(RpcRequest<dynamic> request) => _post('/read', request);

  /// Sends a request to the write module.
  Future<dynamic> write(RpcRequest<dynamic> request) =>
      _post('/write', request);

  /// Sends a request to the execute module.
  Future<dynamic> execute(RpcRequest<dynamic> request) =>
      _post('/execute', request);

  Future<dynamic> _post(String path, RpcRequest<dynamic> request) async {
    try {
      final response = await _dio.post<dynamic>(path, data: request.toJson());
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
