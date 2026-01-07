import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/api_exception.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/features/notifications/data/models/alert.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notifications_repository.g.dart';

class AlertsPage {
  const AlertsPage({required this.alerts, required this.nextPage});

  final List<Alert> alerts;
  final int? nextPage;
}

class UpdatesPage {
  const UpdatesPage({required this.updates, required this.nextPage});

  final List<UpdateListItem> updates;
  final int? nextPage;
}

class NotificationsRepository {
  NotificationsRepository(this._client);

  final KomodoApiClient _client;

  Future<Either<Failure, AlertsPage>> listAlerts({
    required int page,
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _client.read(
        RpcRequest(
          type: 'ListAlerts',
          params: <String, dynamic>{'query': query, 'page': page},
        ),
      );

      if (response is! Map) {
        return const Right(AlertsPage(alerts: <Alert>[], nextPage: null));
      }

      final map = response.cast<String, dynamic>();
      final alertsJson = (map['alerts'] as List<dynamic>?) ?? <dynamic>[];
      final alerts = [
        for (final item in alertsJson)
          if (item is Map) Alert.fromJson(item.cast<String, dynamic>()),
      ];
      final nextPage = _readNullableInt(map['next_page']);
      return Right(AlertsPage(alerts: alerts, nextPage: nextPage));
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }

  Future<Either<Failure, UpdatesPage>> listUpdates({
    required int page,
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _client.read(
        RpcRequest(
          type: 'ListUpdates',
          params: <String, dynamic>{'query': query, 'page': page},
        ),
      );

      if (response is! Map) {
        return const Right(
          UpdatesPage(updates: <UpdateListItem>[], nextPage: null),
        );
      }

      final map = response.cast<String, dynamic>();
      final updatesJson = (map['updates'] as List<dynamic>?) ?? <dynamic>[];
      final updates = [
        for (final item in updatesJson)
          if (item is Map)
            UpdateListItem.fromJson(item.cast<String, dynamic>()),
      ];
      final nextPage = _readNullableInt(map['next_page']);
      return Right(UpdatesPage(updates: updates, nextPage: nextPage));
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(Failure.auth());
      }
      return Left(Failure.server(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(Failure.unknown(message: e.toString()));
    }
  }
}

int? _readNullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

@riverpod
NotificationsRepository? notificationsRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    return null;
  }
  return NotificationsRepository(client);
}
