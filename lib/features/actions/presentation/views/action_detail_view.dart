import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/syntax_highlight/app_syntax_highlight.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/menus/komodo_select_menu_field.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/actions/presentation/providers/actions_provider.dart';
import 'package:syntax_highlight/syntax_highlight.dart';

/// View displaying detailed action information.
class ActionDetailView extends ConsumerStatefulWidget {
  const ActionDetailView({
    required this.actionId,
    required this.actionName,
    super.key,
  });

  final String actionId;
  final String actionName;

  @override
  ConsumerState<ActionDetailView> createState() => _ActionDetailViewState();
}

class _ActionDetailViewState extends ConsumerState<ActionDetailView>
    with
        SingleTickerProviderStateMixin,
        DetailDirtySnackBarMixin<ActionDetailView> {
  late final TabController _tabController;
  final _outerScrollController = ScrollController();
  final _nestedScrollKey = GlobalKey<NestedScrollViewState>();
  CodeEditorController? _fileContentsController;
  final _configEditorKey = GlobalKey<ActionConfigEditorContentState>();
  var _configSaveInFlight = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _fileContentsController?.dispose();
    _fileContentsController = null;
    _tabController.dispose();
    _outerScrollController.dispose();
    super.dispose();
  }

  CodeEditorController _ensureFileContentsController(String text) {
    if (_fileContentsController != null) {
      return _fileContentsController!;
    }

    _fileContentsController = CodeEditorController(
      text: text,
      lightHighlighter: Highlighter(
        language: 'typescript',
        theme: AppSyntaxHighlight.lightTheme,
      ),
      darkHighlighter: Highlighter(
        language: 'typescript',
        theme: AppSyntaxHighlight.darkTheme,
      ),
    );
    return _fileContentsController!;
  }

  @override
  Widget build(BuildContext context) {
    final actionId = widget.actionId;
    final actionAsync = ref.watch(actionDetailProvider(actionId));
    final actionsListAsync = ref.watch(actionsProvider);
    final actionsState = ref.watch(actionActionsProvider);
    final scheme = Theme.of(context).colorScheme;

    ActionListItem? listItem;
    final list = actionsListAsync.asData?.value;
    if (list != null) {
      for (final item in list) {
        if (item.id == actionId) {
          listItem = item;
          break;
        }
      }
    }

    return Scaffold(
      appBar: MainAppBar(
        title: widget.actionName,
        icon: AppIcons.actions,
        markColor: AppTokens.resourceActions,
        markUseGradient: true,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(AppIcons.play),
            tooltip: 'Run',
            onPressed: () => _runAction(context, actionId),
          ),
        ],
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
                    child: actionAsync.when(
                      data: (action) {
                        if (action == null) {
                          return const _MessageSurface(
                            message: 'Action not found',
                          );
                        }

                        return _ActionHeroPanel(
                          action: action,
                          listItem: listItem,
                        );
                      },
                      loading: () => const _LoadingSurface(),
                      error: (error, _) =>
                          _ErrorSurface(error: error.toString()),
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
                          Tab(
                            icon: Icon(AppIcons.bolt),
                            text: 'Config',
                          ),
                          Tab(
                            icon: Icon(AppIcons.notepadText),
                            text: 'File content',
                          ),
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
                      ref.invalidate(actionDetailProvider(actionId));
                    },
                    child: DetailTabScrollView.box(
                      scrollKey:
                          PageStorageKey('action_${widget.actionId}_config'),
                      child: actionAsync.when(
                        data: (action) {
                          if (action == null) {
                            return const _MessageSurface(
                              message: 'Action not found',
                            );
                          }

                          final fileController =
                              _ensureFileContentsController(
                                action.config.fileContents,
                              );
                          return ActionConfigEditorContent(
                            key: _configEditorKey,
                            initialConfig: action.config,
                            fileContentsController: fileController,
                            onDirtyChanged: (dirty) {
                              syncDirtySnackBar(
                                dirty: dirty,
                                onDiscard: () => _discardConfig(action),
                                onSave: () => _saveConfig(action: action),
                                saveEnabled: !_configSaveInFlight,
                              );
                            },
                          );
                        },
                        loading: () => const _LoadingSurface(),
                        error: (error, _) =>
                            _ErrorSurface(error: error.toString()),
                      ),
                    ),
                  ),
                ),
                _KeepAlive(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(actionDetailProvider(actionId));
                    },
                    child: DetailTabScrollView.box(
                      scrollKey: PageStorageKey(
                        'action_${widget.actionId}_file_content',
                      ),
                      child: actionAsync.when(
                        data: (action) {
                          if (action == null) {
                            return const _MessageSurface(
                              message: 'Action not found',
                            );
                          }

                          final fileController =
                              _ensureFileContentsController(
                                action.config.fileContents,
                              );
                          return DetailCodeEditor(
                            controller: fileController,
                            maxHeight: 420,
                          );
                        },
                        loading: () => const _LoadingSurface(),
                        error: (error, _) =>
                            _ErrorSurface(error: error.toString()),
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

  Future<void> _runAction(BuildContext context, String actionId) async {
    final actions = ref.read(actionActionsProvider.notifier);
    final success = await actions.run(actionId);

    if (success) {
      ref
        ..invalidate(actionDetailProvider(actionId))
        ..invalidate(actionsProvider);
    }

    if (context.mounted) {
      AppSnackBar.show(
        context,
        success ? 'Action started' : 'Action failed. Please try again.',
        tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
      );
    }
  }

  void _discardConfig(KomodoAction action) {
    _configEditorKey.currentState?.resetTo(action.config);
    hideDirtySnackBar();
  }

  Future<void> _saveConfig({required KomodoAction action}) async {
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
        .read(actionActionsProvider.notifier)
        .updateActionConfig(actionId: action.id, partialConfig: partialConfig);
    if (!mounted) return;
    setState(() => _configSaveInFlight = false);

    if (updated != null) {
      ref
        ..invalidate(actionDetailProvider(widget.actionId))
        ..invalidate(actionDetailProvider(action.id))
        ..invalidate(actionsProvider);

      _configEditorKey.currentState?.resetTo(updated.config);
      hideDirtySnackBar();
      AppSnackBar.show(
        context,
        'Action updated',
        tone: AppSnackBarTone.success,
      );
      return;
    }

    final err = ref.read(actionActionsProvider).asError?.error;
    AppSnackBar.show(
      context,
      err != null ? 'Failed: $err' : 'Failed to update action',
      tone: AppSnackBarTone.error,
    );

    reShowDirtySnackBarIfStillDirty(
      isStillDirty: () {
        return _configEditorKey.currentState
                ?.buildPartialConfigParams()
                .isNotEmpty ??
            false;
      },
      onDiscard: () => _discardConfig(action),
      onSave: () => _saveConfig(action: action),
      saveEnabled: !_configSaveInFlight,
    );
  }
}

class ActionConfigEditorContent extends StatefulWidget {
  const ActionConfigEditorContent({
    required this.initialConfig,
    this.onDirtyChanged,
    this.fileContentsController,
    super.key,
  });

  final ActionConfig initialConfig;
  final ValueChanged<bool>? onDirtyChanged;
  final CodeEditorController? fileContentsController;

  @override
  State<ActionConfigEditorContent> createState() =>
      ActionConfigEditorContentState();
}

class ActionConfigEditorContentState extends State<ActionConfigEditorContent> {
  late ActionConfig _initial;

  var _lastDirty = false;
  var _suppressDirtyNotify = false;

  late final TextEditingController _schedule;
  late final TextEditingController _scheduleTimezone;
  late final TextEditingController _webhookSecret;

  late final TextEditingController _arguments;
  late CodeEditorController _fileContentsController;
  CodeEditorController get fileContentsController => _fileContentsController;
  late final bool _ownsFileContentsController;

  var _runAtStartup = false;
  var _scheduleEnabled = false;
  var _webhookEnabled = false;
  var _reloadDenoDeps = false;
  var _scheduleAlert = false;
  var _failureAlert = false;
  var _scheduleFormat = ScheduleFormat.english;
  var _argumentsFormat = FileFormat.keyValue;

  @override
  void initState() {
    super.initState();
    _initial = widget.initialConfig;

    _schedule = TextEditingController(text: _initial.schedule);
    _scheduleTimezone = TextEditingController(text: _initial.scheduleTimezone);
    _webhookSecret = TextEditingController(text: _initial.webhookSecret);
    _arguments = TextEditingController(text: _initial.arguments);
    final externalController = widget.fileContentsController;
    if (externalController != null) {
      _fileContentsController = externalController;
      _ownsFileContentsController = false;
    } else {
      _fileContentsController = _createCodeController(
        language: 'typescript',
        text: _initial.fileContents,
      );
      _ownsFileContentsController = true;
    }

    _runAtStartup = _initial.runAtStartup;
    _scheduleEnabled = _initial.scheduleEnabled;
    _webhookEnabled = _initial.webhookEnabled;
    _reloadDenoDeps = _initial.reloadDenoDeps;
    _scheduleAlert = _initial.scheduleAlert;
    _failureAlert = _initial.failureAlert;
    _scheduleFormat = _initial.scheduleFormat;
    _argumentsFormat = _initial.argumentsFormat;

    for (final c in <ChangeNotifier>[
      _schedule,
      _scheduleTimezone,
      _webhookSecret,
      _arguments,
      _fileContentsController,
    ]) {
      c.addListener(_notifyDirtyIfChanged);
    }
  }

  @override
  void didUpdateWidget(covariant ActionConfigEditorContent oldWidget) {
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
    for (final c in <ChangeNotifier>[
      _schedule,
      _scheduleTimezone,
      _webhookSecret,
      _arguments,
      _fileContentsController,
    ]) {
      c.removeListener(_notifyDirtyIfChanged);
    }

    _schedule.dispose();
    _scheduleTimezone.dispose();
    _webhookSecret.dispose();
    _arguments.dispose();
    if (_ownsFileContentsController) {
      _fileContentsController.dispose();
    }
    super.dispose();
  }

  CodeEditorController _createCodeController({
    required String language,
    required String text,
  }) {
    return CodeEditorController(
      text: text,
      lightHighlighter: Highlighter(
        language: language,
        theme: AppSyntaxHighlight.lightTheme,
      ),
      darkHighlighter: Highlighter(
        language: language,
        theme: AppSyntaxHighlight.darkTheme,
      ),
    );
  }

  void resetTo(ActionConfig config) {
    _suppressDirtyNotify = true;
    setState(() {
      _initial = config;

      _schedule.text = config.schedule;
      _scheduleTimezone.text = config.scheduleTimezone;
      _webhookSecret.text = config.webhookSecret;
      _arguments.text = config.arguments;

      _fileContentsController.removeListener(_notifyDirtyIfChanged);
      if (_ownsFileContentsController) {
        _fileContentsController.dispose();
        _fileContentsController = _createCodeController(
          language: 'typescript',
          text: config.fileContents,
        );
      } else {
        _fileContentsController.text = config.fileContents;
      }
      _fileContentsController.addListener(_notifyDirtyIfChanged);

      _runAtStartup = config.runAtStartup;
      _scheduleEnabled = config.scheduleEnabled;
      _webhookEnabled = config.webhookEnabled;
      _reloadDenoDeps = config.reloadDenoDeps;
      _scheduleAlert = config.scheduleAlert;
      _failureAlert = config.failureAlert;
      _scheduleFormat = config.scheduleFormat;
      _argumentsFormat = config.argumentsFormat;
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

    setIfChanged('run_at_startup', _runAtStartup, _initial.runAtStartup);
    setIfChanged(
      'schedule_enabled',
      _scheduleEnabled,
      _initial.scheduleEnabled,
    );
    setIfChanged('webhook_enabled', _webhookEnabled, _initial.webhookEnabled);
    setIfChanged('reload_deno_deps', _reloadDenoDeps, _initial.reloadDenoDeps);
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
      params['schedule_format'] = switch (_scheduleFormat) {
        ScheduleFormat.cron => 'Cron',
        ScheduleFormat.english => 'English',
      };
    }

    if (_argumentsFormat != _initial.argumentsFormat) {
      params['arguments_format'] = switch (_argumentsFormat) {
        FileFormat.keyValue => 'KeyValue',
        FileFormat.toml => 'Toml',
        FileFormat.yaml => 'Yaml',
        FileFormat.json => 'Json',
      };
    }

    final arguments = _arguments.text;
    setIfChanged('arguments', arguments, _initial.arguments);

    final fileContents = _fileContentsController.text;
    setIfChanged('file_contents', fileContents, _initial.fileContents);

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
                value: _runAtStartup,
                onChanged: (v) {
                  setState(() => _runAtStartup = v);
                  _notifyDirtyIfChanged();
                },
                title: const Text('Run at startup'),
                secondary: const Icon(AppIcons.play),
                contentPadding: EdgeInsets.zero,
              ),
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
                value: _reloadDenoDeps,
                onChanged: (v) {
                  setState(() => _reloadDenoDeps = v);
                  _notifyDirtyIfChanged();
                },
                title: const Text('Reload Deno deps'),
                secondary: const Icon(AppIcons.refresh),
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
                key: const ValueKey('action_schedule_format'),
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
        const Gap(12),
        DetailSubCard(
          title: 'Arguments',
          icon: AppIcons.tag,
          child: Column(
            children: [
              KomodoSelectMenuField<FileFormat>(
                key: const ValueKey('action_arguments_format'),
                value: _argumentsFormat,
                items: const [
                  KomodoSelectMenuItem(
                    value: FileFormat.keyValue,
                    label: 'KeyValue',
                  ),
                  KomodoSelectMenuItem(value: FileFormat.toml, label: 'TOML'),
                  KomodoSelectMenuItem(value: FileFormat.yaml, label: 'YAML'),
                  KomodoSelectMenuItem(value: FileFormat.json, label: 'JSON'),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _argumentsFormat = v);
                  _notifyDirtyIfChanged();
                },
                decoration: const InputDecoration(
                  labelText: 'Arguments format',
                  prefixIcon: Icon(AppIcons.tag),
                ),
              ),
              const Gap(12),
              TextFormField(
                controller: _arguments,
                minLines: 2,
                maxLines: 10,
                decoration: InputDecoration(
                  labelText: 'Arguments',
                  prefixIcon: const Icon(AppIcons.package),
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

class _ActionHeroPanel extends StatelessWidget {
  const _ActionHeroPanel({required this.action, required this.listItem});

  final KomodoAction action;
  final ActionListItem? listItem;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final status = listItem?.info.state;
    final description = action.description.trim();

    return DetailHeroPanel(
      metrics: [
        if (status != null)
          DetailMetricTileData(
            label: 'Status',
            value: status.displayName,
            icon: switch (status) {
              ActionState.ok => AppIcons.ok,
              ActionState.failed => AppIcons.error,
              ActionState.running => AppIcons.loading,
              ActionState.unknown => AppIcons.unknown,
            },
            tone: switch (status) {
              ActionState.ok => DetailMetricTone.success,
              ActionState.failed => DetailMetricTone.alert,
              ActionState.running => DetailMetricTone.neutral,
              ActionState.unknown => DetailMetricTone.neutral,
            },
          ),
        DetailMetricTileData(
          label: 'Startup',
          value: action.config.runAtStartup ? 'On' : 'Off',
          icon: action.config.runAtStartup ? AppIcons.ok : AppIcons.pause,
          tone: action.config.runAtStartup
              ? DetailMetricTone.success
              : DetailMetricTone.neutral,
        ),
        if (listItem?.info.lastRunAt != null)
          DetailMetricTileData(
            label: 'Last Run',
            value: _formatTimestampSeconds(listItem!.info.lastRunAt!),
            icon: AppIcons.clock,
            tone: DetailMetricTone.neutral,
          ),
        if (action.config.scheduleEnabled)
          DetailMetricTileData(
            label: 'Schedule',
            value: action.config.schedule.isNotEmpty
                ? action.config.schedule
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
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (action.tags.isNotEmpty)
            DetailPillList(
              items: action.tags,
              showEmptyLabel: false,
            ),
          if (description.isNotEmpty) ...[
            if (action.tags.isNotEmpty) const Gap(12),
            Text(
              'Description',
              style: textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(6),
            Text(
              description,
              style: textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
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
    return const AppSkeletonSurface();
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
