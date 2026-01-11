import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';

import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/actions/presentation/providers/actions_provider.dart';

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

class _ActionDetailViewState extends ConsumerState<ActionDetailView> {
  var _isEditingConfig = false;
  KomodoAction? _configEditSnapshot;
  final _configEditorKey = GlobalKey<ActionConfigEditorContentState>();

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
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(actionDetailProvider(actionId));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                actionAsync.when(
                  data: (action) {
                    if (action == null) {
                      return const _MessageSurface(message: 'Action not found');
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ActionHeroPanel(action: action, listItem: listItem),
                        const Gap(16),
                        DetailSection(
                          title: 'Configuration',
                          icon: AppIcons.settings,
                          trailing: _actionConfigTrailing(
                            context: context,
                            action: action,
                          ),
                          child: _isEditingConfig
                              ? ActionConfigEditorContent(
                                  key: _configEditorKey,
                                  initialConfig:
                                      (_configEditSnapshot?.id == action.id)
                                      ? _configEditSnapshot!.config
                                      : action.config,
                                )
                              : _ActionConfigContent(
                                  action: action,
                                  listItem: listItem,
                                ),
                        ),
                        if (!_isEditingConfig &&
                            (action.config.arguments.trim().isNotEmpty ||
                                action.config.fileContents
                                    .trim()
                                    .isNotEmpty)) ...[
                          const Gap(16),
                          DetailSection(
                            title: 'Script',
                            icon: AppIcons.package,
                            child: _ActionScriptContent(config: action.config),
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => const _LoadingSurface(),
                  error: (error, _) => _ErrorSurface(error: error.toString()),
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

  Widget _actionConfigTrailing({
    required BuildContext context,
    required KomodoAction action,
  }) {
    final scheme = Theme.of(context).colorScheme;

    if (!_isEditingConfig) {
      return IconButton(
        tooltip: 'Edit config',
        icon: Icon(AppIcons.edit, color: scheme.onPrimary),
        onPressed: () {
          setState(() {
            _isEditingConfig = true;
            _configEditSnapshot = action;
          });
        },
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () {
            if (_configEditSnapshot != null) {
              _configEditorKey.currentState?.resetTo(
                _configEditSnapshot!.config,
              );
            }
            setState(() {
              _isEditingConfig = false;
              _configEditSnapshot = null;
            });
          },
          child: Text('Cancel', style: TextStyle(color: scheme.onPrimary)),
        ),
        const Gap(6),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.onPrimary,
            foregroundColor: scheme.primary,
          ),
          onPressed: () => _saveConfig(context: context, actionId: action.id),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _saveConfig({
    required BuildContext context,
    required String actionId,
  }) async {
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
      AppSnackBar.show(context, 'No changes to save');
      return;
    }

    final updated = await ref
        .read(actionActionsProvider.notifier)
        .updateActionConfig(actionId: actionId, partialConfig: partialConfig);

    if (!context.mounted) return;

    if (updated == null) {
      final err = ref.read(actionActionsProvider).asError?.error;
      AppSnackBar.show(
        context,
        err != null ? 'Failed: $err' : 'Failed to update action',
        tone: AppSnackBarTone.error,
      );
      return;
    }

    ref
      ..invalidate(actionDetailProvider(actionId))
      ..invalidate(actionsProvider);

    setState(() {
      _isEditingConfig = false;
      _configEditSnapshot = null;
    });

    AppSnackBar.show(context, 'Action updated', tone: AppSnackBarTone.success);
  }
}

class ActionConfigEditorContent extends StatefulWidget {
  const ActionConfigEditorContent({required this.initialConfig, super.key});

  final ActionConfig initialConfig;

  @override
  State<ActionConfigEditorContent> createState() =>
      ActionConfigEditorContentState();
}

class ActionConfigEditorContentState extends State<ActionConfigEditorContent> {
  late ActionConfig _initial;

  late final TextEditingController _schedule;
  late final TextEditingController _scheduleTimezone;
  late final TextEditingController _webhookSecret;

  late final TextEditingController _arguments;
  late final TextEditingController _fileContents;

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
    _fileContents = TextEditingController(text: _initial.fileContents);

    _runAtStartup = _initial.runAtStartup;
    _scheduleEnabled = _initial.scheduleEnabled;
    _webhookEnabled = _initial.webhookEnabled;
    _reloadDenoDeps = _initial.reloadDenoDeps;
    _scheduleAlert = _initial.scheduleAlert;
    _failureAlert = _initial.failureAlert;
    _scheduleFormat = _initial.scheduleFormat;
    _argumentsFormat = _initial.argumentsFormat;
  }

  @override
  void dispose() {
    _schedule.dispose();
    _scheduleTimezone.dispose();
    _webhookSecret.dispose();
    _arguments.dispose();
    _fileContents.dispose();
    super.dispose();
  }

  void resetTo(ActionConfig config) {
    setState(() {
      _initial = config;

      _schedule.text = config.schedule;
      _scheduleTimezone.text = config.scheduleTimezone;
      _webhookSecret.text = config.webhookSecret;
      _arguments.text = config.arguments;
      _fileContents.text = config.fileContents;

      _runAtStartup = config.runAtStartup;
      _scheduleEnabled = config.scheduleEnabled;
      _webhookEnabled = config.webhookEnabled;
      _reloadDenoDeps = config.reloadDenoDeps;
      _scheduleAlert = config.scheduleAlert;
      _failureAlert = config.failureAlert;
      _scheduleFormat = config.scheduleFormat;
      _argumentsFormat = config.argumentsFormat;
    });
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

    final fileContents = _fileContents.text;
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
                onChanged: (v) => setState(() => _runAtStartup = v),
                title: const Text('Run at startup'),
                secondary: const Icon(AppIcons.play),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile.adaptive(
                value: _scheduleEnabled,
                onChanged: (v) => setState(() => _scheduleEnabled = v),
                title: const Text('Schedule enabled'),
                secondary: const Icon(AppIcons.clock),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile.adaptive(
                value: _webhookEnabled,
                onChanged: (v) => setState(() => _webhookEnabled = v),
                title: const Text('Webhook enabled'),
                secondary: const Icon(AppIcons.network),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile.adaptive(
                value: _reloadDenoDeps,
                onChanged: (v) => setState(() => _reloadDenoDeps = v),
                title: const Text('Reload Deno deps'),
                secondary: const Icon(AppIcons.refresh),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile.adaptive(
                value: _scheduleAlert,
                onChanged: (v) => setState(() => _scheduleAlert = v),
                title: const Text('Schedule alerts'),
                secondary: const Icon(AppIcons.notifications),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile.adaptive(
                value: _failureAlert,
                onChanged: (v) => setState(() => _failureAlert = v),
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
              DropdownButtonFormField<ScheduleFormat>(
                key: const ValueKey('action_schedule_format'),
                value: _scheduleFormat,
                items: const [
                  DropdownMenuItem(
                    value: ScheduleFormat.english,
                    child: Text('English'),
                  ),
                  DropdownMenuItem(
                    value: ScheduleFormat.cron,
                    child: Text('Cron'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _scheduleFormat = v);
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
              DropdownButtonFormField<FileFormat>(
                key: const ValueKey('action_arguments_format'),
                value: _argumentsFormat,
                items: const [
                  DropdownMenuItem(
                    value: FileFormat.keyValue,
                    child: Text('KeyValue'),
                  ),
                  DropdownMenuItem(value: FileFormat.toml, child: Text('TOML')),
                  DropdownMenuItem(value: FileFormat.yaml, child: Text('YAML')),
                  DropdownMenuItem(value: FileFormat.json, child: Text('JSON')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _argumentsFormat = v);
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
        const Gap(12),
        DetailSubCard(
          title: 'File contents',
          icon: AppIcons.package,
          child: Column(
            children: [
              TextFormField(
                controller: _fileContents,
                minLines: 6,
                maxLines: 18,
                decoration: InputDecoration(
                  labelText: 'Script',
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

class _ActionHeroPanel extends StatelessWidget {
  const _ActionHeroPanel({required this.action, required this.listItem});

  final KomodoAction action;
  final ActionListItem? listItem;

  @override
  Widget build(BuildContext context) {
    final status = listItem?.info.state;

    return DetailHeroPanel(
      header: _ActionHeader(action: action),
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
    );
  }
}

class _ActionHeader extends StatelessWidget {
  const _ActionHeader({required this.action});

  final KomodoAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = action.description.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          action.name,
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

class _ActionConfigContent extends StatelessWidget {
  const _ActionConfigContent({required this.action, required this.listItem});

  final KomodoAction action;
  final ActionListItem? listItem;

  @override
  Widget build(BuildContext context) {
    final config = action.config;
    final scheduleError = listItem?.info.scheduleError?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill.onOff(
              isOn: config.runAtStartup,
              onLabel: 'Startup on',
              offLabel: 'Startup off',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.pause,
            ),
            StatusPill.onOff(
              isOn: config.scheduleEnabled,
              onLabel: 'Schedule on',
              offLabel: 'Schedule off',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.pause,
            ),
            StatusPill.onOff(
              isOn: config.webhookEnabled,
              onLabel: 'Webhook on',
              offLabel: 'Webhook off',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.pause,
            ),
            StatusPill.onOff(
              isOn: config.reloadDenoDeps,
              onLabel: 'Reload deps',
              offLabel: 'No reload',
              onIcon: AppIcons.refresh,
              offIcon: AppIcons.pause,
            ),
            StatusPill.onOff(
              isOn: config.scheduleAlert,
              onLabel: 'Schedule alerts',
              offLabel: 'No schedule alerts',
              onIcon: AppIcons.notifications,
              offIcon: AppIcons.notifications,
            ),
            StatusPill.onOff(
              isOn: config.failureAlert,
              onLabel: 'Failure alerts',
              offLabel: 'No failure alerts',
              onIcon: AppIcons.warning,
              offIcon: AppIcons.ok,
            ),
          ],
        ),
        const Gap(14),
        DetailSubCard(
          title: 'Schedule',
          icon: AppIcons.clock,
          child: Column(
            children: [
              DetailKeyValueRow(
                label: 'Enabled',
                value: config.scheduleEnabled ? 'Yes' : 'No',
              ),
              DetailKeyValueRow(
                label: 'Format',
                value: config.scheduleFormat.name.toUpperCase(),
              ),
              DetailKeyValueRow(
                label: 'Timezone',
                value: config.scheduleTimezone.isNotEmpty
                    ? config.scheduleTimezone
                    : '—',
              ),
              DetailKeyValueRow(
                label: 'Expression',
                value: config.schedule.isNotEmpty ? config.schedule : '—',
              ),
              if (listItem?.info.nextScheduledRun != null)
                DetailKeyValueRow(
                  label: 'Next run',
                  value: _formatTimestampSeconds(
                    listItem!.info.nextScheduledRun!,
                  ),
                ),
              if (scheduleError.isNotEmpty)
                DetailKeyValueRow(
                  label: 'Schedule error',
                  value: scheduleError,
                  bottomPadding: 0,
                )
              else
                const DetailKeyValueRow(
                  label: 'Schedule error',
                  value: '—',
                  bottomPadding: 0,
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
              DetailKeyValueRow(
                label: 'Enabled',
                value: config.webhookEnabled ? 'Yes' : 'No',
              ),
              DetailKeyValueRow(
                label: 'Secret',
                value: config.webhookSecret.isNotEmpty ? 'Configured' : '—',
                bottomPadding: 0,
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
              DetailKeyValueRow(
                label: 'Format',
                value: config.argumentsFormat.displayName,
                bottomPadding: 0,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionScriptContent extends StatelessWidget {
  const _ActionScriptContent({required this.config});

  final ActionConfig config;

  @override
  Widget build(BuildContext context) {
    final args = config.arguments.trim();
    final file = config.fileContents.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (args.isNotEmpty) ...[
          Text(
            'Arguments',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Gap(8),
          DetailCodeBlock(code: args, maxHeight: 220),
        ],
        if (args.isNotEmpty && file.isNotEmpty) const Gap(16),
        if (file.isNotEmpty) ...[
          Text(
            'File contents',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Gap(8),
          DetailCodeBlock(
            code: file,
            language: DetailCodeLanguage.typescript,
            maxHeight: 420,
          ),
        ],
      ],
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
