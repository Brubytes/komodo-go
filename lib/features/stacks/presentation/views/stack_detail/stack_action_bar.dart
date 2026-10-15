import 'package:flutter/material.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/presentation/widgets/stack_card.dart';

/// State-aware action bar for the stack detail screen.
///
/// Primary: Deploy when the stack is not running, Redeploy when it has
/// pending changes, Resume when paused, otherwise Restart. Secondary jumps to
/// the logs tab. Only actions valid for [state] appear in the "More" menu.
class StackActionBar extends StatelessWidget {
  const StackActionBar({
    required this.state,
    required this.needsDeploy,
    required this.onAction,
    required this.onShowLogs,
    this.manageItems = const [],
    this.busy = false,
    super.key,
  });

  final StackState? state;

  /// True when the repo has new commits or images can be updated.
  final bool needsDeploy;
  final ValueChanged<StackAction> onAction;
  final VoidCallback onShowLogs;
  final List<DetailActionItem> manageItems;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final state = this.state ?? StackState.unknown;
    final running =
        state.isRunning ||
        state == StackState.unhealthy ||
        state == StackState.restarting;
    final paused = state == StackState.paused;

    final DetailActionButton primary;
    StackAction? primaryAction;
    if (!running && !paused) {
      primaryAction = StackAction.redeploy;
      primary = DetailActionButton(
        label: 'Deploy',
        icon: AppIcons.deployments,
        loading: busy,
        onPressed: () => onAction(StackAction.redeploy),
      );
    } else if (needsDeploy) {
      primaryAction = StackAction.redeploy;
      primary = DetailActionButton(
        label: 'Redeploy',
        icon: AppIcons.deployments,
        loading: busy,
        onPressed: () => onAction(StackAction.redeploy),
      );
    } else if (paused) {
      primaryAction = StackAction.start;
      primary = DetailActionButton(
        label: 'Resume',
        icon: AppIcons.play,
        loading: busy,
        onPressed: () => onAction(StackAction.start),
      );
    } else {
      primaryAction = StackAction.restart;
      primary = DetailActionButton(
        label: 'Restart',
        icon: AppIcons.refresh,
        loading: busy,
        onPressed: () => onAction(StackAction.restart),
      );
    }

    DetailActionItem item(
      String label,
      IconData icon,
      StackAction action, {
      bool destructive = false,
    }) {
      return DetailActionItem(
        label: label,
        icon: icon,
        destructive: destructive,
        onSelected: () => onAction(action),
      );
    }

    final lifecycle = <DetailActionItem>[
      if (!running && !paused) item('Start', AppIcons.play, StackAction.start),
      if (running) item('Restart', AppIcons.refresh, StackAction.restart),
      if (running) item('Pause', AppIcons.pause, StackAction.pause),
      if (running || paused) item('Stop', AppIcons.stop, StackAction.stop),
    ];
    // The primary button already covers Restart / Resume.
    if (primaryAction == StackAction.restart) {
      lifecycle.removeWhere((i) => i.label == 'Restart');
    }

    return DetailActionBar(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      primary: primary,
      secondary: DetailActionButton(
        label: 'Logs',
        icon: AppIcons.logs,
        onPressed: onShowLogs,
      ),
      moreGroups: [
        DetailActionGroup(label: 'Lifecycle', items: lifecycle),
        DetailActionGroup(
          label: 'Maintenance',
          items: [
            item('Pull images', AppIcons.download, StackAction.pullImages),
            item(
              'Check for image updates',
              Icons.refresh_outlined,
              StackAction.checkUpdates,
            ),
            item(
              'Deploy if changed',
              Icons.difference_outlined,
              StackAction.deployIfChanged,
            ),
            if (running && primaryAction != StackAction.redeploy)
              item('Redeploy', AppIcons.deployments, StackAction.redeploy),
          ],
        ),
        DetailActionGroup(label: 'Manage', items: manageItems),
        DetailActionGroup(
          items: [
            item(
              'Destroy',
              AppIcons.delete,
              StackAction.destroy,
              destructive: true,
            ),
          ],
        ),
      ],
    );
  }
}
