import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/utils/relative_time.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/dialogs/confirm_destructive_dialog.dart';
import 'package:komodo_go/core/widgets/empty_error_state.dart';
import 'package:komodo_go/core/widgets/empty_state_view.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/menus/komodo_select_menu_field.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/features/procedures/presentation/providers/procedures_provider.dart';
import 'package:komodo_go/features/procedures/presentation/widgets/procedure_stages_timeline.dart';
import 'package:komodo_go/shared/widgets/automation_toggles_block.dart';

/// View displaying detailed procedure information.
class ProcedureDetailView extends ConsumerStatefulWidget {
  const ProcedureDetailView({
    required this.procedureId,
    required this.procedureName,
    this.appBarActions = const <Widget>[],
    this.manageGroups = const <DetailActionGroup>[],
    super.key,
  });

  final String procedureId;
  final String procedureName;
  final List<Widget> appBarActions;
  final List<DetailActionGroup> manageGroups;

  @override
  ConsumerState<ProcedureDetailView> createState() =>
      _ProcedureDetailViewState();
}

class _ProcedureDetailViewState extends ConsumerState<ProcedureDetailView>
    with
        SingleTickerProviderStateMixin,
        DetailDirtySnackBarMixin<ProcedureDetailView> {
  late final TabController _tabController;
  final _outerScrollController = ScrollController();
  final _nestedScrollKey = GlobalKey<NestedScrollViewState>();
  final _configEditorKey = GlobalKey<ProcedureConfigEditorContentState>();
  var _configSaveInFlight = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _outerScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final procedureId = widget.procedureId;
    final procedureAsync = ref.watch(procedureDetailProvider(procedureId));
    final proceduresListAsync = ref.watch(proceduresProvider);
    final actionsState = ref.watch(procedureActionsProvider);
    final scheme = Theme.of(context).colorScheme;

    ProcedureListItem? listItem;
    final list = proceduresListAsync.asData?.value;
    if (list != null) {
      for (final item in list) {
        if (item.id == procedureId) {
          listItem = item;
          break;
        }
      }
    }

    return Scaffold(
      appBar: MainAppBar(
        title: widget.procedureName,
        icon: AppIcons.procedures,
        markColor: AppTokens.resourceProcedures,
        markUseGradient: true,
        centerTitle: true,
        status: procedureAppBarStatus(listItem: listItem),
        actions: widget.appBarActions,
      ),
      body: Stack(
        children: [
          NestedScrollView(
            key: _nestedScrollKey,
            controller: _outerScrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: procedureAsync.when(
                      data: (procedure) {
                        if (procedure == null) {
                          return const EmptyStateView.inline(
                            icon: AppIcons.procedures,
                            title: 'Procedure not found',
                          );
                        }

                        final running =
                            listItem?.info.state == ProcedureState.running;
                        final onRun = actionsState.isLoading || running
                            ? null
                            : () =>
                                  unawaited(_runProcedure(context, procedure));
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ProcedureHeader(
                              procedure: procedure,
                              listItem: listItem,
                              onRun: onRun,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            DetailActionBar(
                              primary: DetailActionButton(
                                label: running ? 'Running…' : 'Run',
                                icon: AppIcons.play,
                                loading: running || actionsState.isLoading,
                                onPressed: onRun,
                              ),
                              moreGroups: widget.manageGroups,
                            ),
                          ],
                        );
                      },
                      loading: () => const _LoadingSurface(),
                      error: (error, _) => ErrorStateView.fromError(
                        title: 'Failed to load procedure',
                        error: error,
                        onRetry: () => ref.invalidate(
                          procedureDetailProvider(procedureId),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverOverlapAbsorber(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                    context,
                  ),
                  sliver: SliverPersistentHeader(
                    pinned: true,
                    delegate: _PinnedTabBarHeaderDelegate(
                      backgroundColor: scheme.surface,
                      tabBar: buildDetailTabBar(
                        context: context,
                        controller: _tabController,
                        outerScrollController: _outerScrollController,
                        nestedScrollKey: _nestedScrollKey,
                        tabs: const [
                          Tab(icon: Icon(AppIcons.bolt), text: 'Config'),
                          Tab(icon: Icon(AppIcons.procedures), text: 'Stages'),
                        ],
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _KeepAlive(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(procedureDetailProvider(procedureId));
                    },
                    child: DetailTabScrollView.box(
                      scrollKey: PageStorageKey(
                        'procedure_${widget.procedureId}_config',
                      ),
                      child: procedureAsync.when(
                        data: (procedure) {
                          if (procedure == null) {
                            return const EmptyStateView.inline(
                              icon: AppIcons.procedures,
                              title: 'Procedure not found',
                            );
                          }

                          return ProcedureConfigEditorContent(
                            key: _configEditorKey,
                            initialConfig: procedure.config,
                            onDirtyChanged: (dirty) {
                              syncDirtySnackBar(
                                dirty: dirty,
                                onDiscard: () => _discardConfig(procedure),
                                onSave: () => _saveConfig(procedure: procedure),
                                saveEnabled: !_configSaveInFlight,
                              );
                            },
                          );
                        },
                        loading: () => const _LoadingSurface(),
                        error: (error, _) => ErrorStateView.fromError(
                          title: 'Failed to load procedure',
                          error: error,
                          onRetry: () => ref.invalidate(
                            procedureDetailProvider(procedureId),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _KeepAlive(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(procedureDetailProvider(procedureId));
                    },
                    child: DetailTabScrollView.box(
                      scrollKey: PageStorageKey(
                        'procedure_${widget.procedureId}_stages',
                      ),
                      child: procedureAsync.when(
                        data: (procedure) {
                          if (procedure == null) {
                            return const EmptyStateView.inline(
                              icon: AppIcons.procedures,
                              title: 'Procedure not found',
                            );
                          }

                          return ProcedureStagesTimeline(
                            stages: procedure.config.stages,
                          );
                        },
                        loading: () => const _LoadingSurface(),
                        error: (error, _) => ErrorStateView.fromError(
                          title: 'Failed to load procedure',
                          error: error,
                          onRetry: () => ref.invalidate(
                            procedureDetailProvider(procedureId),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (actionsState.isLoading)
            ColoredBox(
              color: scheme.scrim.withValues(alpha: 0.25),
              child: const Center(child: AppSkeletonCard()),
            ),
        ],
      ),
    );
  }

  Future<void> _runProcedure(
    BuildContext context,
    KomodoProcedure procedure,
  ) async {
    final stages = procedure.config.stages.length;
    final confirmed = await confirmDestructive(
      context,
      title: 'Run ${procedure.name}?',
      message:
          'Executes all $stages ${stages == 1 ? 'stage' : 'stages'} in order.',
      confirmLabel: 'Run',
      destructive: false,
    );
    if (!confirmed || !mounted) return;

    final actions = ref.read(procedureActionsProvider.notifier);
    final success = await actions.run(procedure.id);

    if (!mounted) return;

    if (success) {
      ref
        ..invalidate(procedureDetailProvider(widget.procedureId))
        ..invalidate(proceduresProvider);
    }

    if (context.mounted) {
      AppSnackBar.show(
        context,
        success ? 'Procedure started' : 'Action failed. Please try again.',
        tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
      );
    }
  }

  void _discardConfig(KomodoProcedure procedure) {
    _configEditorKey.currentState?.resetTo(procedure.config);
    hideDirtySnackBar();
  }

  Future<void> _saveConfig({required KomodoProcedure procedure}) async {
    if (_configSaveInFlight) return;

    final draft = _configEditorKey.currentState;
    if (draft == null) {
      AppSnackBar.show(
        context,
        'Editor not ready',
        tone: AppSnackBarTone.error,
      );
      return;
    }

    final partialConfig = draft.buildPartialConfigParams();
    if (partialConfig.isEmpty) {
      hideDirtySnackBar();
      return;
    }

    setState(() => _configSaveInFlight = true);
    final updated = await ref
        .read(procedureActionsProvider.notifier)
        .updateProcedureConfig(
          procedureId: procedure.id,
          partialConfig: partialConfig,
        );
    if (!mounted) return;
    setState(() => _configSaveInFlight = false);

    if (updated != null) {
      ref
        ..invalidate(procedureDetailProvider(widget.procedureId))
        ..invalidate(procedureDetailProvider(procedure.id))
        ..invalidate(proceduresProvider);

      _configEditorKey.currentState?.resetTo(updated.config);
      hideDirtySnackBar();
      AppSnackBar.show(
        context,
        'Procedure updated',
        tone: AppSnackBarTone.success,
      );
      return;
    }

    final err = ref.read(procedureActionsProvider).asError?.error;
    AppSnackBar.show(
      context,
      err != null ? 'Failed: $err' : 'Failed to update procedure',
      tone: AppSnackBarTone.error,
    );

    reShowDirtySnackBarIfStillDirty(
      isStillDirty: () {
        return _configEditorKey.currentState
                ?.buildPartialConfigParams()
                .isNotEmpty ??
            false;
      },
      onDiscard: () => _discardConfig(procedure),
      onSave: () => _saveConfig(procedure: procedure),
      saveEnabled: !_configSaveInFlight,
    );
  }
}

class _PinnedTabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  _PinnedTabBarHeaderDelegate({
    required this.tabBar,
    required this.backgroundColor,
  });

  final PreferredSizeWidget tabBar;
  final Color backgroundColor;

  @override
  double get minExtent => tabBar.preferredSize.height + 1;

  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Align(alignment: Alignment.centerLeft, child: tabBar),
    );
  }

  @override
  bool shouldRebuild(_PinnedTabBarHeaderDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar ||
      backgroundColor != oldDelegate.backgroundColor;
}

class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin<_KeepAlive> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}

class ProcedureConfigEditorContent extends StatefulWidget {
  const ProcedureConfigEditorContent({
    required this.initialConfig,
    this.onDirtyChanged,
    super.key,
  });

  final ProcedureConfig initialConfig;
  final ValueChanged<bool>? onDirtyChanged;

  @override
  State<ProcedureConfigEditorContent> createState() =>
      ProcedureConfigEditorContentState();
}

class ProcedureConfigEditorContentState
    extends State<ProcedureConfigEditorContent> {
  late ProcedureConfig _initial;

  var _lastDirty = false;
  var _suppressDirtyNotify = false;

  late final TextEditingController _schedule;
  late final TextEditingController _scheduleTimezone;
  late final TextEditingController _webhookSecret;

  var _scheduleEnabled = false;
  var _webhookEnabled = false;
  var _scheduleAlert = false;
  var _failureAlert = false;
  ScheduleFormat _scheduleFormat = ScheduleFormat.english;

  @override
  void initState() {
    super.initState();
    _initial = widget.initialConfig;

    _schedule = TextEditingController(text: _initial.schedule);
    _scheduleTimezone = TextEditingController(text: _initial.scheduleTimezone);
    _webhookSecret = TextEditingController(text: _initial.webhookSecret);

    _scheduleEnabled = _initial.scheduleEnabled;
    _webhookEnabled = _initial.webhookEnabled;
    _scheduleAlert = _initial.scheduleAlert;
    _failureAlert = _initial.failureAlert;
    _scheduleFormat = _initial.scheduleFormat;

    for (final c in <TextEditingController>[
      _schedule,
      _scheduleTimezone,
      _webhookSecret,
    ]) {
      c.addListener(_notifyDirtyIfChanged);
    }
  }

  @override
  void didUpdateWidget(covariant ProcedureConfigEditorContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialConfig != oldWidget.initialConfig) {
      final dirty = buildPartialConfigParams().isNotEmpty;
      if (!dirty) {
        resetTo(widget.initialConfig);
      }
    }
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _schedule,
      _scheduleTimezone,
      _webhookSecret,
    ]) {
      c.removeListener(_notifyDirtyIfChanged);
    }

    _schedule.dispose();
    _scheduleTimezone.dispose();
    _webhookSecret.dispose();
    super.dispose();
  }

  void resetTo(ProcedureConfig config) {
    _suppressDirtyNotify = true;
    setState(() {
      _initial = config;

      _schedule.text = config.schedule;
      _scheduleTimezone.text = config.scheduleTimezone;
      _webhookSecret.text = config.webhookSecret;

      _scheduleEnabled = config.scheduleEnabled;
      _webhookEnabled = config.webhookEnabled;
      _scheduleAlert = config.scheduleAlert;
      _failureAlert = config.failureAlert;
      _scheduleFormat = config.scheduleFormat;
    });

    _suppressDirtyNotify = false;
    _lastDirty = false;
    widget.onDirtyChanged?.call(false);
  }

  void _notifyDirtyIfChanged() {
    if (_suppressDirtyNotify) return;
    final dirty = buildPartialConfigParams().isNotEmpty;
    if (dirty == _lastDirty) return;
    _lastDirty = dirty;
    widget.onDirtyChanged?.call(dirty);
  }

  Map<String, dynamic> buildPartialConfigParams() {
    final params = <String, dynamic>{};

    void setIfChanged(String key, Object value, Object initialValue) {
      if (value != initialValue) {
        params[key] = value;
      }
    }

    setIfChanged(
      'schedule_enabled',
      _scheduleEnabled,
      _initial.scheduleEnabled,
    );
    setIfChanged('webhook_enabled', _webhookEnabled, _initial.webhookEnabled);
    setIfChanged('schedule_alert', _scheduleAlert, _initial.scheduleAlert);
    setIfChanged('failure_alert', _failureAlert, _initial.failureAlert);

    final schedule = _schedule.text;
    setIfChanged('schedule', schedule, _initial.schedule);

    final scheduleTimezone = _scheduleTimezone.text.trim();
    setIfChanged(
      'schedule_timezone',
      scheduleTimezone,
      _initial.scheduleTimezone,
    );

    final webhookSecret = _webhookSecret.text;
    setIfChanged('webhook_secret', webhookSecret, _initial.webhookSecret);

    if (_scheduleFormat != _initial.scheduleFormat) {
      params['schedule_format'] = _scheduleFormat == ScheduleFormat.cron
          ? 'Cron'
          : 'English';
    }

    return params;
  }

  void _toggle(void Function() update) {
    setState(update);
    _notifyDirtyIfChanged();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutomationTogglesBlock(
          primary: [
            AutomationToggle(
              label: 'Schedule enabled',
              icon: AppIcons.clock,
              value: _scheduleEnabled,
              onChanged: (v) => _toggle(() => _scheduleEnabled = v),
            ),
            AutomationToggle(
              label: 'Failure alerts',
              icon: AppIcons.warning,
              value: _failureAlert,
              onChanged: (v) => _toggle(() => _failureAlert = v),
            ),
          ],
          rare: [
            AutomationToggle(
              label: 'Schedule alerts',
              icon: AppIcons.notifications,
              value: _scheduleAlert,
              onChanged: (v) => _toggle(() => _scheduleAlert = v),
            ),
          ],
          webhookEnabled: AutomationToggle(
            label: 'Webhook enabled',
            icon: AppIcons.network,
            value: _webhookEnabled,
            onChanged: (v) => _toggle(() => _webhookEnabled = v),
          ),
          webhookSecret: _webhookSecret,
        ),
        const SizedBox(height: AppSpacing.md),
        DetailSubCard(
          title: 'Schedule',
          icon: AppIcons.clock,
          child: Column(
            children: [
              KomodoSelectMenuField<ScheduleFormat>(
                key: const ValueKey('procedure_schedule_format'),
                value: _scheduleFormat,
                items: const [
                  KomodoSelectMenuItem(
                    value: ScheduleFormat.english,
                    label: 'English',
                  ),
                  KomodoSelectMenuItem(
                    value: ScheduleFormat.cron,
                    label: 'Cron',
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _scheduleFormat = v);
                  _notifyDirtyIfChanged();
                },
                decoration: const InputDecoration(
                  labelText: 'Schedule format',
                  prefixIcon: Icon(AppIcons.clock),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _scheduleTimezone,
                decoration: InputDecoration(
                  labelText: 'Timezone',
                  prefixIcon: const Icon(AppIcons.clock),
                  labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _schedule,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Schedule expression',
                  prefixIcon: const Icon(AppIcons.tag),
                  helperText: _scheduleFormat == ScheduleFormat.cron
                      ? 'Cron (e.g. 0 0 * * *)'
                      : 'English (e.g. every day at 01:00)',
                  labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// App bar status line: state plus time since the last run.
MainAppBarStatus? procedureAppBarStatus({
  required ProcedureListItem? listItem,
}) {
  final info = listItem?.info;
  final state = info?.state;
  if (info == null || state == null) return null;
  final lastRun = info.lastRunAt;
  final ran = state == ProcedureState.running || lastRun == null
      ? ''
      : ' · ran ${formatTimeAgo(lastRun)}';
  return MainAppBarStatus(
    label: '${state.displayName}$ran',
    tone: switch (state) {
      ProcedureState.ok => PillTone.success,
      ProcedureState.failed => PillTone.alert,
      ProcedureState.running => PillTone.warning,
      ProcedureState.unknown => PillTone.neutral,
    },
  );
}

class _ProcedureHeader extends StatelessWidget {
  const _ProcedureHeader({
    required this.procedure,
    required this.listItem,
    required this.onRun,
  });

  final KomodoProcedure procedure;
  final ProcedureListItem? listItem;
  final VoidCallback? onRun;

  @override
  Widget build(BuildContext context) {
    final schedule = procedure.config.schedule.trim();
    final nextRun = listItem?.info.nextScheduledRun;
    final failed = listItem?.info.state == ProcedureState.failed;

    return DetailResourceHeader(
      banner: failed
          ? DetailAttentionBanner(
              icon: AppIcons.error,
              message: 'Last run failed',
              tone: PillTone.alert,
              actionLabel: onRun == null ? null : 'Run',
              onAction: onRun,
            )
          : null,
      facts: [
        DetailFact(
          icon: AppIcons.procedures,
          label: 'Stages',
          value: procedure.config.stages.length.toString(),
        ),
        if (schedule.isNotEmpty)
          DetailFact(
            icon: AppIcons.clock,
            label: 'Schedule',
            value: schedule,
          ),
        if (nextRun != null)
          DetailFact(
            icon: AppIcons.waiting,
            label: 'Next run',
            value: formatTimeUntil(nextRun),
            fullValue: DateTime.fromMillisecondsSinceEpoch(
              nextRun,
            ).toLocal().toString(),
          ),
      ],
      tags: procedure.tags,
      description: procedure.description,
    );
  }
}

/// Timestamps from the API are unix milliseconds.

class _LoadingSurface extends StatelessWidget {
  const _LoadingSurface();

  @override
  Widget build(BuildContext context) {
    return const AppSkeletonSurface();
  }
}
