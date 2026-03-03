import 'package:dio/dio.dart';

/// Exception thrown when an API request fails.
class ApiException implements Exception {
  const ApiException({required this.message, this.statusCode, this.trace});

  /// Creates an [ApiException] from a [DioException].
  factory ApiException.fromDioException(DioException error) {
    final response = error.response;
    final responseData = response?.data;
    final serverMessage = _extractServerMessage(responseData);
    final serverTrace = _extractServerTrace(responseData);

    if (serverMessage != null) {
      return ApiException(
        message: serverMessage,
        statusCode: response?.statusCode,
        trace: serverTrace,
      );
    }

    // Handle different DioException types
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const ApiException(
        message: 'Connection timed out',
      ),
      DioExceptionType.connectionError => const ApiException(
        message: 'Could not connect to server',
      ),
      DioExceptionType.badResponse => ApiException(
        message: _fallbackBadResponseMessage(error),
        statusCode: response?.statusCode,
      ),
      DioExceptionType.cancel => const ApiException(
        message: 'Request cancelled',
      ),
      _ => ApiException(message: error.message ?? 'Unknown network error'),
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

  static String _fallbackBadResponseMessage(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;
    final statusMessage = response?.statusMessage?.trim();

    final dioMessage = error.message?.trim();
    if (dioMessage != null && dioMessage.isNotEmpty) {
      final isOnlyReasonPhrase =
          statusMessage != null &&
          statusMessage.isNotEmpty &&
          dioMessage.toLowerCase() == statusMessage.toLowerCase();
      if (!isOnlyReasonPhrase) {
        return dioMessage;
      }
    }

    if (statusCode != null) {
      final base = statusMessage != null && statusMessage.isNotEmpty
          ? 'HTTP $statusCode $statusMessage'
          : 'HTTP $statusCode';
      final location = response?.headers.value('location')?.trim();
      if (location != null && location.isNotEmpty) {
        return '$base (Location: $location)';
      }
      return base;
    }

    if (statusMessage != null && statusMessage.isNotEmpty) {
      return statusMessage;
    }

    return 'Request failed';
  }

  static String? _extractServerMessage(Object? responseData) {
    if (responseData == null) {
      return null;
    }

    if (responseData is String) {
      final value = responseData.trim();
      return value.isEmpty ? null : value;
    }

    if (responseData is Map) {
      final messageKeys = ['error', 'message', 'detail'];
      for (final key in messageKeys) {
        final value = responseData[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }

    return null;
  }

  static String? _extractServerTrace(Object? responseData) {
    if (responseData is! Map) {
      return null;
    }

    final trace = responseData['trace'];
    if (trace is List) {
      final lines = trace
          .whereType<String>()
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      if (lines.isNotEmpty) {
        return lines.join('\n');
      }
    }

    return null;
  }
}
