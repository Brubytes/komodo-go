import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/providers/shared_preferences_provider.dart';

/// SharedPreferences key holding the dismissed failed-update IDs.
const dismissedUpdatesKey = 'komodo.dismissed_failed_updates.v1';

final dismissedUpdatesProvider =
    AsyncNotifierProvider<DismissedUpdatesNotifier, Set<String>>(
      DismissedUpdatesNotifier.new,
    );

/// Failed-update IDs the user swiped away on the home "Needs attention" card.
class DismissedUpdatesNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return (prefs.getStringList(dismissedUpdatesKey) ?? const <String>[])
        .toSet();
  }

  Future<void> _save(Set<String> ids) async {
    state = AsyncValue.data(ids);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setStringList(dismissedUpdatesKey, ids.toList());
  }

  Future<void> dismiss(String id) async {
    final current = state.asData?.value ?? await future;
    if (current.contains(id)) return;
    await _save({...current, id});
  }

  Future<void> restore(String id) async {
    final current = state.asData?.value ?? await future;
    if (!current.contains(id)) return;
    await _save({...current}..remove(id));
  }

  /// Drops stored IDs that are not in [validIds] (expired or gone).
  Future<void> prune(Set<String> validIds) async {
    final current = state.asData?.value;
    if (current == null) return;
    final kept = current.intersection(validIds);
    if (kept.length == current.length) return;
    await _save(kept);
  }
}
