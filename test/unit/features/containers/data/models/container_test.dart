import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/features/containers/data/models/container.dart';

void main() {
  test('parses the v2.3 server name on container list items', () {
    final container = ContainerListItem.fromJson(<String, dynamic>{
      'server_id': 'server-1',
      'server_name': 'alpha',
      'name': 'web',
      'state': 'Running',
    });

    expect(container.serverId, 'server-1');
    expect(container.serverName, 'alpha');
    expect(container.state, ContainerState.running);
  });
}
