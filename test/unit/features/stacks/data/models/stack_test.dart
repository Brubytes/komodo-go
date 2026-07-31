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
}
