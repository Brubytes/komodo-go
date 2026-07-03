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
          'state': 'running',
          'linked_repo': 'linked-repo-1',
          'branch': 'main',
        },
      });

      expect(stack.id, 's1');
      expect(stack.name, 'media-stack');
      expect(stack.info.serverId, 'server-1');
      expect(stack.info.linkedRepo, 'linked-repo-1');
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
