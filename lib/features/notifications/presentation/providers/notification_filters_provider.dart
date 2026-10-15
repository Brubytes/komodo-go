import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/features/notifications/data/models/alert.dart';
import 'package:komodo_go/features/notifications/data/models/update_list_item.dart';

/// Filters for the Alerts tab. Unresolved alerts only by default.
class AlertFilters {
  const AlertFilters({this.unresolvedOnly = true, this.criticalOnly = false});

  final bool unresolvedOnly;
  final bool criticalOnly;

  bool get isDefault => unresolvedOnly && !criticalOnly;

  AlertFilters copyWith({bool? unresolvedOnly, bool? criticalOnly}) {
    return AlertFilters(
      unresolvedOnly: unresolvedOnly ?? this.unresolvedOnly,
      criticalOnly: criticalOnly ?? this.criticalOnly,
    );
  }

  List<Alert> apply(List<Alert> alerts) {
    return alerts
        .where((alert) => !unresolvedOnly || !alert.resolved)
        .where(
          (alert) => !criticalOnly || alert.level == SeverityLevel.critical,
        )
        .toList();
  }
}

class AlertFiltersNotifier extends Notifier<AlertFilters> {
  @override
  AlertFilters build() => const AlertFilters();

  AlertFilters get filters => state;
  set filters(AlertFilters value) => state = value;
}

final alertFiltersProvider =
    NotifierProvider<AlertFiltersNotifier, AlertFilters>(
      AlertFiltersNotifier.new,
    );

/// "Failed only" toggle for the Updates tab.
class UpdatesFailedOnlyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  bool get value => state;
  set value(bool value) => state = value;
}

final updatesFailedOnlyProvider =
    NotifierProvider<UpdatesFailedOnlyNotifier, bool>(
      UpdatesFailedOnlyNotifier.new,
    );

List<UpdateListItem> applyUpdatesFilter(
  List<UpdateListItem> updates, {
  required bool failedOnly,
}) {
  if (!failedOnly) return updates;
  return updates.where((u) => u.status == UpdateStatus.failed).toList();
}
