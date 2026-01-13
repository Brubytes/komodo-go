import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/syntax_highlight/app_syntax_highlight.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/menus/komodo_select_menu_field.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:syntax_highlight/syntax_highlight.dart';

class StackHeroPanel extends StatelessWidget {
  const StackHeroPanel({
    required this.stack,
    required this.listItem,
    required this.serviceCount,
    required this.updateCount,
    required this.serverName,
    super.key,
  });

  final KomodoStack stack;
  final StackListItem? listItem;
  final int? serviceCount;
  final int? updateCount;
  final String? serverName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final config = stack.config;
    final info = stack.info;

    final state = listItem?.info.state;
    final status = listItem?.info.status;
    final projectMissing = listItem?.info.projectMissing ?? false;

    final missingCount = info.missingFiles.length;
    final upToDate =
        info.latestHash != null && info.deployedHash == info.latestHash;

    return DetailHeroPanel(
      tintColor: scheme.surface,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stack.description.trim().isNotEmpty) ...[
            DetailIconInfoRow(
              icon: AppIcons.tag,
              label: 'Description',
              value: stack.description.trim(),
            ),
            const Gap(10),
          ],
          if (config.serverId.isNotEmpty) ...[
            DetailIconInfoRow(
              icon: AppIcons.server,
              label: 'Server',
              value: serverName ?? config.serverId,
            ),
            const Gap(10),
          ],
          if (status?.trim().isNotEmpty ?? false) ...[
            DetailIconInfoRow(
              icon: AppIcons.activity,
              label: 'Status',
              value: status!.trim(),
            ),
            const Gap(10),
          ],
          if (config.repo.isNotEmpty) ...[
            DetailIconInfoRow(
              icon: AppIcons.repos,
              label: 'Repo',
              value: config.branch.isNotEmpty
                  ? '${config.repo} (${config.branch})'
                  : config.repo,
            ),
            const Gap(10),
          ],
          if (config.runDirectory.isNotEmpty)
            DetailIconInfoRow(
              icon: AppIcons.package,
              label: 'Directory',
              value: config.runDirectory,
            ),
        ],
      ),
      metrics: [
        DetailMetricTileData(
          icon: _stateIcon(state),
          label: 'State',
          value: state?.displayName ?? '—',
          tone: _stateTone(state),
        ),
        DetailMetricTileData(
          icon: AppIcons.repos,
          label: 'Branch',
          value: config.branch.isNotEmpty ? config.branch : '—',
          tone: DetailMetricTone.neutral,
        ),
        DetailMetricTileData(
          icon: AppIcons.widgets,
          label: 'Services',
          value: serviceCount?.toString() ?? '—',
          tone: DetailMetricTone.neutral,
        ),
        DetailMetricTileData(
          icon: AppIcons.updateAvailable,
          label: 'Updates',
          value: updateCount?.toString() ?? '—',
          tone: (updateCount ?? 0) > 0
              ? DetailMetricTone.tertiary
              : DetailMetricTone.success,
        ),
        DetailMetricTileData(
          icon: AppIcons.warning,
          label: 'Missing',
          value: missingCount.toString(),
          tone: missingCount > 0
              ? DetailMetricTone.tertiary
              : DetailMetricTone.success,
        ),
        DetailMetricTileData(
          icon: upToDate ? AppIcons.ok : AppIcons.warning,
          label: 'Git',
          value: upToDate ? 'Up to date' : 'Out of date',
          tone: upToDate ? DetailMetricTone.success : DetailMetricTone.tertiary,
        ),
      ],
      footer: DetailPillList(
        items: stack.tags,
        showEmptyLabel: false,
        leading: [
          if (projectMissing)
            const StatusPill(
              label: 'Project missing',
              icon: AppIcons.warning,
              tone: PillTone.warning,
            ),
        ],
      ),
    );
  }

  IconData _stateIcon(StackState? state) {
    return switch (state) {
      StackState.running => AppIcons.ok,
      StackState.deploying || StackState.restarting => AppIcons.loading,
      StackState.unhealthy => AppIcons.error,
      StackState.stopped ||
      StackState.created ||
      StackState.down ||
      StackState.dead => AppIcons.stopped,
      StackState.paused => AppIcons.paused,
      StackState.removing => AppIcons.warning,
      _ => AppIcons.unknown,
    };
  }

  DetailMetricTone _stateTone(StackState? state) {
    return switch (state) {
      StackState.running => DetailMetricTone.success,
      StackState.deploying || StackState.restarting => DetailMetricTone.primary,
      StackState.unhealthy => DetailMetricTone.alert,
      StackState.stopped ||
      StackState.created ||
      StackState.down ||
      StackState.dead => DetailMetricTone.neutral,
      StackState.paused => DetailMetricTone.secondary,
      _ => DetailMetricTone.neutral,
    };
  }
}

