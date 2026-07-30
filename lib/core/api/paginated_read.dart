import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/query_templates.dart';

/// Common filters and ordering supported by Komodo v2.3 resource list APIs.
class ResourceListOptions {
  const ResourceListOptions({
    this.terms = '',
    this.names = const [],
    this.tags = const [],
    this.tagBehavior = 'All',
    this.templates = 'Include',
    this.sortBy = 'Name',
    this.sortDesc = false,
    this.pageSize = 50,
  }) : assert(pageSize > 0, 'pageSize must be greater than zero');

  final String terms;
  final List<String> names;
  final List<String> tags;
  final String tagBehavior;
  final String templates;
  final String sortBy;
  final bool sortDesc;
  final int pageSize;

  Map<String, dynamic> params({Map<String, dynamic>? specific}) =>
      <String, dynamic>{
        'query': emptyQuery(
          specific: specific,
          terms: terms,
          names: names,
          tags: tags,
          tagBehavior: tagBehavior,
          templates: templates,
        ),
        'sort_by': sortBy,
        'sort_desc': sortDesc,
      };
}

/// Reads every page from a v2.3 paginated list endpoint.
///
/// Repository list methods historically returned the complete collection. This
/// helper retains that contract while sending explicit pagination parameters so
/// the server's new default limit cannot silently truncate results.
Future<List<dynamic>> readAllPages(
  KomodoApiClient client, {
  required String type,
  required Map<String, dynamic> params,
  int pageSize = 50,
}) async {
  final result = <dynamic>[];
  var page = 0;

  while (true) {
    final response = await client.read(
      RpcRequest(
        type: type,
        params: <String, dynamic>{
          ...params,
          'page': page,
          'limit': pageSize,
        },
      ),
    );
    final items = response as List<dynamic>? ?? const <dynamic>[];
    result.addAll(items);
    if (items.length < pageSize) return result;
    page += 1;
  }
}
