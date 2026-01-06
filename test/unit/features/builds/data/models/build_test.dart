import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';

void main() {
  group('Build', () {
    test('parses list item payload (BuildListItem)', () {
      final build = BuildListItem.fromJson({
        'id': 'b1',
        'name': 'api-build',
        'tags': ['prod'],
        'info': {
          'state': 'Ok',
          'last_built_at': 1,
          'version': {'major': 1, 'minor': 2, 'patch': 3},
          'builder_id': 'builder-1',
          'repo': 'acme/api',
          'branch': 'main',
          'built_hash': 'deadbeef',
          'latest_hash': 'cafebabe',
        },
      });

      expect(build.id, 'b1');
      expect(build.name, 'api-build');
      expect(build.info.state, BuildState.ok);
      expect(build.info.version.label, '1.2.3');
      expect(build.info.repo, 'acme/api');
    });

    test('parses detail payload (Build)', () {
      final build = KomodoBuild.fromJson({
        '_id': {r'$oid': 'abc123'},
        'name': 'api-build',
        'config': {
          'builder_id': 'builder-1',
          'version': {'major': 1, 'minor': 2, 'patch': 3},
          'image_name': 'ghcr.io/acme/api',
          'image_tag': 'latest',
          'repo': 'acme/api',
          'branch': 'main',
          'webhook_enabled': true,
        },
        'info': {
          'last_built_at': 1,
          'built_hash': 'deadbeef',
          'latest_hash': 'cafebabe',
          'remote_error': '',
        },
      });

      expect(build.id, 'abc123');
      expect(build.config.builderId, 'builder-1');
      expect(build.config.version.label, '1.2.3');
      expect(build.config.webhookEnabled, isTrue);
      expect(build.info.builtHash, 'deadbeef');
    });
  });
}

