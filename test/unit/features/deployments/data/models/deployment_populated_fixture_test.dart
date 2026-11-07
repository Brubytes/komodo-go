import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';

import '../../../../../support/fixtures.dart';

void main() {
  group('Deployment (captured Komodo 2.3.1 response)', () {
    test('build-sourced deployment keeps the tagged image object', () {
      final deployment = Deployment.fromJson(
        loadKomodoFixture('get_deployment_build_source'),
      );

      final image = deployment.config!.image as Map<dynamic, dynamic>;
      expect(image['type'], 'Build');
      expect(
        (image['params'] as Map<dynamic, dynamic>)['build_id'],
        '6aef181156835308d22938c8',
      );
      expect(deployment.config!.restart, 'on-failure');
      expect(deployment.config!.terminationSignal, 'SIGINT');
      // No image name exists for build-sourced deployments.
      expect(deployment.imageLabel, '');
    });
  });
}
