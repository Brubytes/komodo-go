import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';

void main() {
  group('Server', () {
    test(r'parses id from `_id.$oid`', () {
      final server = Server.fromJson({
        '_id': {r'$oid': 'abc123'},
        'name': 'server-1',
        'info': {'state': 'Ok', 'address': '10.0.0.1'},
      });

      expect(server.id, 'abc123');
      expect(server.name, 'server-1');
      expect(server.info?.state, ServerState.ok);
      expect(server.address, '10.0.0.1');
    });

    test('parses id from `id` and handles missing optional fields', () {
      final server = Server.fromJson({
        'id': 'id-1',
        'name': 'server-2',
        'info': {'state': 'NotOk'},
      });

      expect(server.id, 'id-1');
      expect(server.description, isNull);
      expect(server.tags, isEmpty);
      expect(server.template, isFalse);
      expect(server.info?.state, ServerState.notOk);
      expect(server.info?.version, '');
    });

    test('parses server state variants', () {
      expect(
        ServerInfo.fromJson({'state': 'Disabled'}).state,
        ServerState.disabled,
      );
      expect(ServerInfo.fromJson({'state': 'ok'}).state, ServerState.ok);
      expect(
        ServerInfo.fromJson({'state': 'unknown_value'}).state,
        ServerState.unknown,
      );
    });
  });
}
