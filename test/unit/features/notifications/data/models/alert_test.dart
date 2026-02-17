import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/notifications/data/models/alert.dart';

void main() {
  group('AlertPayload', () {
    test('parses legacy externally tagged shape', () {
      final payload = AlertPayload.fromJson({
        'ServerUnreachable': {'id': 's1', 'name': 'nas'},
      });

      expect(payload.variant, 'ServerUnreachable');
      expect(payload.data['name'], 'nas');
      expect(payload.displayTitle, 'Server Unreachable');
      expect(payload.primaryName, 'nas');
    });

    test('parses internally tagged shape', () {
      final payload = AlertPayload.fromJson({
        'type': 'ResourceSyncPendingUpdates',
        'data': {'id': 'sync-1', 'name': 'testSync'},
      });

      expect(payload.variant, 'ResourceSyncPendingUpdates');
      expect(payload.data['id'], 'sync-1');
      expect(payload.displayTitle, 'Resource Sync Pending Updates');
      expect(payload.primaryName, 'testSync');
    });

    test('parses flattened tagged shape when nested data is missing', () {
      final payload = AlertPayload.fromJson({
        'type': 'BuildFailed',
        'name': 'build-42',
        'message': 'exit code 1',
      });

      expect(payload.variant, 'BuildFailed');
      expect(payload.data['name'], 'build-42');
      expect(payload.data.containsKey('type'), isFalse);
      expect(payload.primaryName, 'build-42');
    });
  });

  group('Alert', () {
    test('parses backend alert payload with type+data encoding', () {
      final alert = Alert.fromJson({
        '_id': {r'$oid': 'alert-1'},
        'ts': 1736308800,
        'resolved': false,
        'level': 'OK',
        'target': {'ResourceSync': 'sync-1'},
        'data': {
          'type': 'ResourceSyncPendingUpdates',
          'data': {'id': 'sync-1', 'name': 'testSync'},
        },
      });

      expect(alert.id, 'alert-1');
      expect(alert.level, SeverityLevel.ok);
      expect(alert.payload.variant, 'ResourceSyncPendingUpdates');
      expect(alert.payload.primaryName, 'testSync');
      expect(alert.payload.displayTitle, 'Resource Sync Pending Updates');
    });
  });
}
