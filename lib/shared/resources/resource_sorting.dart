import 'package:komodo_go/core/widgets/filters/template_filter.dart';

/// Severity buckets used to order and filter resources.
///
/// Lower values are more urgent. Every resource kind maps its own state enum
/// onto these buckets via `ResourceListConfig.severityOf`.
abstract final class ResourceSeverity {
  /// Failed, unhealthy, dead or unreachable: needs attention now.
  static const int attention = 0;

  /// Update available, restarting, building/pending, out of date.
  static const int warning = 1;

  /// Healthy or running.
  static const int healthy = 2;

  /// Stopped, inactive or unknown.
  static const int inactive = 3;

  /// Highest severity value that counts as a "problem".
  static const int maxProblem = warning;
}

/// Sort order of a resource list.
enum ResourceSortMode {
  /// Severity first, then case-insensitive name.
  problemsFirst('Problems first'),

  /// Case-insensitive name only.
  name('Name'),

  /// Most recent timestamp first (only for kinds exposing a timestamp).
  recentlyUpdated('Recently updated');

  const ResourceSortMode(this.label);

  final String label;
}

/// Returns a new list ordered by [mode].
///
/// Ties are always broken by case-insensitive name so ordering is stable and
/// deterministic. [ResourceSortMode.recentlyUpdated] falls back to
/// [ResourceSortMode.problemsFirst] when [updatedAtOf] is null.
List<T> sortResources<T>(
  List<T> items, {
  required ResourceSortMode mode,
  required int Function(T item) severityOf,
  required String Function(T item) nameOf,
  int Function(T item)? updatedAtOf,
}) {
  final effective =
      mode == ResourceSortMode.recentlyUpdated && updatedAtOf == null
      ? ResourceSortMode.problemsFirst
      : mode;

  // Decorate-sort-undecorate: compute lowercase name / severity / timestamp
  // once per item instead of once per comparison.
  final entries = <_SortEntry<T>>[
    for (final item in items)
      _SortEntry<T>(
        item,
        nameOf(item).toLowerCase(),
        effective == ResourceSortMode.problemsFirst ? severityOf(item) : 0,
        effective == ResourceSortMode.recentlyUpdated ? updatedAtOf!(item) : 0,
      ),
  ];
  switch (effective) {
    case ResourceSortMode.problemsFirst:
      entries.sort((a, b) {
        final bySeverity = a.severity.compareTo(b.severity);
        return bySeverity != 0 ? bySeverity : a.name.compareTo(b.name);
      });
    case ResourceSortMode.name:
      entries.sort((a, b) => a.name.compareTo(b.name));
    case ResourceSortMode.recentlyUpdated:
      entries.sort((a, b) {
        final byTime = b.updatedAt.compareTo(a.updatedAt);
        return byTime != 0 ? byTime : a.name.compareTo(b.name);
      });
  }
  return [for (final e in entries) e.item];
}

class _SortEntry<T> {
  _SortEntry(this.item, this.name, this.severity, this.updatedAt);

  final T item;
  final String name;
  final int severity;
  final int updatedAt;
}

/// Applies the problems-only, state and server quick filters.
///
/// Empty selections mean "no restriction".
List<T> applyResourceViewFilters<T>(
  List<T> items, {
  required bool problemsOnly,
  required Set<String> selectedStates,
  required Set<String> selectedServers,
  required int Function(T item) severityOf,
  String Function(T item)? stateLabelOf,
  String? Function(T item)? serverNameOf,
}) {
  return items.where((item) {
    if (problemsOnly && severityOf(item) > ResourceSeverity.maxProblem) {
      return false;
    }
    if (selectedStates.isNotEmpty &&
        (stateLabelOf == null ||
            !selectedStates.contains(stateLabelOf(item)))) {
      return false;
    }
    if (selectedServers.isNotEmpty &&
        (serverNameOf == null ||
            !selectedServers.contains(serverNameOf(item)))) {
      return false;
    }
    return true;
  }).toList();
}

/// Distinct non-empty values, sorted case-insensitively.
List<String> collectDistinct<T>(
  List<T> items,
  String? Function(T item) valueOf,
) {
  final values = <String>{};
  for (final item in items) {
    final value = valueOf(item)?.trim();
    if (value != null && value.isNotEmpty) values.add(value);
  }
  return values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

/// Human label for a state enum value, e.g. `notOk` -> `Not ok`.
String resourceStateLabel(Enum value) {
  final spaced = value.name.replaceAllMapped(
    RegExp('(?<=[a-z])(?=[A-Z])'),
    (_) => ' ',
  );
  final lower = spaced.toLowerCase();
  return lower.isEmpty ? lower : lower[0].toUpperCase() + lower.substring(1);
}

/// Number of filters that deviate from their defaults.
///
/// The template filter defaults to [TemplateFilter.exclude], so only
/// `include`/`only` count. A non-empty search query counts once. [extra]
/// covers kind-specific toggles (e.g. stacks' "pending updates").
int countActiveResourceFilters({
  String query = '',
  Set<String> selectedTags = const {},
  TemplateFilter templateFilter = TemplateFilter.exclude,
  bool problemsOnly = false,
  Set<String> selectedStates = const {},
  Set<String> selectedServers = const {},
  int extra = 0,
}) {
  return (query.trim().isEmpty ? 0 : 1) +
      selectedTags.length +
      (templateFilter == TemplateFilter.exclude ? 0 : 1) +
      (problemsOnly ? 1 : 0) +
      selectedStates.length +
      selectedServers.length +
      extra;
}
