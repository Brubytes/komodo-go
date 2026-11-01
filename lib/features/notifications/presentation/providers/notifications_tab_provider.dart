import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Active tab of the notifications screen (0 = Alerts, 1 = Updates).
///
/// Lives outside the view so the surrounding list/detail layout can split
/// only while the Updates tab is showing, and so the list instance in a
/// detail page opens on the same tab.
class NotificationsTabIndex extends Notifier<int> {
  @override
  int build() => 0;

  int get index => state;

  set index(int value) => state = value;
}

final notificationsTabIndexProvider =
    NotifierProvider<NotificationsTabIndex, int>(NotificationsTabIndex.new);
