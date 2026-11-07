import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';

void main() {
  group('SyncDiffData names (captured Komodo 2.3.1 shapes)', () {
    test('Create carries an explicit name', () {
      final diff = ResourceSyncDiff.fromJson({
        'target': {'type': 'Stack', 'id': ''},
        'data': {
          'type': 'Create',
          'data': {
            'name': 'new-stack',
            'proposed': '[[stack]]\nname = "new-stack"\n[stack.config]\n',
          },
        },
      });

      expect(diff.data.operation, SyncDiffOperation.create);
      expect(diff.name, 'new-stack');
    });

    test('Update has no name; it is read from the TOML', () {
      final diff = ResourceSyncDiff.fromJson({
        'target': {'type': 'Deployment', 'id': '6aef181256835308d22938d2'},
        'data': {
          'type': 'Update',
          'data': {
            'proposed': '[[deployment]]\nname = "web"\n[deployment.config]\n',
            'current': '[[deployment]]\nname = "web"\ntags = ["t"]\n',
          },
        },
      });

      expect(diff.data.operation, SyncDiffOperation.update);
      expect(diff.name, 'web');
    });

    test('Delete has only `current`; name comes from the TOML', () {
      final diff = ResourceSyncDiff.fromJson({
        'target': {'type': 'Server', 'id': '697519a44d3b178d5a7e2f84'},
        'data': {
          'type': 'Delete',
          'data': {
            'current': '[[server]]\nname = "local"\n[server.config]\n',
          },
        },
      });

      expect(diff.data.operation, SyncDiffOperation.delete);
      expect(diff.name, 'local');
    });

    test('falls back to the target id when no name can be found', () {
      final diff = ResourceSyncDiff.fromJson({
        'target': {'type': 'Server', 'id': 'abc'},
        'data': {
          'type': 'Delete',
          'data': {'current': 'nothing here'},
        },
      });

      expect(diff.name, 'abc');
    });

    test('variable and user group diffs resolve names too', () {
      final variable = SyncDiffData.fromJson({
        'type': 'Delete',
        'data': {
          'current': '[[variable]]\nname = "TEST"\nvalue = "a"\n',
        },
      });
      final group = SyncDiffData.fromJson({
        'type': 'Create',
        'data': {
          'name': 'g',
          'proposed': '[[user_group]]\nname = "g"\n',
        },
      });

      expect(variable.name, 'TEST');
      expect(group.name, 'g');
    });
  });
}
