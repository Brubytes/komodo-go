import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';

void main() {
  group('Deployment', () {
    test('parses list item payload (DeploymentListItem)', () {
      final deployment = Deployment.fromJson({
        'id': 'd1',
        'name': 'web',
        'tags': ['prod'],
        'info': {
          'state': 'running',
          'image': 'nginx:latest',
          'update_available': true,
          'server_id': 's1',
        },
      });

      expect(deployment.id, 'd1');
      expect(deployment.name, 'web');
      expect(deployment.tags, ['prod']);
      expect(deployment.info?.state, DeploymentState.running);
      expect(deployment.imageLabel, 'nginx:latest');
      expect(deployment.config, isNull);
    });

    test('parses detail payload (Deployment) and derives image label', () {
      final deployment = Deployment.fromJson({
        '_id': {r'$oid': 'abc123'},
        'name': 'api',
        'config': {
          'server_id': 's1',
          'image': {
            'Image': {'image': 'ghcr.io/acme/api:1.2.3'},
          },
        },
      });

      expect(deployment.id, 'abc123');
      expect(deployment.config?.serverId, 's1');
      expect(deployment.imageLabel, 'ghcr.io/acme/api:1.2.3');
    });
  });
}