class StackConfigContent extends StatelessWidget {
  const StackConfigContent({
    required this.config,
    required this.serverName,
    super.key,
  });

  final StackConfig config;
  final String? serverName;

  @override
  Widget build(BuildContext context) {
    final compose = config.fileContents.trim();
    final environment = config.environment.trim();
    final isLinkedToRepo = config.linkedRepo.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill.onOff(
              isOn: config.autoPull,
              onLabel: 'Auto pull',
              offLabel: 'Manual pull',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.pause,
            ),
            StatusPill.onOff(
              isOn: config.autoUpdate,
              onLabel: 'Auto update',
              offLabel: 'Manual update',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.pause,
            ),
            StatusPill.onOff(
              isOn: config.pollForUpdates,
              onLabel: 'Polling on',
              offLabel: 'Polling off',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.pause,
            ),
            StatusPill.onOff(
              isOn: config.sendAlerts,
              onLabel: 'Alerts on',
              offLabel: 'Alerts off',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.notifications,
            ),
          ],
        ),
        if (isLinkedToRepo) ...[
          const Gap(14),
          DetailSubCard(
            title: 'Repository',
            icon: AppIcons.repos,
            child: Column(
              children: [
                DetailKeyValueRow(
                  label: 'Repo',
                  value: config.repo.isNotEmpty ? config.repo : '—',
                ),
                DetailKeyValueRow(
                  label: 'Branch',
                  value: config.branch.isNotEmpty ? config.branch : '—',
                ),
                DetailKeyValueRow(
                  label: 'Commit',
                  value: config.commit.isNotEmpty ? config.commit : '—',
                  bottomPadding: 0,
                ),
              ],
            ),
          ),
        ],
        const Gap(12),
        DetailSubCard(
          title: 'Paths',
          icon: AppIcons.package,
          child: Column(
            children: [
              DetailKeyValueRow(
                label: 'Project',
                value: config.projectName.isNotEmpty ? config.projectName : '—',
              ),
              DetailKeyValueRow(
                label: 'Clone path',
                value: config.clonePath.isNotEmpty ? config.clonePath : '—',
              ),
              DetailKeyValueRow(
                label: 'Run dir',
                value: config.runDirectory.isNotEmpty
                    ? config.runDirectory
                    : '—',
              ),
              DetailKeyValueRow(
                label: 'Env file',
                value: config.envFilePath.isNotEmpty ? config.envFilePath : '—',
                bottomPadding: 0,
              ),
            ],
          ),
        ),
        if (config.links.isNotEmpty ||
            config.additionalEnvFiles.isNotEmpty ||
            config.filePaths.isNotEmpty ||
            config.ignoreServices.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Extras',
            icon: AppIcons.widgets,
            child: Column(
              children: [
                if (config.links.isNotEmpty)
                  DetailKeyValueRow(
                    label: 'Links',
                    value: config.links.join('\n'),
                  ),
                if (config.additionalEnvFiles.isNotEmpty)
                  DetailKeyValueRow(
                    label: 'Extra env',
                    value: config.additionalEnvFiles.join('\n'),
                  ),
                if (config.filePaths.isNotEmpty)
                  DetailKeyValueRow(
                    label: 'Files',
                    value: config.filePaths.join('\n'),
                  ),
                if (config.ignoreServices.isNotEmpty)
                  DetailKeyValueRow(
                    label: 'Ignore',
                    value: config.ignoreServices.join(', '),
                    bottomPadding: 0,
                  ),
              ],
            ),
          ),
        ],
        if (config.serverId.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Server',
            icon: AppIcons.server,
            child: DetailKeyValueRow(
              label: 'Server',
              value: serverName ?? config.serverId,
              bottomPadding: 0,
            ),
          ),
        ],
        if (isLinkedToRepo) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Linked repo',
            icon: AppIcons.repos,
            child: DetailKeyValueRow(
              label: 'Repo',
              value: config.linkedRepo,
              bottomPadding: 0,
            ),
          ),
        ],
        if (compose.isNotEmpty || environment.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Compose',
            icon: AppIcons.stacks,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (config.filePaths.isNotEmpty) ...[
                  DetailPillList(items: config.filePaths),
                  const Gap(12),
                ],
                if (compose.isNotEmpty)
                  DetailCodeBlock(
                    code: compose,
                    language: DetailCodeLanguage.yaml,
                  )
                else
                  const Text('No compose contents available'),
                const Gap(12),
                Text(
                  'Environment variables',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(8),
                if (environment.isNotEmpty)
                  DetailCodeBlock(code: environment)
                else
                  const Text('No environment variables available'),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class StackConfigEditorContent extends StatefulWidget {
  const StackConfigEditorContent({
    required this.initialConfig,
    this.servers = const [],
    this.repos = const [],
    this.onDirtyChanged,
    super.key,
  });

  final StackConfig initialConfig;
  final List<Server> servers;
  final List<RepoListItem> repos;
  final ValueChanged<bool>? onDirtyChanged;

  @override
  State<StackConfigEditorContent> createState() =>
      StackConfigEditorContentState();
}

class StackConfigEditorContentState extends State<StackConfigEditorContent> {
  late StackConfig _initial;

  var _lastDirty = false;
  var _suppressDirtyNotify = false;

  late final TextEditingController _serverId;
  late final TextEditingController _repo;
  late final TextEditingController _branch;
  late final TextEditingController _commit;
  late final TextEditingController _linkedRepo;
  late final TextEditingController _projectName;
  late final TextEditingController _clonePath;
  late final TextEditingController _runDirectory;
  late final TextEditingController _envFilePath;
  late final TextEditingController _webhookSecret;

  final List<TextEditingController> _linkControllers = [];
  final List<TextEditingController> _additionalEnvFileControllers = [];
  final List<TextEditingController> _filePathControllers = [];
  final List<TextEditingController> _ignoreServiceControllers = [];

  late CodeEditorController _composeController;
  late CodeEditorController _environmentController;

  late bool _autoPull;
  late bool _autoUpdate;
  late bool _pollForUpdates;
  late bool _sendAlerts;

  late bool _reclone;

  late bool _webhookEnabled;
  late bool _webhookForceDeploy;

  @override
  void initState() {
    super.initState();
    _initial = widget.initialConfig;

    _serverId = TextEditingController(text: _initial.serverId);
    _repo = TextEditingController(text: _initial.repo);
    _branch = TextEditingController(text: _initial.branch);
    _commit = TextEditingController(text: _initial.commit);
    _linkedRepo = TextEditingController(text: _initial.linkedRepo);
    _projectName = TextEditingController(text: _initial.projectName);
    _clonePath = TextEditingController(text: _initial.clonePath);
    _runDirectory = TextEditingController(text: _initial.runDirectory);
    _envFilePath = TextEditingController(text: _initial.envFilePath);
    _webhookSecret = TextEditingController(text: _initial.webhookSecret);

    _setRowControllers(_linkControllers, _initial.links);
    _setRowControllers(
      _additionalEnvFileControllers,
      _initial.additionalEnvFiles,
    );
    _setRowControllers(_filePathControllers, _initial.filePaths);
    _setRowControllers(_ignoreServiceControllers, _initial.ignoreServices);

    _autoPull = _initial.autoPull;
    _autoUpdate = _initial.autoUpdate;
    _pollForUpdates = _initial.pollForUpdates;
    _sendAlerts = _initial.sendAlerts;

    _reclone = _initial.reclone;

    _webhookEnabled = _initial.webhookEnabled;
    _webhookForceDeploy = _initial.webhookForceDeploy;

    _composeController = _createCodeController(
      language: 'yaml',
      text: _initial.fileContents,
    );
    _environmentController = _createCodeController(
      // No native dotenv language is registered in app highlight init.
      // We still use a CodeEditor as requested.
      language: 'yaml',
      text: _initial.environment,
    );

    for (final c in <ChangeNotifier>[
      _serverId,
      _repo,
      _branch,
      _commit,
      _linkedRepo,
      _projectName,
      _clonePath,
      _runDirectory,
      _envFilePath,
      _webhookSecret,
      _composeController,
      _environmentController,
    ]) {
      c.addListener(_notifyDirtyIfChanged);
    }
  }

  @override
  void didUpdateWidget(covariant StackConfigEditorContent oldWidget) {
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
      _serverId,
      _repo,
      _branch,
      _commit,
      _linkedRepo,
      _projectName,
      _clonePath,
      _runDirectory,
      _envFilePath,
      _webhookSecret,
      _composeController,
      _environmentController,
    ]) {
      c.removeListener(_notifyDirtyIfChanged);
    }

    _serverId.dispose();
    _repo.dispose();
    _branch.dispose();
    _commit.dispose();
    _linkedRepo.dispose();
    _projectName.dispose();
    _clonePath.dispose();
    _runDirectory.dispose();
    _envFilePath.dispose();
    _webhookSecret.dispose();

    _disposeRowControllers(_linkControllers);
    _disposeRowControllers(_additionalEnvFileControllers);
    _disposeRowControllers(_filePathControllers);
    _disposeRowControllers(_ignoreServiceControllers);

    _composeController.dispose();
    _environmentController.dispose();
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

  void _disposeRowControllers(List<TextEditingController> controllers) {
    for (final c in controllers) {
      c.removeListener(_notifyDirtyIfChanged);
      c.dispose();
    }
    controllers.clear();
  }

  void _setRowControllers(
    List<TextEditingController> target,
    List<String> values,
  ) {
    _disposeRowControllers(target);

    final cleaned = values.map((e) => e.trim()).where((e) => e.isNotEmpty);
    target.addAll(cleaned.map((e) => TextEditingController(text: e)).toList());
    for (final c in target) {
      c.addListener(_notifyDirtyIfChanged);
    }
  }

  void _addRow(List<TextEditingController> target) {
    setState(() {
      final c = TextEditingController();
      c.addListener(_notifyDirtyIfChanged);
      target.add(c);
    });
    _notifyDirtyIfChanged();
  }

  void _removeRow(List<TextEditingController> target, int index) {
    if (index < 0 || index >= target.length) return;
    setState(() {
      final c = target.removeAt(index);
      c.removeListener(_notifyDirtyIfChanged);
      c.dispose();
    });
    _notifyDirtyIfChanged();
  }

  void resetTo(StackConfig config) {
    _suppressDirtyNotify = true;

    _setRowControllers(_linkControllers, config.links);
    _setRowControllers(
      _additionalEnvFileControllers,
      config.additionalEnvFiles,
    );
    _setRowControllers(_filePathControllers, config.filePaths);
    _setRowControllers(_ignoreServiceControllers, config.ignoreServices);

    setState(() {
      _initial = config;
      _serverId.text = config.serverId;
      _repo.text = config.repo;
      _branch.text = config.branch;
      _commit.text = config.commit;
      _linkedRepo.text = config.linkedRepo;
      _projectName.text = config.projectName;
      _clonePath.text = config.clonePath;
      _runDirectory.text = config.runDirectory;
      _envFilePath.text = config.envFilePath;
      _autoPull = config.autoPull;
      _autoUpdate = config.autoUpdate;
      _pollForUpdates = config.pollForUpdates;
      _sendAlerts = config.sendAlerts;

      _reclone = config.reclone;

      _webhookEnabled = config.webhookEnabled;
      _webhookForceDeploy = config.webhookForceDeploy;
      _webhookSecret.text = config.webhookSecret;

      _composeController.removeListener(_notifyDirtyIfChanged);
      _environmentController.removeListener(_notifyDirtyIfChanged);
      _composeController.dispose();
      _environmentController.dispose();
      _composeController = _createCodeController(
        language: 'yaml',
        text: config.fileContents,
      );
      _environmentController = _createCodeController(
        language: 'yaml',
        text: config.environment,
      );

      _composeController.addListener(_notifyDirtyIfChanged);
      _environmentController.addListener(_notifyDirtyIfChanged);
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

    void setIfChanged<T>(String key, T current, T initial) {
      if (current != initial) params[key] = current;
    }

    void setListIfChanged(
      String key,
      List<TextEditingController> controllers,
      List<String> initial,
    ) {
      final cleaned = controllers
          .map((c) => c.text.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final initCleaned = initial
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (!_listEquals(cleaned, initCleaned)) {
        params[key] = cleaned;
      }
    }

    setIfChanged('server_id', _serverId.text.trim(), _initial.serverId);
    setIfChanged('repo', _repo.text.trim(), _initial.repo);
    setIfChanged('branch', _branch.text.trim(), _initial.branch);
    setIfChanged('commit', _commit.text.trim(), _initial.commit);
    setIfChanged('linked_repo', _linkedRepo.text.trim(), _initial.linkedRepo);
    setIfChanged(
      'project_name',
      _projectName.text.trim(),
      _initial.projectName,
    );
    setIfChanged('clone_path', _clonePath.text.trim(), _initial.clonePath);
    setIfChanged(
      'run_directory',
      _runDirectory.text.trim(),
      _initial.runDirectory,
    );
    setIfChanged(
      'env_file_path',
      _envFilePath.text.trim(),
      _initial.envFilePath,
    );

    setIfChanged('auto_pull', _autoPull, _initial.autoPull);
    setIfChanged('auto_update', _autoUpdate, _initial.autoUpdate);
    setIfChanged('poll_for_updates', _pollForUpdates, _initial.pollForUpdates);
    setIfChanged('send_alerts', _sendAlerts, _initial.sendAlerts);

    setIfChanged('reclone', _reclone, _initial.reclone);

    setIfChanged('webhook_enabled', _webhookEnabled, _initial.webhookEnabled);
    setIfChanged(
      'webhook_force_deploy',
      _webhookForceDeploy,
      _initial.webhookForceDeploy,
    );
    setIfChanged('webhook_secret', _webhookSecret.text, _initial.webhookSecret);

    setListIfChanged('links', _linkControllers, _initial.links);
    setListIfChanged(
      'additional_env_files',
      _additionalEnvFileControllers,
      _initial.additionalEnvFiles,
    );
    setListIfChanged('file_paths', _filePathControllers, _initial.filePaths);
    setListIfChanged(
      'ignore_services',
      _ignoreServiceControllers,
      _initial.ignoreServices,
    );

    final compose = _composeController.text;
    if (compose != _initial.fileContents) params['file_contents'] = compose;

    final env = _environmentController.text;
    if (env != _initial.environment) params['environment'] = env;

    return params;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final servers = widget.servers;
    final repos = widget.repos;

    final sortedServers = [...servers]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final sortedRepos = [...repos]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final serverIdInList = sortedServers.any((s) => s.id == _serverId.text);
    final linkedRepoInList = sortedRepos.any((r) => r.id == _linkedRepo.text);

    // Repo mode should react to edits, not just the initial config.
    final hasRepoConfig =
        _linkedRepo.text.trim().isNotEmpty ||
        _repo.text.trim().isNotEmpty ||
        _branch.text.trim().isNotEmpty ||
        _clonePath.text.trim().isNotEmpty;

    // Track if a linked repo is currently selected
    final hasLinkedRepo = _linkedRepo.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Server
        DetailSubCard(
          title: 'Server',
          icon: AppIcons.server,
          child: Column(
            children: [
              if (sortedServers.isNotEmpty)
                KomodoSelectMenuField<String>(
                  key: ValueKey(sortedServers.length),
                  value: serverIdInList ? _serverId.text : null,
                  decoration: InputDecoration(
                    labelText: 'Server',
                    prefixIcon: const Icon(AppIcons.server),
                    helperStyle: TextStyle(color: scheme.onSurfaceVariant),
                    helperText: 'Select the server to deploy on.',
                  ),
                  items: [
                    for (final server in sortedServers)
                      KomodoSelectMenuItem(
                        value: server.id,
                        label: server.name,
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _serverId.text = value);
                  },
                )
              else
                TextFormField(
                  controller: _serverId,
                  decoration: InputDecoration(
                    labelText: 'Server ID',
                    prefixIcon: const Icon(AppIcons.server),
                    helperStyle: TextStyle(color: scheme.onSurfaceVariant),
                    helperText: 'Select the server to deploy on.',
                  ),
                ),
              if (sortedServers.isNotEmpty && !serverIdInList) ...[
                const Gap(8),
                TextFormField(
                  controller: _serverId,
                  decoration: const InputDecoration(
                    labelText: 'Server ID (manual)',
                    prefixIcon: Icon(AppIcons.tag),
                    helperText: 'Current value not found in server list.',
                  ),
                ),
              ],
            ],
          ),
        ),
        const Gap(12),

        // 2. Source (repo section)
        if (hasRepoConfig) ...[
          DetailSubCard(
            title: 'Source',
            icon: AppIcons.repos,
            child: Column(
              children: [
                // Linked repo selector (always shown in this section)
                if (sortedRepos.isNotEmpty)
                  KomodoSelectMenuField<String>(
                    key: ValueKey(sortedRepos.length),
                    value: linkedRepoInList ? _linkedRepo.text : null,
                    decoration: const InputDecoration(
                      labelText: 'Repo',
                      prefixIcon: Icon(AppIcons.repos),
                      helperText:
                          'Select an existing Repo to attach, or configure below.',
                    ),
                    items: [
                      for (final repo in sortedRepos)
                        KomodoSelectMenuItem(
                          value: repo.id,
                          label: repo.info.repo.trim().isNotEmpty
                              ? '${repo.name} · ${repo.info.repo.trim()}'
                              : repo.name,
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _linkedRepo.text = value);
                      _notifyDirtyIfChanged();
                    },
                  )
                else
                  TextFormField(
                    controller: _linkedRepo,
                    decoration: const InputDecoration(
                      labelText: 'Linked repo',
                      prefixIcon: Icon(AppIcons.repos),
                    ),
                  ),
                if (sortedRepos.isNotEmpty && !linkedRepoInList) ...[
                  const Gap(8),
                  TextFormField(
                    controller: _linkedRepo,
                    decoration: const InputDecoration(
                      labelText: 'Linked repo ID (manual)',
                      prefixIcon: Icon(AppIcons.tag),
                      helperText: 'Current value not found in repo list.',
                    ),
                  ),
                ],

                // Only show manual git config fields when NO linked repo is selected
                if (!hasLinkedRepo) ...[
                  const Gap(12),
                  TextFormField(
                    controller: _repo,
                    decoration: const InputDecoration(
                      labelText: 'Repo path',
                      prefixIcon: Icon(AppIcons.repos),
                      helperText: 'The repo path: {namespace}/{repo_name}',
                    ),
                  ),
                  const Gap(12),
                  TextFormField(
                    controller: _branch,
                    decoration: const InputDecoration(
                      labelText: 'Branch',
                      prefixIcon: Icon(AppIcons.repos),
                      helperText: "Custom branch, or defaults to 'main'.",
                    ),
                  ),
                  const Gap(12),
                  TextFormField(
                    controller: _commit,
                    decoration: const InputDecoration(
                      labelText: 'Commit hash',
                      prefixIcon: Icon(AppIcons.tag),
                      helperText:
                          'Optional. Switch to a specific commit after cloning.',
                    ),
                  ),
                  const Gap(12),
                  TextFormField(
                    controller: _clonePath,
                    decoration: const InputDecoration(
                      labelText: 'Clone path',
                      prefixIcon: Icon(AppIcons.package),
                      helperText: 'Folder on the host to clone the repo in.',
                    ),
                  ),
                ],

                const Gap(12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _reclone,
                  title: const Text('Reclone'),
                  subtitle: const Text(
                    "Delete the repo folder and clone it again, instead of using 'git pull'.",
                  ),
                  onChanged: (v) {
                    setState(() => _reclone = v);
                    _notifyDirtyIfChanged();
                  },
                ),
              ],
            ),
          ),
          const Gap(12),
        ],

        // 3. Files
        DetailSubCard(
          title: 'Files',
          icon: AppIcons.package,
          child: Column(
            children: [
              TextFormField(
                controller: _runDirectory,
                decoration: const InputDecoration(
                  labelText: 'Run directory',
                  prefixIcon: Icon(AppIcons.package),
                  helperText:
                      'Working directory for compose up, relative to repo root.',
                ),
              ),
              const Gap(12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'File paths',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const Gap(4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Files for 'docker compose -f'. Relative to run directory.",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Gap(8),
              if (_filePathControllers.isEmpty)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _addRow(_filePathControllers),
                    icon: const Icon(AppIcons.add),
                    label: const Text('File path'),
                  ),
                )
              else
                Column(
                  children: [
                    for (var i = 0; i < _filePathControllers.length; i++) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _filePathControllers[i],
                              decoration: InputDecoration(
                                hintText: 'File path',
                                prefixIcon: i == 0
                                    ? const Icon(AppIcons.package)
                                    : null,
                              ),
                            ),
                          ),
                          const Gap(8),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(AppIcons.delete),
                            onPressed: () =>
                                _removeRow(_filePathControllers, i),
                          ),
                        ],
                      ),
                      const Gap(8),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _addRow(_filePathControllers),
                        icon: const Icon(AppIcons.add),
                        label: const Text('Add file path'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const Gap(12),

        // 4. Environment
        DetailSubCard(
          title: 'Environment',
          icon: AppIcons.settings,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Environment variables',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(8),
              DetailCodeEditor(
                controller: _environmentController,
                maxHeight: 240,
              ),
              const Gap(12),
              TextFormField(
                controller: _envFilePath,
                decoration: const InputDecoration(
                  labelText: 'Env file path',
                  prefixIcon: Icon(AppIcons.package),
                  helperText:
                      'Path to write env file, relative to run directory.',
                ),
              ),
              const Gap(12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Additional env files',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const Gap(4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Extra env files for '--env-file'. Relative to run directory.",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Gap(8),
              if (_additionalEnvFileControllers.isEmpty)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _addRow(_additionalEnvFileControllers),
                    icon: const Icon(AppIcons.add),
                    label: const Text('Env file'),
                  ),
                )
              else
                Column(
                  children: [
                    for (
                      var i = 0;
                      i < _additionalEnvFileControllers.length;
                      i++
                    ) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _additionalEnvFileControllers[i],
                              decoration: InputDecoration(
                                hintText: 'Env file path',
                                prefixIcon: i == 0
                                    ? const Icon(AppIcons.package)
                                    : null,
                              ),
                            ),
                          ),
                          const Gap(8),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(AppIcons.delete),
                            onPressed: () =>
                                _removeRow(_additionalEnvFileControllers, i),
                          ),
                        ],
                      ),
                      const Gap(8),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _addRow(_additionalEnvFileControllers),
                        icon: const Icon(AppIcons.add),
                        label: const Text('Add env file'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const Gap(12),

        // 5. Auto Update
        DetailSubCard(
          title: 'Auto Update',
          icon: AppIcons.refresh,
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _pollForUpdates,
                title: const Text('Poll for updates'),
                subtitle: const Text('Check for image updates on an interval.'),
                onChanged: (v) {
                  setState(() => _pollForUpdates = v);
                  _notifyDirtyIfChanged();
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _autoUpdate,
                title: const Text('Auto update'),
                subtitle: const Text(
                  'Trigger redeploy if newer image is found.',
                ),
                onChanged: (v) {
                  setState(() => _autoUpdate = v);
                  _notifyDirtyIfChanged();
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _autoPull,
                title: const Text('Auto pull'),
                subtitle: const Text('Pull latest changes before deploying.'),
                onChanged: (v) {
                  setState(() => _autoPull = v);
                  _notifyDirtyIfChanged();
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _sendAlerts,
                title: const Text('Send alerts'),
                onChanged: (v) {
                  setState(() => _sendAlerts = v);
                  _notifyDirtyIfChanged();
                },
              ),
            ],
          ),
        ),
        const Gap(12),

        // 6. Links
        DetailSubCard(
          title: 'Links',
          icon: AppIcons.network,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Quick links',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const Gap(4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add quick links in the resource header.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Gap(8),
              if (_linkControllers.isEmpty)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _addRow(_linkControllers),
                    icon: const Icon(AppIcons.add),
                    label: const Text('Link'),
                  ),
                )
              else
                Column(
                  children: [
                    for (var i = 0; i < _linkControllers.length; i++) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _linkControllers[i],
                              decoration: InputDecoration(
                                hintText: 'Link',
                                prefixIcon: i == 0
                                    ? const Icon(AppIcons.network)
                                    : null,
                              ),
                            ),
                          ),
                          const Gap(8),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(AppIcons.delete),
                            onPressed: () => _removeRow(_linkControllers, i),
                          ),
                        ],
                      ),
                      const Gap(8),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _addRow(_linkControllers),
                        icon: const Icon(AppIcons.add),
                        label: const Text('Add link'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const Gap(12),

        // 7. Webhooks
        DetailSubCard(
          title: 'Webhooks',
          icon: AppIcons.plug,
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _webhookEnabled,
                title: const Text('Webhook enabled'),
                subtitle: const Text('Allow git provider webhooks to deploy.'),
                onChanged: (v) {
                  setState(() => _webhookEnabled = v);
                  _notifyDirtyIfChanged();
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _webhookForceDeploy,
                title: const Text('Webhook force deploy'),
                subtitle: const Text(
                  "Force deploy even if Komodo doesn't detect file changes.",
                ),
                onChanged: (v) {
                  setState(() => _webhookForceDeploy = v);
                  _notifyDirtyIfChanged();
                },
              ),
              TextFormField(
                controller: _webhookSecret,
                decoration: const InputDecoration(
                  labelText: 'Webhook secret',
                  helperText:
                      'Leave empty to use the global default (if configured).',
                  prefixIcon: Icon(AppIcons.lock),
                ),
              ),
            ],
          ),
        ),
        const Gap(12),

        // 8. Advanced
        DetailSubCard(
          title: 'Advanced',
          icon: AppIcons.settings,
          child: Column(
            children: [
              TextFormField(
                controller: _projectName,
                decoration: const InputDecoration(
                  labelText: 'Project name',
                  prefixIcon: Icon(AppIcons.package),
                  helperText:
                      'Compose project name. Match existing name if importing.',
                ),
              ),
              const Gap(12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ignore services',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const Gap(4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Init services that exit early, so stack reports correct health.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Gap(8),
              if (_ignoreServiceControllers.isEmpty)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _addRow(_ignoreServiceControllers),
                    icon: const Icon(AppIcons.add),
                    label: const Text('Service'),
                  ),
                )
              else
                Column(
                  children: [
                    for (
                      var i = 0;
                      i < _ignoreServiceControllers.length;
                      i++
                    ) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _ignoreServiceControllers[i],
                              decoration: InputDecoration(
                                hintText: 'Service name',
                                prefixIcon: i == 0
                                    ? const Icon(AppIcons.warning)
                                    : null,
                              ),
                            ),
                          ),
                          const Gap(8),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(AppIcons.delete),
                            onPressed: () =>
                                _removeRow(_ignoreServiceControllers, i),
                          ),
                        ],
                      ),
                      const Gap(8),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _addRow(_ignoreServiceControllers),
                        icon: const Icon(AppIcons.add),
                        label: const Text('Add service'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const Gap(12),

        // 9. Compose (file contents)
        if (!hasRepoConfig)
          DetailSubCard(
            title: 'Compose',
            icon: AppIcons.stacks,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DetailCodeEditor(
                  controller: _composeController,
                  maxHeight: 320,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class StackDeploymentContent extends StatelessWidget {
  const StackDeploymentContent({required this.info, super.key});

  final StackInfo info;

  @override
  Widget build(BuildContext context) {
    final latest = info.latestHash;
    final deployed = info.deployedHash;

    final upToDate = latest != null && deployed == latest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              label: upToDate ? 'Up to date' : 'Out of date',
              icon: upToDate ? AppIcons.ok : AppIcons.warning,
              tone: upToDate ? PillTone.success : PillTone.warning,
            ),
            if (info.missingFiles.isNotEmpty)
              StatusPill(
                label: '${info.missingFiles.length} missing files',
                icon: AppIcons.warning,
                tone: PillTone.warning,
              ),
          ],
        ),
        const Gap(14),
        DetailSubCard(
          title: 'Commits',
          icon: AppIcons.repos,
          child: Column(
            children: [
              DetailKeyValueRow(
                label: 'Latest',
                value: _shortHash(latest) ?? '—',
              ),
              if (info.latestMessage?.trim().isNotEmpty ?? false)
                DetailKeyValueRow(
                  label: 'Message',
                  value: info.latestMessage!.trim(),
                ),
              DetailKeyValueRow(
                label: 'Deployed',
                value: _shortHash(deployed) ?? '—',
              ),
              if (info.deployedMessage?.trim().isNotEmpty ?? false)
                DetailKeyValueRow(
                  label: 'Message',
                  value: info.deployedMessage!.trim(),
                  bottomPadding: 0,
                )
              else
                const DetailKeyValueRow(
                  label: 'Message',
                  value: '—',
                  bottomPadding: 0,
                ),
            ],
          ),
        ),
        if (info.missingFiles.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Missing files',
            icon: AppIcons.warning,
            child: DetailPillList(
              items: info.missingFiles,
              emptyLabel: 'No missing files',
            ),
          ),
        ],
      ],
    );
  }

  String? _shortHash(String? value) {
    if (value == null) return null;
    final v = value.trim();
    if (v.isEmpty) return null;
    return v.length > 8 ? v.substring(0, 8) : v;
  }
}

