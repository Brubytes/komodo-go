import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';

void main() {
  group('UpdateListItem', () {
    UpdateListItem parse({required String status, required bool success}) =>
        UpdateListItem.fromJson({
          'id': 'u1',
          'operation': 'DeployStack',
          'start_ts': 1700000000000,
          'success': success,
          'username': 'admin',
          'operator': 'admin',
          'status': status,
          'version': {'major': 0, 'minor': 0, 'patch': 0},
        });

    test('parses Komodo UpdateStatus strings (Queued/InProgress)', () {
      expect(
        parse(status: 'Queued', success: false).status,
        UpdateStatus.queued,
      );
      expect(
        parse(status: 'InProgress', success: false).status,
        UpdateStatus.running,
      );
      expect(
        parse(status: 'In_Progress', success: false).status,
        UpdateStatus.running,
      );
    });

    test('derives success/failure from Complete + success flag', () {
      expect(
        parse(status: 'Complete', success: true).status,
        UpdateStatus.success,
      );
      expect(
        parse(status: 'Complete', success: false).status,
        UpdateStatus.failed,
      );
    });

    test('unknown status values fall back to unknown', () {
      expect(
        parse(status: 'SomethingNew', success: true).status,
        UpdateStatus.unknown,
      );
    });
  });
}
