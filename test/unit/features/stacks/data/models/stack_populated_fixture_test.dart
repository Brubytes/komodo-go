import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';

import '../../../../../support/fixtures.dart';

void main() {
  group('KomodoStack (captured Komodo 2.3.1 response)', () {
    final stack = KomodoStack.fromJson(
      loadKomodoFixture('get_stack_populated'),
    );

    test('additional_env_files object entries keep path and track', () {
      expect(
        stack.config.additionalEnvFiles
            .map((f) => (path: f.path, track: f.track))
            .toList(),
        [(path: '.env.a', track: true), (path: '.env.b', track: false)],
      );
    });

    test('config_files with omitted services/requires use defaults', () {
      final files = stack.config.configFiles;
      expect(files.map((f) => f.path), [
        'conf/a.conf',
        'conf/b.conf',
        'conf/c.conf',
      ]);
      expect(files[0].services, ['web', 'db']);
      expect(files[0].requires, StackFileRequires.redeploy);
      expect(files[1].services, isEmpty);
      expect(files[1].requires, StackFileRequires.restart);
      expect(files[2].requires, StackFileRequires.none);
    });

    test('remaining populated config and info fields', () {
      expect(stack.config.filePaths, ['a.yaml', 'b.yaml']);
      expect(stack.config.ignoreServices, ['db']);
      expect(stack.config.extraArgs, ['--pull', 'always']);
      expect(stack.config.registryProvider, 'ghcr.io');
      expect(stack.config.webhookForceDeploy, isTrue);
      expect(stack.config.clonePath, '/opt/c');
      expect(stack.info.remoteErrors?.single.path, 'Failed at: Clone Repo');
      expect(stack.info.remoteContents, isEmpty);
    });
  });
}
