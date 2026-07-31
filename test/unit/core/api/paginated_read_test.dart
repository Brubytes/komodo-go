import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/komodo_api_capabilities.dart';
import 'package:komodo_go/core/api/paginated_read.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements KomodoApiClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const RpcRequest<dynamic>(type: 'fallback', params: <String, dynamic>{}),
    );
  });

  test('readAllPages reads subsequent pages until a short page', () async {
    final client = _MockApiClient();
    when(
      () => client.capabilities,
    ).thenReturn(KomodoApiCapabilities.v23AndNewer);
    when(() => client.read(any())).thenAnswer((invocation) async {
      final request =
          invocation.positionalArguments.single as RpcRequest<dynamic>;
      final page = (request.params as Map<String, dynamic>)['page'];
      if (page == 0) return List<dynamic>.generate(50, (index) => index);
      return <dynamic>[50];
    });

    final result = await readAllPages(
      client,
      type: 'ListActions',
      params: const ResourceListOptions().params(),
    );

    expect(result, hasLength(51));
    final requests = verify(
      () => client.read(captureAny()),
    ).captured.cast<RpcRequest<dynamic>>();
    expect(requests, hasLength(2));
    expect((requests[0].params as Map<String, dynamic>)['page'], 0);
    expect((requests[1].params as Map<String, dynamic>)['page'], 1);
    expect((requests[1].params as Map<String, dynamic>)['limit'], 50);
  });

  test('Komodo 2.2 performs one unpaginated list request', () async {
    final client = _MockApiClient();
    when(() => client.capabilities).thenReturn(KomodoApiCapabilities.v22);
    when(
      () => client.read(any()),
    ).thenAnswer((_) async => List<dynamic>.generate(80, (index) => index));

    final result = await readAllPages(
      client,
      type: 'ListActions',
      params: const ResourceListOptions(
        terms: 'deploy',
        sortDesc: true,
      ).params(),
    );

    expect(result, hasLength(80));
    final request =
        verify(
              () => client.read(captureAny()),
            ).captured.single
            as RpcRequest<dynamic>;
    expect(request.params, <String, dynamic>{
      'query': <String, dynamic>{
        'names': <String>[],
        'templates': 'Include',
        'tags': <String>[],
        'tag_behavior': 'All',
        'specific': <String, dynamic>{},
      },
    });
  });

  test('ResourceListOptions forwards v2.3 filters and ordering', () {
    final params = const ResourceListOptions(
      terms: 'api',
      names: ['prod'],
      tags: ['critical'],
      tagBehavior: 'Any',
      templates: 'Exclude',
      sortBy: 'UpdatedAt',
      sortDesc: true,
    ).params();

    expect(params, <String, dynamic>{
      'query': <String, dynamic>{
        'terms': 'api',
        'names': <String>['prod'],
        'templates': 'Exclude',
        'tags': <String>['critical'],
        'tag_behavior': 'Any',
        'specific': <String, dynamic>{},
      },
      'sort_by': 'UpdatedAt',
      'sort_desc': true,
    });
  });
}
