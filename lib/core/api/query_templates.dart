Map<String, dynamic> emptyQuery({
  Map<String, dynamic>? specific,
  String terms = '',
  List<String> names = const [],
  List<String> tags = const [],
  String tagBehavior = 'All',
  String templates = 'Include',
}) {
  return <String, dynamic>{
    'terms': terms,
    'names': names,
    'templates': templates,
    'tags': tags,
    'tag_behavior': tagBehavior,
    'specific': specific ?? <String, dynamic>{},
  };
}
