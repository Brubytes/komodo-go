import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';

void main() {
  group('Repo', () {
    test('parses list item payload (RepoListItem)', () {
      final repo = RepoListItem.fromJson({
        'id': 'r1',
        'name': 'app-repo',
        'tags': ['prod'],
        'info': {
          'server_id': 's1',
          'builder_id': 'b1',
          'repo': 'acme/app',
          'branch': 'main',
          'state': 'Ok',
          'last_pulled_at': 1,
          'last_built_at': 2,
        },
      });

      expect(repo.id, 'r1');
      expect(repo.name, 'app-repo');
      expect(repo.tags, ['prod']);
      expect(repo.info.repo, 'acme/app');
      expect(repo.info.branch, 'main');
      expect(repo.info.state, RepoState.ok);
    });

    test('parses detail payload (Repo)', () {
      final repo = KomodoRepo.fromJson({
        '_id': {r'$oid': 'abc123'},
        'name': 'app-repo',
        'config': {
          'server_id': 's1',
          'builder_id': 'b1',
          'repo': 'acme/app',
          'branch': 'main',
          'path': '/opt/app',
          'webhook_enabled': true,
        },
        'info': {
          'last_pulled_at': 1,
          'latest_hash': 'deadbeef',
          'latest_message': 'Commit message',
        },
      });

      expect(repo.id, 'abc123');
      expect(repo.config.serverId, 's1');
      expect(repo.config.repo, 'acme/app');
      expect(repo.config.webhookEnabled, isTrue);
      expect(repo.info.latestHash, 'deadbeef');
    });
  });
}
