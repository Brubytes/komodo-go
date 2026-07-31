import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/data/models/core_info.dart';

void main() {
  test('parses the v2.3 default pagination limit', () {
    final info = CoreInfo.fromJson(<String, dynamic>{
      'webhook_base_url': 'https://example.com/webhook',
      'default_pagination_limit': 75,
    });

    expect(info.webhookBaseUrl, 'https://example.com/webhook');
    expect(info.defaultPaginationLimit, 75);
  });

  test('defaults pagination limit for older payloads', () {
    expect(
      CoreInfo.fromJson(const <String, dynamic>{}).defaultPaginationLimit,
      50,
    );
  });
}
