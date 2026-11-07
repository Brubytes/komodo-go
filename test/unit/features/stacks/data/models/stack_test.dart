import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';

void main() {
  group('Stack', () {
    test('parses list item payload (StackListItem)', () {
      final stack = StackListItem.fromJson({
        'id': 's1',
        'name': 'media-stack',
        'tags': ['prod'],
        'info': {
          'server_id': 'server-1',
          'server_name': 'alpha',
          'swarm_id': 'swarm-1',
          'swarm_name': 'primary',
          'state': 'running',
          'linked_repo': 'linked-repo-1',
          'linked_repo_name': 'infrastructure',
          'branch': 'main',
        },
      });

      expect(stack.id, 's1');
      expect(stack.name, 'media-stack');
      expect(stack.info.serverId, 'server-1');
      expect(stack.info.serverName, 'alpha');
      expect(stack.info.swarmName, 'primary');
      expect(stack.info.linkedRepo, 'linked-repo-1');
      expect(stack.info.linkedRepoName, 'infrastructure');
    });

    test('parses v2.3 stack service identity and state', () {
      final service = StackService.fromJson({
        'stack_id': 'stack-1',
        'stack_name': 'media',
        'service': 'web',
        'state': 'Running',
        'swarm_service': <String, dynamic>{'id': 'service-1'},
      });

      expect(service.stackId, 'stack-1');
      expect(service.stackName, 'media');
      expect(service.state, 'Running');
      expect(service.swarmService, isA<Map<String, dynamic>>());
    });

    test('reports Git source for linked-repo stacks', () {
      final stack = StackListItem.fromJson({
        'id': 's1',
        'name': 'media-stack',
        'info': {
          'linked_repo': 'linked-repo-1',
        },
      });

      expect(stack.sourceLabel, 'Git');
    });
  });

  group('StackAdditionalEnvFile', () {
    test('parses 2.x object entries', () {
      final config = StackConfig.fromJson({
        'additional_env_files': [
          {'path': 'extra.env', 'track': true},
          {'path': 'local.env', 'track': false},
        ],
      });
      expect(config.additionalEnvFiles, const [
        StackAdditionalEnvFile(path: 'extra.env'),
        StackAdditionalEnvFile(path: 'local.env', track: false),
      ]);
    });

    test('parses legacy string entries as tracked', () {
      final config = StackConfig.fromJson({
        'additional_env_files': ['extra.env'],
      });
      expect(config.additionalEnvFiles, const [
        StackAdditionalEnvFile(path: 'extra.env'),
      ]);
    });

    test('skips unparseable entries without throwing', () {
      final config = StackConfig.fromJson({
        'additional_env_files': [
          1,
          null,
          {'track': true},
          {'path': 5},
          {'path': 'ok.env', 'track': 'yes'},
        ],
      });
      expect(config.additionalEnvFiles, const [
        StackAdditionalEnvFile(path: 'ok.env'),
      ]);
    });

    test('parses a realistic 2.x GetStack payload', () {
      final stack = KomodoStack.fromJson({
        '_id': {r'$oid': '695d542f7f312f61ae431362'},
        'name': 'hello-world',
        'description': '',
        'template': false,
        'tags': <String>[],
        'info': {
          'missing_files': <String>[],
          'deployed_project_name': 'librespeed',
          'deployed_hash': null,
          'deployed_message': null,
          'deployed_contents': [
            {'path': 'compose.yaml', 'contents': 'services: {}'},
          ],
          'deployed_services': [
            {
              'service_name': 'hello_world',
              'container_name': 'librespeed-hello_world',
              'image': 'hello-world',
              'image_digest': null,
            },
          ],
          'deployed_config': 'name: librespeed\n',
          'remote_contents': null,
          'remote_errors': null,
          'latest_hash': null,
          'latest_message': null,
        },
        'config': {
          'swarm_id': '',
          'server_id': '',
          'links': ['https://x'],
          'project_name': '',
          'auto_pull': true,
          'run_build': false,
          'file_paths': ['compose.yaml'],
          'env_file_path': '.env',
          'additional_env_files': [
            {'path': 'extra.env', 'track': true},
          ],
          'config_files': [
            {'path': 'a.conf'},
          ],
          'pre_deploy': {'path': '', 'command': '', 'shell_mode': false},
          'ignore_services': ['x'],
          'file_contents': 'services: {}',
          'environment': '',
        },
        'base_permission': 'None',
        'updated_at': 1767724165313,
      });

      expect(stack.id, '695d542f7f312f61ae431362');
      expect(stack.config.additionalEnvFiles, const [
        StackAdditionalEnvFile(path: 'extra.env'),
      ]);
      expect(stack.config.configFiles.single.path, 'a.conf');
      expect(stack.config.filePaths, ['compose.yaml']);
    });
  });
}