class StackServiceCard extends StatelessWidget {
  const StackServiceCard({required this.service, super.key});

  final StackService service;

  @override
  Widget build(BuildContext context) {
    final container = service.container;
    final status = container?.status?.trim() ?? '';
    final state = container?.state.trim() ?? '';
    final hasUpdate = service.updateAvailable;

    return DetailSubCard(
      title: service.service,
      icon: hasUpdate ? AppIcons.updateAvailable : AppIcons.widgets,
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasUpdate)
                const StatusPill(
                  label: 'Update available',
                  icon: AppIcons.updateAvailable,
                  tone: PillTone.warning,
                )
              else
                const StatusPill(
                  label: 'Up to date',
                  icon: AppIcons.ok,
                  tone: PillTone.success,
                ),
              if (state.isNotEmpty) ValuePill(label: 'State', value: state),
              if (status.isNotEmpty) ValuePill(label: 'Status', value: status),
            ],
          ),
          if ((container?.image?.trim().isNotEmpty ?? false) ||
              (container?.name.trim().isNotEmpty ?? false)) ...[
            const Gap(12),
            if (container?.name.trim().isNotEmpty ?? false)
              DetailKeyValueRow(
                label: 'Container',
                value: container!.name.trim(),
              ),
            if (container?.image?.trim().isNotEmpty ?? false)
              DetailKeyValueRow(
                label: 'Image',
                value: container!.image!.trim(),
                bottomPadding: 0,
              ),
          ],
        ],
      ),
    );
  }
}

