import 'package:komodo_go/core/widgets/filters/template_filter.dart';

/// Applies template, tag, and search filters to a resource list.
List<T> applyResourceFilters<T>(
  List<T> items, {
  required String query,
  required Set<String> selectedTags,
  required TemplateFilter templateFilter,
  required Map<String, String> tagNameById,
  required bool Function(T item) isTemplate,
  required List<String> Function(T item) tagsOf,
  required List<String> Function(T item) searchFieldsOf,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final normalizedTags = selectedTags
      .map((tag) => tag.trim().toLowerCase())
      .where((tag) => tag.isNotEmpty)
      .toSet();

  return items.where((item) {
    switch (templateFilter) {
      case TemplateFilter.exclude:
        if (isTemplate(item)) return false;
      case TemplateFilter.only:
        if (!isTemplate(item)) return false;
      case TemplateFilter.include:
        break;
    }

    if (normalizedTags.isNotEmpty) {
      final tagMatches = tagsOf(item).any(
        (tag) => normalizedTags.contains(tag.trim().toLowerCase()),
      );
      if (!tagMatches) return false;
    }

    if (normalizedQuery.isEmpty) return true;

    final fieldMatch = searchFieldsOf(item).any(
      (field) => field.toLowerCase().contains(normalizedQuery),
    );
    final displayTags = resourceDisplayTags(tagsOf(item), tagNameById);
    final tagMatch = displayTags.any(
      (tag) => tag.trim().toLowerCase().contains(normalizedQuery),
    );

    return fieldMatch || tagMatch;
  }).toList();
}

/// True when any filter deviates from its default.
bool hasActiveResourceFilters({
  required String query,
  required Set<String> selectedTags,
  required TemplateFilter templateFilter,
}) {
  return query.trim().isNotEmpty ||
      selectedTags.isNotEmpty ||
      templateFilter != TemplateFilter.exclude;
}

/// Collects the distinct, trimmed, sorted tag values across [items].
List<String> collectResourceTags<T>(
  List<T> items,
  List<String> Function(T item) tagsOf,
) {
  final tags = <String>{};
  for (final item in items) {
    for (final tag in tagsOf(item)) {
      if (tag.trim().isNotEmpty) {
        tags.add(tag.trim());
      }
    }
  }
  final sorted = tags.toList()..sort();
  return sorted;
}

/// Maps raw tag ids to display names via [tagNameById], falling back to the
/// raw value, preserving item order.
List<String> resourceDisplayTags(
  List<String> tags,
  Map<String, String> tagNameById,
) {
  if (tags.isEmpty) return const [];
  return [
    for (final tag in tags) tagNameById[tag] ?? tag,
  ];
}
