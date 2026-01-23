import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/menus/komodo_select_menu_field.dart';

import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/features/procedures/presentation/providers/procedures_provider.dart';

/// View displaying detailed procedure information.
class ProcedureDetailView extends ConsumerStatefulWidget {
  const ProcedureDetailView({
    required this.procedureId,
    required this.procedureName,
    super.key,
  });

  final String procedureId;
  final String procedureName;

  @override
  ConsumerState<ProcedureDetailView> createState() =>
      _ProcedureDetailViewState();
}

class _ProcedureDetailViewState extends ConsumerState<ProcedureDetailView>
    with
        SingleTickerProviderStateMixin,
        DetailDirtySnackBarMixin<ProcedureDetailView> {
  late final TabController _tabController;
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
        actions: [
          IconButton(
            icon: const Icon(AppIcons.play),
            tooltip: 'Run',
            onPressed: () => _runProcedure(context, procedureId),
          ),
        ],
      ),
      body: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: procedureAsync.when(
                      data: (procedure) {
                        if (procedure == null) {
                          return const _MessageSurface(
                            message: 'Procedure not found',
                          );
                        }

                        return _ProcedureHeroPanel(
                          procedure: procedure,
                          listItem: listItem,
                        );
                      },
                      loading: () => const _LoadingSurface(),
                      error: (error, _) =>
                          _ErrorSurface(error: error.toString()),
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedTabBarHeaderDelegate(
                    backgroundColor: scheme.surface,
                    tabBar: TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Config'),
                        Tab(text: 'Stages'),
                      ],
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
                    child: ListView(
                      key: PageStorageKey(
                        'procedure_${widget.procedureId}_config',
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        procedureAsync.when(
                          data: (procedure) {
                            if (procedure == null) {
                              return const _MessageSurface(
                                message: 'Procedure not found',
                              );
                            }

                            return ProcedureConfigEditorContent(
                              key: _configEditorKey,
                              initialConfig: procedure.config,
                              onDirtyChanged: (dirty) {
                                syncDirtySnackBar(
                                  dirty: dirty,
                                  onDiscard: () => _discardConfig(procedure),
                                  onSave: () =>
                                      _saveConfig(procedure: procedure),
                                  saveEnabled: !_configSaveInFlight,
                                );
                              },
                            );
                          },
                          loading: () => const _LoadingSurface(),
                          error: (error, _) =>
                              _ErrorSurface(error: error.toString()),
                        ),
                      ],
                    ),
                  ),
                ),
                _KeepAlive(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(procedureDetailProvider(procedureId));
                    },
                    child: ListView(
                      key: PageStorageKey(
                        'procedure_${widget.procedureId}_stages',
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        procedureAsync.when(
                          data: (procedure) {
                            if (procedure == null) {
                              return const _MessageSurface(
                                message: 'Procedure not found',
                              );
                            }

                            return _ProcedureStagesContent(
                              config: procedure.config,
                            );
                          },
                          loading: () => const _LoadingSurface(),
                          error: (error, _) =>
                              _ErrorSurface(error: error.toString()),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (actionsState.isLoading)
            ColoredBox(
              color: scheme.scrim.withValues(alpha: 0.25),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _runProcedure(BuildContext context, String procedureId) async {
    final actions = ref.read(procedureActionsProvider.notifier);
    final success = await actions.run(procedureId);

    if (success) {
      ref
        ..invalidate(procedureDetailProvider(procedureId))
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

  final TabBar tabBar;
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
  var _scheduleFormat = ScheduleFormat.english;

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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailSubCard(
          title: 'Toggles',
          icon: AppIcons.settings,
          child: Column(
            children: [
              SwitchListTile.adaptive(
                value: _scheduleEnabled,
                onChanged: (v) {
                  setState(() => _scheduleEnabled = v);
                  _notifyDirtyIfChanged();
                },
                title: const Text('Schedule enabled'),
                secondary: const Icon(AppIcons.clock),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile.adaptive(
                value: _webhookEnabled,
                onChanged: (v) {
                  setState(() => _webhookEnabled = v);
                  _notifyDirtyIfChanged();
                },
                title: const Text('Webhook enabled'),
                secondary: const Icon(AppIcons.network),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile.adaptive(
                value: _scheduleAlert,
                onChanged: (v) {
                  setState(() => _scheduleAlert = v);
                  _notifyDirtyIfChanged();
                },
                title: const Text('Schedule alerts'),
                secondary: const Icon(AppIcons.notifications),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile.adaptive(
                value: _failureAlert,
                onChanged: (v) {
                  setState(() => _failureAlert = v);
                  _notifyDirtyIfChanged();
                },
                title: const Text('Failure alerts'),
                secondary: const Icon(AppIcons.warning),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        const Gap(12),
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
              const Gap(12),
              TextFormField(
                controller: _scheduleTimezone,
                decoration: InputDecoration(
                  labelText: 'Timezone',
                  prefixIcon: const Icon(AppIcons.clock),
                  labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
              const Gap(12),
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
        const Gap(12),
        DetailSubCard(
          title: 'Webhook',
          icon: AppIcons.network,
          child: Column(
            children: [
              TextFormField(
                controller: _webhookSecret,
                decoration: InputDecoration(
                  labelText: 'Webhook secret',
                  prefixIcon: const Icon(AppIcons.key),
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

class _ProcedureHeroPanel extends StatelessWidget {
  const _ProcedureHeroPanel({required this.procedure, required this.listItem});

  final KomodoProcedure procedure;
  final ProcedureListItem? listItem;

  @override
  Widget build(BuildContext context) {
    final status = listItem?.info.state;
    final stagesCount = procedure.config.stages.length;

    return DetailHeroPanel(
      header: _ProcedureHeader(procedure: procedure),
      metrics: [
        if (status != null)
          DetailMetricTileData(
            label: 'Status',
            value: status.displayName,
            icon: switch (status) {
              ProcedureState.ok => AppIcons.ok,
              ProcedureState.failed => AppIcons.error,
              ProcedureState.running => AppIcons.loading,
              ProcedureState.unknown => AppIcons.unknown,
            },
            tone: switch (status) {
              ProcedureState.ok => DetailMetricTone.success,
              ProcedureState.failed => DetailMetricTone.alert,
              ProcedureState.running => DetailMetricTone.neutral,
              ProcedureState.unknown => DetailMetricTone.neutral,
            },
          ),
        DetailMetricTileData(
          label: 'Stages',
          value: stagesCount.toString(),
          icon: AppIcons.stacks,
          tone: DetailMetricTone.neutral,
        ),
        if (listItem?.info.lastRunAt != null)
          DetailMetricTileData(
            label: 'Last Run',
            value: _formatTimestampSeconds(listItem!.info.lastRunAt!),
            icon: AppIcons.clock,
            tone: DetailMetricTone.neutral,
          ),
        if (procedure.config.scheduleEnabled)
          DetailMetricTileData(
            label: 'Schedule',
            value: procedure.config.schedule.isNotEmpty
                ? procedure.config.schedule
                : 'Enabled',
            icon: AppIcons.clock,
            tone: DetailMetricTone.tertiary,
          )
        else
          const DetailMetricTileData(
            label: 'Schedule',
            value: 'Off',
            icon: AppIcons.pause,
            tone: DetailMetricTone.neutral,
          ),
      ],
    );
  }
}

class _ProcedureHeader extends StatelessWidget {
  const _ProcedureHeader({required this.procedure});

  final KomodoProcedure procedure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = procedure.description.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          procedure.name,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (description.isNotEmpty) ...[
          const Gap(4),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProcedureStagesContent extends StatelessWidget {
  const _ProcedureStagesContent({required this.config});

  final ProcedureConfig config;

  @override
  Widget build(BuildContext context) {
    if (config.stages.isEmpty) {
      return const Text('No stages configured');
    }

    return Column(
      children: [
        for (final stage in config.stages) ...[
          _StageCard(stage: stage),
          if (stage != config.stages.last) const Gap(12),
        ],
      ],
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.stage});

  final ProcedureStage stage;

  @override
  Widget build(BuildContext context) {
    final enabledExecutions = stage.executions.where((e) => e.enabled).length;
    final totalExecutions = stage.executions.length;

    return DetailSubCard(
      title: stage.name.isNotEmpty ? stage.name : 'Stage',
      icon: AppIcons.stacks,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill.onOff(
                isOn: stage.enabled,
                onLabel: 'Enabled',
                offLabel: 'Disabled',
                onIcon: AppIcons.ok,
                offIcon: AppIcons.canceled,
              ),
              TextPill(label: '$enabledExecutions/$totalExecutions executions'),
            ],
          ),
          if (totalExecutions > 0) ...[
            const Gap(12),
            for (var i = 0; i < stage.executions.length; i++) ...[
              _ExecutionBlock(index: i, execution: stage.executions[i]),
              if (i != stage.executions.length - 1) const Gap(12),
            ],
          ],
        ],
      ),
    );
  }
}

class _ExecutionBlock extends StatelessWidget {
  const _ExecutionBlock({required this.index, required this.execution});

  final int index;
  final EnabledExecution execution;

  @override
  Widget build(BuildContext context) {
    final label = 'Execution ${index + 1}';
    final code = _pretty(execution.execution);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Gap(8),
            StatusPill.onOff(
              isOn: execution.enabled,
              onLabel: 'On',
              offLabel: 'Off',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.pause,
            ),
          ],
        ),
        const Gap(8),
        DetailCodeBlock(code: code, maxHeight: 220),
      ],
    );
  }
}

String _pretty(Object? value) {
  if (value == null) return 'null';
  if (value is String) return value.trim().isEmpty ? '""' : value.trim();
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } on Exception {
    return value.toString();
  }
}

String _formatTimestampSeconds(int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
  return 'Just now';
}

class _MessageSurface extends StatelessWidget {
  const _MessageSurface({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DetailSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(child: Text(message)),
      ),
    );
  }
}

class _LoadingSurface extends StatelessWidget {
  const _LoadingSurface();

  @override
  Widget build(BuildContext context) {
    return const DetailSurface(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorSurface extends StatelessWidget {
  const _ErrorSurface({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return DetailSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $error'),
      ),
    );
  }
}
