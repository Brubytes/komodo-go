import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';

void main() {
  group('ResourceSync', () {
    test('parses list item payload (ResourceSyncListItem)', () {
      final sync = ResourceSyncListItem.fromJson({
        'id': 's1',
        'name': 'sync-prod',
        'info': {
          'repo': 'acme/api',
          'branch': 'main',
          'resource_path': ['deployments'],
          'state': 'Ok',
          'last_sync_ts': 1,
        },
      });

      expect(sync.id, 's1');
      expect(sync.name, 'sync-prod');
      expect(sync.info.repo, 'acme/api');
      expect(sync.info.branch, 'main');
      expect(sync.info.resourcePath, ['deployments']);
      expect(sync.info.state, ResourceSyncState.ok);
      expect(sync.info.lastSyncTs, 1);
    });

    test('parses detail payload (ResourceSync)', () {
      final sync = KomodoResourceSync.fromJson({
        '_id': {r'$oid': 'abc123'},
        'name': 'sync-prod',
        'config': {
          'repo': 'acme/api',
          'branch': 'main',
          'webhook_enabled': true,
          'resource_path': ['deployments'],
          'managed': true,
          'delete': false,
          'file_contents': 'some config',
        },
        'info': {
          'last_sync_ts': 1,
          'last_sync_hash': 'deadbeef',
          'pending_error': '',
        },
      });

      expect(sync.id, 'abc123');
      expect(sync.config.repo, 'acme/api');
      expect(sync.config.branch, 'main');
      expect(sync.config.webhookEnabled, isTrue);
      expect(sync.config.resourcePath, ['deployments']);
      expect(sync.info.lastSyncTs, 1);
      expect(sync.info.lastSyncHash, 'deadbeef');
    });
  });
}
