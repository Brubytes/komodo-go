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
          'server_name': 'alpha',
          'swarm_id': 'swarm-1',
          'swarm_name': 'primary',
          'custom_name': 'web-custom',
          'deployed_name': 'web-custom',
        },
      });

      expect(deployment.id, 'd1');
      expect(deployment.name, 'web');
      expect(deployment.tags, ['prod']);
      expect(deployment.info?.state, DeploymentState.running);
      expect(deployment.info?.serverName, 'alpha');
      expect(deployment.info?.swarmName, 'primary');
      expect(deployment.info?.customName, 'web-custom');
      expect(deployment.info?.deployedName, 'web-custom');
      expect(deployment.imageLabel, 'nginx:latest');
      expect(deployment.config, isNull);
    });

    test('parses detail payload (Deployment) and derives image label', () {
      final deployment = Deployment.fromJson({
        '_id': {r'$oid': 'abc123'},
        'name': 'api',
        'config': {
          'server_id': 's1',
          'swarm_id': 'swarm-1',
          'custom_name': 'api-custom',
          'image': {
            'Image': {'image': 'ghcr.io/acme/api:1.2.3'},
          },
        },
      });

      expect(deployment.id, 'abc123');
      expect(deployment.config?.serverId, 's1');
      expect(deployment.config?.swarmId, 'swarm-1');
      expect(deployment.config?.customName, 'api-custom');
      expect(deployment.imageLabel, 'ghcr.io/acme/api:1.2.3');
    });
  });
}
