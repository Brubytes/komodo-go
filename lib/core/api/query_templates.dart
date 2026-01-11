Map<String, dynamic> emptyQuery({Map<String, dynamic>? specific}) {
  return <String, dynamic>{
    'names': <String>[],
    'templates': 'Include',
    'tags': <String>[],
    'tag_behavior': 'All',
    'specific': specific ?? <String, dynamic>{},
  };
}
