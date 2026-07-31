import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/widgets/filters/tag_filter_sheet.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';

/// Per-resource configuration consumed by `ResourceListView<T>`.
///
/// Everything that differed between the five copied list views
/// (builds/repos/actions/procedures/syncs) lives here; the shared view
/// renders identical chrome around it.
class ResourceListConfig<T> {
  const ResourceListConfig({
    required this.kind,
    required this.title,
    required this.resourceName,
    required this.icon,
    required this.markColor,
    required this.searchFieldKey,
    required this.skeletonTitle,
    required this.skeletonSubtitle,
    required this.skeletonChipLeft,
    required this.skeletonChipRight,
    required this.watchList,
    required this.watchTagOptions,
    required this.refreshList,
    required this.invalidateList,
    required this.watchActionsState,
    required this.isTemplate,
    required this.tagsOf,
    required this.searchFieldsOf,
    required this.cardBuilder,
  });

  /// Keys the shared filter providers.
  final ResourceKind kind;

  /// App bar title, e.g. `'Builds'`.
  final String title;

  /// Lowercase plural used in user-facing copy.
  final String resourceName;

  /// App bar and empty-state icon.
  final IconData icon;

  /// App bar mark color.
  final Color markColor;

  /// Search `TextField` key. Must stay identical to the pre-refactor key.
  final Key searchFieldKey;

  /// Skeleton placeholder title.
  final String skeletonTitle;

  /// Skeleton placeholder subtitle.
  final String skeletonSubtitle;

  /// Left skeleton chip label.
  final String skeletonChipLeft;

  /// Right skeleton chip label.
  final String skeletonChipRight;

  /// Watches the list provider.
  final AsyncValue<List<T>> Function(WidgetRef ref) watchList;

  /// Watches globally configured tag options for this list.
  final AsyncValue<List<TagOption>> Function(WidgetRef ref) watchTagOptions;

  /// Pull-to-refresh target.
  final Future<void> Function(WidgetRef ref) refreshList;

  /// Error-state retry target.
  final void Function(WidgetRef ref) invalidateList;

  /// Watches the actions notifier that drives the busy overlay.
  final AsyncValue<void> Function(WidgetRef ref) watchActionsState;

  /// Whether the item is a template.
  final bool Function(T item) isTemplate;

  /// Raw tag values of the item.
  final List<String> Function(T item) tagsOf;

  /// Search haystack for the item.
  final List<String> Function(T item) searchFieldsOf;

  /// Builds the resource card, including navigation and action handling.
  final Widget Function(
    BuildContext context,
    WidgetRef ref,
    T item,
    List<String> displayTags,
  )
  cardBuilder;
}
