import 'package:dio/dio.dart';

/// Exception thrown when an API request fails.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.trace,
  });

  /// Creates an [ApiException] from a [DioException].
  factory ApiException.fromDioException(DioException error) {
    final response = error.response;

    // Try to parse Komodo error response format
    if (response?.data is Map<String, dynamic>) {
      final data = response!.data as Map<String, dynamic>;
      final errorMessage = data['error'] as String? ?? 'Unknown error';
      final trace = (data['trace'] as List<dynamic>?)?.cast<String>();

      return ApiException(
        message: errorMessage,
        statusCode: response.statusCode,
        trace: trace?.join('\n'),
      );
    }

    // Handle different DioException types
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        const ApiException(message: 'Connection timed out'),
      DioExceptionType.connectionError =>
        const ApiException(message: 'Could not connect to server'),
      DioExceptionType.badResponse => ApiException(
          message: 'Server error: ${response?.statusCode}',
          statusCode: response?.statusCode,
        ),
      DioExceptionType.cancel =>
        const ApiException(message: 'Request cancelled'),
      _ => ApiException(
          message: error.message ?? 'Unknown network error',
        ),
    };
  }

  final String message;
  final int? statusCode;
  final String? trace;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode != null && statusCode! >= 500;

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}