class StackLogContent extends StatelessWidget {
  const StackLogContent({required this.log, super.key});

  final StackLog? log;

  @override
  Widget build(BuildContext context) {
    final log = this.log;
    if (log == null) {
      return const Text('No logs available');
    }

    final output = [
      if (log.stdout.trim().isNotEmpty) log.stdout.trim(),
      if (log.stderr.trim().isNotEmpty) log.stderr.trim(),
    ].join('\n');

    final duration = (log.endTs > 0 && log.startTs > 0)
        ? Duration(milliseconds: log.endTs - log.startTs)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              label: log.success ? 'Success' : 'Failed',
              icon: log.success ? AppIcons.ok : AppIcons.error,
              tone: log.success ? PillTone.success : PillTone.alert,
            ),
            if (duration != null)
              ValuePill(label: 'Duration', value: '${duration.inSeconds}s'),
          ],
        ),
        const Gap(14),
        if (log.command.isNotEmpty) ...[
          DetailKeyValueRow(label: 'Command', value: log.command),
          const Gap(10),
        ],
        DetailCodeBlock(code: output.isNotEmpty ? output : 'No output'),
      ],
    );
  }
}

class StackLoadingSurface extends StatelessWidget {
  const StackLoadingSurface({super.key});

  @override
  Widget build(BuildContext context) {
    return const DetailSurface(
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class StackMessageSurface extends StatelessWidget {
  const StackMessageSurface({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DetailSurface(child: Text(message));
  }
}
