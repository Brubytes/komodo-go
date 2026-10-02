import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/notifications/data/models/resource_target.dart';
import 'package:komodo_go/features/notifications/data/models/update_detail.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';

void main() {
  test('parses complete update payload, logs, timestamps, and TOML', () {
    final update = UpdateDetail.fromJson(<String, dynamic>{
      'id': 'update-1',
      'operation': 'DeployStack',
      'start_ts': 1700000000000,
      'end_ts': 1700000002500,
      'success': false,
      'operator': 'jan',
      'target': <String, dynamic>{'Stack': 'stack-1'},
      'status': 'Complete',
      'version': <String, dynamic>{'major': 2, 'minor': 3, 'patch': 1},
      'commit_hash': 'abc123',
      'other_data': '{"force":true}',
      'prev_toml': 'old = true',
      'current_toml': 'old = false',
      'logs': <Map<String, dynamic>>[
        <String, dynamic>{
          'stage': 'Deploy',
          'command': 'docker compose up -d',
          'stdout': 'starting',
          'stderr': 'failed',
          'success': false,
          'start_ts': 1700000000000,
          'end_ts': 1700000002500,
        },
      ],
    });

    expect(update.id, 'update-1');
    expect(update.status, UpdateStatus.failed);
    expect(update.target?.type, ResourceTargetType.stack);
    expect(update.target?.id, 'stack-1');
    expect(update.duration, const Duration(milliseconds: 2500));
    expect(update.logs.single.stage, 'Deploy');
    expect(update.logs.single.duration, const Duration(milliseconds: 2500));
    expect(update.logs.single.stderr, 'failed');
    expect(update.previousToml, 'old = true');
    expect(update.currentToml, 'old = false');
    expect(update.version.label, '2.3.1');
  });

  test('supports mongo id and missing optional fields', () {
    final update = UpdateDetail.fromJson(<String, dynamic>{
      '_id': <String, dynamic>{r'$oid': 'mongo-id'},
      'operation': 'RunAction',
      'start_ts': 1,
      'success': true,
      'status': 'Complete',
    });

    expect(update.id, 'mongo-id');
    expect(update.status, UpdateStatus.success);
    expect(update.endTs, isNull);
    expect(update.duration, isNull);
    expect(update.logs, isEmpty);
  });
}
