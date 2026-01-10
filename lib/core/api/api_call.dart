import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/error/failures.dart';

typedef ApiAction<T> = Future<T> Function();
typedef ApiExceptionMapper = Failure Function(ApiException error);
typedef DioExceptionMapper = Failure Function(DioException error);

Future<Either<Failure, T>> apiCall<T>(
  ApiAction<T> action, {
  ApiExceptionMapper? onApiException,
  DioExceptionMapper? onDioException,
  Failure Function(Object error)? onUnknown,
}) async {
  try {
    final result = await action();
    return Right(result);
  } on ApiException catch (e) {
    if (onApiException != null) {
      return Left(onApiException(e));
    }
    if (e.isUnauthorized) {
      return const Left(Failure.auth());
    }
    return Left(Failure.server(message: e.message, statusCode: e.statusCode));
  } on DioException catch (e) {
    if (onDioException != null) {
      return Left(onDioException(e));
    }
    return const Left(
      Failure.network(message: 'Could not connect to server'),
    );
  } on Object catch (e) {
    if (e is Failure) {
      return Left(e);
    }
    if (onUnknown != null) {
      return Left(onUnknown(e));
    }
    return Left(Failure.unknown(message: e.toString()));
  }
}
