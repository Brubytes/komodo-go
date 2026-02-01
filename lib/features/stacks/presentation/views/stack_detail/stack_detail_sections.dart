import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/syntax_highlight/app_syntax_highlight.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/empty_state_view.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/menus/komodo_select_menu_field.dart';
import 'package:komodo_go/features/providers/data/models/docker_registry_account.dart';
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
    required this.sourceLabel,
    required this.sourceIcon,
    required this.displayTags,
    super.key,
  });

  final KomodoStack stack;
  final StackListItem? listItem;
  final int? serviceCount;
  final int? updateCount;
  final String? serverName;
  final String sourceLabel;
  final IconData sourceIcon;
  final List<String> displayTags;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final config = stack.config;
    final info = stack.info;

    final isRepoDefined =
        !config.filesOnHost &&
        (config.linkedRepo.trim().isNotEmpty || config.repo.trim().isNotEmpty);

    final state = listItem?.info.state;
    final projectMissing = listItem?.info.projectMissing ?? false;

    final missingCount = info.missingFiles.length;
    final hasGitMeta = info.latestHash != null || info.deployedHash != null;
    final upToDate =
        info.latestHash != null && info.deployedHash == info.latestHash;
    final description = stack.description.trim();
    final serverLabel = serverName ?? config.serverId;
    final runDirectory = config.runDirectory.trim();
    final directoryLabel = _formatDirectory(runDirectory);
    final metrics = <DetailMetricTileData>[
      DetailMetricTileData(
        icon: _stateIcon(state),
        label: 'State',
        value: state?.displayName ?? '—',
        tone: _stateTone(state),
      ),
      DetailMetricTileData(
        icon: sourceIcon,
        label: 'Source',
        value: sourceLabel,
        tone: DetailMetricTone.neutral,
      ),
      if (config.serverId.isNotEmpty)
        DetailMetricTileData(
          icon: AppIcons.server,
          label: 'Server',
          value: serverLabel,
          tone: DetailMetricTone.neutral,
        ),
      if (runDirectory.isNotEmpty)
        DetailMetricTileData(
          icon: AppIcons.package,
          label: 'Directory',
          value: directoryLabel,
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
      if (isRepoDefined)
        DetailMetricTileData(
          icon: !hasGitMeta
              ? AppIcons.widgets
              : (upToDate ? AppIcons.ok : AppIcons.warning),
          label: 'Git',
          value: !hasGitMeta ? '—' : (upToDate ? 'Up to date' : 'Out of date'),
          tone: !hasGitMeta
              ? DetailMetricTone.neutral
              : (upToDate
                    ? DetailMetricTone.success
                    : DetailMetricTone.tertiary),
        ),
    ];

    return DetailHeroPanel(
      tintColor: scheme.surface,
      metrics: metrics,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailPillList(
            items: displayTags,
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
          if (description.isNotEmpty) ...[
            const Gap(12),
            Text(
              'Description',
              style: textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(6),
            Text(description, style: textTheme.bodyMedium),
          ],
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

  String _formatDirectory(String path) {
    if (path.isEmpty) return path;
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (parts.isEmpty) return path;
    if (parts.length <= 2) return normalized;
    final tail = parts.sublist(parts.length - 2).join('/');
    return '…/$tail';
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
    final isRepoDefined =
        !config.filesOnHost &&
        (config.linkedRepo.trim().isNotEmpty || config.repo.trim().isNotEmpty);
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
        if (isRepoDefined) ...[
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
                  Text(
                    'No compose contents yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
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
                  Text(
                    'No environment variables yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
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
    required this.stackIdOrName,
    required this.initialConfig,
    this.webhookBaseUrl = '',
    this.servers = const [],
    this.repos = const [],
    this.registryAccounts = const [],
    this.onDirtyChanged,
    super.key,
  });

  final String stackIdOrName;
  final StackConfig initialConfig;
  final String webhookBaseUrl;
  final List<Server> servers;
  final List<RepoListItem> repos;
  final List<DockerRegistryAccount> registryAccounts;
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
  late final TextEditingController _webhookDeployUrlDisplay;

  late final TextEditingController _registryAccount;

  final List<TextEditingController> _linkControllers = [];
  final List<TextEditingController> _additionalEnvFileControllers = [];
  final List<TextEditingController> _filePathControllers = [];
  final List<TextEditingController> _ignoreServiceControllers = [];
  final List<TextEditingController> _extraArgControllers = [];

  final List<TextEditingController> _configFilePathControllers = [];
  final List<TextEditingController> _configFileServicesControllers = [];
  final List<StackFileRequires> _configFileRequires = [];

  late CodeEditorController _composeController;
  late CodeEditorController _environmentController;

  late bool _autoPull;
  late bool _autoUpdate;
  late bool _pollForUpdates;
  late bool _sendAlerts;

  late bool _runBuild;
  late bool _destroyBeforeDeploy;

  late bool _reclone;

  late bool _webhookEnabled;
  late bool _webhookForceDeploy;

  @override
  void initState() {
    super.initState();
    _initial = widget.initialConfig;
    _webhookDeployUrlDisplay = TextEditingController(
      text: _computeDeployWebhookUrl(baseUrl: widget.webhookBaseUrl),
    );

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

    _registryAccount = TextEditingController(text: _initial.registryAccount);

    _setRowControllers(_linkControllers, _initial.links);
    _setRowControllers(
      _additionalEnvFileControllers,
      _initial.additionalEnvFiles,
    );
    _setRowControllers(_filePathControllers, _initial.filePaths);
    _setRowControllers(_ignoreServiceControllers, _initial.ignoreServices);
    _setRowControllers(_extraArgControllers, _initial.extraArgs);
    _setConfigFileControllers(_initial.configFiles);

    _autoPull = _initial.autoPull;
    _autoUpdate = _initial.autoUpdate;
    _pollForUpdates = _initial.pollForUpdates;
    _sendAlerts = _initial.sendAlerts;

    _runBuild = _initial.runBuild;
    _destroyBeforeDeploy = _initial.destroyBeforeDeploy;

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
      _registryAccount,
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

    if (widget.webhookBaseUrl != oldWidget.webhookBaseUrl ||
        widget.stackIdOrName != oldWidget.stackIdOrName) {
      _webhookDeployUrlDisplay.text = _computeDeployWebhookUrl(
        baseUrl: widget.webhookBaseUrl,
      );
    }

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
      _registryAccount,
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
    _registryAccount.dispose();
    _webhookSecret.dispose();
    _webhookDeployUrlDisplay.dispose();

    _disposeRowControllers(_linkControllers);
    _disposeRowControllers(_additionalEnvFileControllers);
    _disposeRowControllers(_filePathControllers);
    _disposeRowControllers(_ignoreServiceControllers);
    _disposeRowControllers(_extraArgControllers);

    _disposeConfigFileControllers();

    _composeController.dispose();
    _environmentController.dispose();
    super.dispose();
  }

  String _computeDeployWebhookUrl({required String baseUrl}) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) return '';
    final normalized = trimmed.replaceAll(RegExp(r'/+$'), '');
    final stack = Uri.encodeComponent(widget.stackIdOrName);
    return '$normalized/stack/$stack/deploy';
  }

  Future<void> _copyToClipboard(String value) async {
    if (value.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  void _disposeConfigFileControllers() {
    for (final c in _configFilePathControllers) {
      c.removeListener(_notifyDirtyIfChanged);
      c.dispose();
    }
    for (final c in _configFileServicesControllers) {
      c.removeListener(_notifyDirtyIfChanged);
      c.dispose();
    }
    _configFilePathControllers.clear();
    _configFileServicesControllers.clear();
    _configFileRequires.clear();
  }

  void _setConfigFileControllers(List<StackFileDependency> values) {
    _disposeConfigFileControllers();

    final cleaned = values.where((e) => e.path.trim().isNotEmpty);
    for (final dep in cleaned) {
      final path = TextEditingController(text: dep.path.trim());
      final services = TextEditingController(text: dep.services.join(', '));
      path.addListener(_notifyDirtyIfChanged);
      services.addListener(_notifyDirtyIfChanged);
      _configFilePathControllers.add(path);
      _configFileServicesControllers.add(services);
      _configFileRequires.add(dep.requires);
    }
  }

  void _addConfigFileRow() {
    setState(() {
      final path = TextEditingController();
      final services = TextEditingController();
      path.addListener(_notifyDirtyIfChanged);
      services.addListener(_notifyDirtyIfChanged);
      _configFilePathControllers.add(path);
      _configFileServicesControllers.add(services);
      _configFileRequires.add(StackFileRequires.none);
    });
    _notifyDirtyIfChanged();
  }

  void _removeConfigFileRow(int index) {
    if (index < 0 || index >= _configFilePathControllers.length) return;
    setState(() {
      final path = _configFilePathControllers.removeAt(index);
      final services = _configFileServicesControllers.removeAt(index);
      _configFileRequires.removeAt(index);
      path.removeListener(_notifyDirtyIfChanged);
      services.removeListener(_notifyDirtyIfChanged);
      path.dispose();
      services.dispose();
    });
    _notifyDirtyIfChanged();
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
    _setRowControllers(_extraArgControllers, config.extraArgs);
    _setConfigFileControllers(config.configFiles);

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
      _registryAccount.text = config.registryAccount;
      _autoPull = config.autoPull;
      _autoUpdate = config.autoUpdate;
      _pollForUpdates = config.pollForUpdates;
      _sendAlerts = config.sendAlerts;

      _runBuild = config.runBuild;
      _destroyBeforeDeploy = config.destroyBeforeDeploy;

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

    void setConfigFilesIfChanged(
      String key,
      List<StackFileDependency> initial,
    ) {
      final current = <Map<String, dynamic>>[];
      for (var i = 0; i < _configFilePathControllers.length; i++) {
        final path = _configFilePathControllers[i].text.trim();
        if (path.isEmpty) continue;
        final services = _configFileServicesControllers[i].text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        current.add(<String, dynamic>{
          'path': path,
          'services': services,
          'requires': _stackFileRequiresToWire(_configFileRequires[i]),
        });
      }

      final init = initial
          .where((e) => e.path.trim().isNotEmpty)
          .map(
            (e) => <String, dynamic>{
              'path': e.path.trim(),
              'services': e.services
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList(),
              'requires': _stackFileRequiresToWire(e.requires),
            },
          )
          .toList();

      if (!_deepListEquals(current, init)) {
        params[key] = current;
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

    String registryProviderForAccount(String accountId) {
      for (final a in widget.registryAccounts) {
        if (a.id == accountId) return a.domain;
      }
      return '';
    }

    final currentRegistryAccount = _registryAccount.text.trim();
    final initialRegistryAccount = _initial.registryAccount.trim();
    if (currentRegistryAccount != initialRegistryAccount) {
      params['registry_account'] = currentRegistryAccount;
      params['registry_provider'] = currentRegistryAccount.isEmpty
          ? ''
          : registryProviderForAccount(currentRegistryAccount);
    }

    setIfChanged('auto_pull', _autoPull, _initial.autoPull);
    setIfChanged('run_build', _runBuild, _initial.runBuild);
    setIfChanged('auto_update', _autoUpdate, _initial.autoUpdate);
    setIfChanged('poll_for_updates', _pollForUpdates, _initial.pollForUpdates);
    setIfChanged('send_alerts', _sendAlerts, _initial.sendAlerts);

    setIfChanged(
      'destroy_before_deploy',
      _destroyBeforeDeploy,
      _initial.destroyBeforeDeploy,
    );

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
    setConfigFilesIfChanged('config_files', _initial.configFiles);
    setListIfChanged(
      'ignore_services',
      _ignoreServiceControllers,
      _initial.ignoreServices,
    );

    setListIfChanged('extra_args', _extraArgControllers, _initial.extraArgs);

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

  bool _deepListEquals(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.length != right.length) return false;
      for (final key in left.keys) {
        if (!right.containsKey(key)) return false;
        final lv = left[key];
        final rv = right[key];
        if (lv is List<String> && rv is List<String>) {
          if (!_listEquals(lv, rv)) return false;
        } else if (lv != rv) {
          return false;
        }
      }
    }
    return true;
  }

  String _requiresLabel(StackFileRequires value) {
    return switch (value) {
      StackFileRequires.none => 'None',
      StackFileRequires.restart => 'Restart',
      StackFileRequires.redeploy => 'Redeploy',
    };
  }

  String _stackFileRequiresToWire(StackFileRequires value) {
    return switch (value) {
      StackFileRequires.redeploy => 'Redeploy',
      StackFileRequires.restart => 'Restart',
      StackFileRequires.none => 'None',
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final servers = widget.servers;
    final repos = widget.repos;
    final registries = widget.registryAccounts;

    final sortedServers = [...servers]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final sortedRepos = [...repos]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final sortedRegistries = [...registries]
      ..sort(
        (a, b) => a.domain.toLowerCase().compareTo(b.domain.toLowerCase()) != 0
            ? a.domain.toLowerCase().compareTo(b.domain.toLowerCase())
            : a.username.toLowerCase().compareTo(b.username.toLowerCase()),
      );

    final serverIdInList = sortedServers.any((s) => s.id == _serverId.text);
    final linkedRepoInList = sortedRepos.any((r) => r.id == _linkedRepo.text);
    final registryInList = sortedRegistries.any(
      (r) => r.id == _registryAccount.text,
    );

    // Only show git source settings if this stack is actually defined via git.
    // (UI-defined stacks and files-on-host stacks shouldn't show the entire block.)
    final isGitDefined =
        !_initial.filesOnHost &&
        (_initial.linkedRepo.trim().isNotEmpty ||
            _initial.repo.trim().isNotEmpty);

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

        // 2. Compose (file contents)
        // Only for UI-defined stacks (not git-defined, not files-on-host).
        if (!_initial.filesOnHost && !isGitDefined) ...[
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
          const Gap(12),
        ],

        // 3. Source (repo section)
        if (isGitDefined) ...[
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

        // 5. Config Files
        DetailSubCard(
          title: 'Config Files',
          icon: AppIcons.package,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add other config files to associate with the Stack, and edit in the UI. Relative to Run Directory.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Gap(8),
              if (_configFilePathControllers.isEmpty)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _addConfigFileRow,
                    icon: const Icon(AppIcons.add),
                    label: const Text('Config file'),
                  ),
                )
              else
                Column(
                  children: [
                    for (
                      var i = 0;
                      i < _configFilePathControllers.length;
                      i++
                    ) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _configFilePathControllers[i],
                              decoration: InputDecoration(
                                labelText: i == 0 ? 'Path' : null,
                                hintText:
                                    'Relative path (e.g. config/app.yaml)',
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
                            onPressed: () => _removeConfigFileRow(i),
                          ),
                        ],
                      ),
                      const Gap(8),
                      DropdownButtonFormField<StackFileRequires>(
                        value: _configFileRequires[i],
                        decoration: const InputDecoration(
                          labelText: 'Requires',
                          prefixIcon: Icon(AppIcons.refresh),
                          helperText:
                              'What should happen when this file changes.',
                        ),
                        items: [
                          for (final v in StackFileRequires.values)
                            DropdownMenuItem(
                              value: v,
                              child: Text(_requiresLabel(v)),
                            ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _configFileRequires[i] = v);
                          _notifyDirtyIfChanged();
                        },
                      ),
                      const Gap(8),
                      TextFormField(
                        controller: _configFileServicesControllers[i],
                        decoration: const InputDecoration(
                          labelText: 'Services (optional)',
                          prefixIcon: Icon(AppIcons.widgets),
                          helperText:
                              'Comma-separated list of services this file applies to.',
                        ),
                      ),
                      const Gap(12),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addConfigFileRow,
                        icon: const Icon(AppIcons.add),
                        label: const Text('Add config file'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const Gap(12),

        // 6. Auto Update
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

        // 7. Links
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
              if (_webhookDeployUrlDisplay.text.trim().isNotEmpty) ...[
                TextFormField(
                  controller: _webhookDeployUrlDisplay,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Webhook URL – Deploy',
                    helperText:
                        'Derived from the Komodo core webhook_base_url.',
                    prefixIcon: const Icon(AppIcons.network),
                    suffixIcon: IconButton(
                      tooltip: 'Copy',
                      icon: const Icon(AppIcons.copy),
                      onPressed: () =>
                          _copyToClipboard(_webhookDeployUrlDisplay.text),
                    ),
                  ),
                ),
                const Gap(12),
              ],
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
                  'Deployment behavior',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const Gap(4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Advanced switches that affect deploy behavior.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Gap(8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _autoPull,
                title: const Text('Pre-pull images'),
                subtitle: const Text('Pull images before deploying.'),
                onChanged: (v) {
                  setState(() => _autoPull = v);
                  _notifyDirtyIfChanged();
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _runBuild,
                title: const Text('Pre-build images'),
                subtitle: const Text('Build images before deploying.'),
                onChanged: (v) {
                  setState(() => _runBuild = v);
                  _notifyDirtyIfChanged();
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _destroyBeforeDeploy,
                title: const Text('Destroy before deploy'),
                subtitle: const Text(
                  'Destroy existing resources before deploying.',
                ),
                onChanged: (v) {
                  setState(() => _destroyBeforeDeploy = v);
                  _notifyDirtyIfChanged();
                },
              ),
              const Gap(12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Image registry',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const Gap(8),
              if (sortedRegistries.isNotEmpty)
                KomodoSelectMenuField<String>(
                  key: ValueKey(sortedRegistries.length),
                  value: registryInList ? _registryAccount.text : null,
                  decoration: const InputDecoration(
                    labelText: 'Registry account',
                    prefixIcon: Icon(AppIcons.package),
                    helperText:
                        'Select a Docker registry account for private images.',
                  ),
                  items: [
                    KomodoSelectMenuItem(value: '', label: 'None'),
                    for (final account in sortedRegistries)
                      KomodoSelectMenuItem(
                        value: account.id,
                        label: '${account.domain} · ${account.username}',
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _registryAccount.text = value);
                    _notifyDirtyIfChanged();
                  },
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No registry accounts configured.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (sortedRegistries.isNotEmpty && !registryInList)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Current registry account is not in the account list.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              const Gap(12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Extra args',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const Gap(4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Extra args for deploy (one argument per row).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Gap(8),
              if (_extraArgControllers.isEmpty)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _addRow(_extraArgControllers),
                    icon: const Icon(AppIcons.add),
                    label: const Text('Arg'),
                  ),
                )
              else
                Column(
                  children: [
                    for (var i = 0; i < _extraArgControllers.length; i++) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _extraArgControllers[i],
                              decoration: InputDecoration(
                                hintText: 'Argument',
                                prefixIcon: i == 0
                                    ? const Icon(AppIcons.tag)
                                    : null,
                              ),
                            ),
                          ),
                          const Gap(8),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(AppIcons.delete),
                            onPressed: () =>
                                _removeRow(_extraArgControllers, i),
                          ),
                        ],
                      ),
                      const Gap(8),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _addRow(_extraArgControllers),
                        icon: const Icon(AppIcons.add),
                        label: const Text('Add arg'),
                      ),
                    ),
                  ],
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
      ],
    );
  }
}

class StackDeploymentContent extends StatelessWidget {
  const StackDeploymentContent({
    required this.info,
    required this.isRepoDefined,
    super.key,
  });

  final StackInfo info;
  final bool isRepoDefined;

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
            if (isRepoDefined)
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
        if (isRepoDefined) ...[
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
        ],
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

class StackInfoTabContent extends StatefulWidget {
  const StackInfoTabContent({
    required this.info,
    required this.onSaveFile,
    this.onDirtyChanged,
    super.key,
  });

  final StackInfo info;
  final Future<bool> Function(String path, String contents, {bool showSnackBar})
  onSaveFile;
  final ValueChanged<bool>? onDirtyChanged;

  @override
  State<StackInfoTabContent> createState() => StackInfoTabContentState();
}

class StackInfoTabContentState extends State<StackInfoTabContent> {
  final Map<String, CodeEditorController> _controllers = {};
  final Map<String, String> _initialContents = {};
  final Set<String> _savingPaths = {};
  final Set<String> _dirtyPaths = {};

  var _files = <StackRemoteFileContents>[];
  var _lastDirty = false;

  bool get isDirty => _dirtyPaths.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _syncFiles(widget.info.remoteContents ?? const []);
  }

  @override
  void didUpdateWidget(covariant StackInfoTabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.info.remoteContents != oldWidget.info.remoteContents) {
      _syncFiles(widget.info.remoteContents ?? const []);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _initialContents.clear();
    _savingPaths.clear();
    _dirtyPaths.clear();
    super.dispose();
  }

  void _syncFiles(List<StackRemoteFileContents> files) {
    final nextPaths = {for (final f in files) f.path};

    final removed = _controllers.keys.where((p) => !nextPaths.contains(p));
    for (final path in removed) {
      _controllers.remove(path)?.dispose();
      _initialContents.remove(path);
      _savingPaths.remove(path);
    }

    for (final file in files) {
      final path = file.path;
      final controller = _controllers[path];
      if (controller == null) {
        _registerController(path, _createCodeController(text: file.contents));
        continue;
      }

      final initial = _initialContents[path] ?? '';
      final isDirty = controller.text != initial;
      if (!isDirty && controller.text != file.contents) {
        controller.text = file.contents;
      }
      _initialContents[path] = file.contents;
    }

    if (!mounted) {
      _files = files;
      _notifyDirtyChanged();
      return;
    }
    setState(() => _files = files);
    _notifyDirtyChanged();
  }

  CodeEditorController _createCodeController({required String text}) {
    return CodeEditorController(
      text: text,
      lightHighlighter: Highlighter(
        language: 'yaml',
        theme: AppSyntaxHighlight.lightTheme,
      ),
      darkHighlighter: Highlighter(
        language: 'yaml',
        theme: AppSyntaxHighlight.darkTheme,
      ),
    );
  }

  void _registerController(String path, CodeEditorController controller) {
    _controllers[path] = controller;
    _initialContents[path] = controller.text;
    controller.addListener(() => _handleControllerChanged(path));
  }

  void _handleControllerChanged(String path) {
    _updateDirtyForPath(path);
    if (!mounted) return;
    setState(() {});
  }

  void _updateDirtyForPath(String path) {
    final controller = _controllers[path];
    if (controller == null) return;
    if (controller.text != (_initialContents[path] ?? '')) {
      _dirtyPaths.add(path);
    } else {
      _dirtyPaths.remove(path);
    }
    _notifyDirtyChanged();
  }

  void _notifyDirtyChanged() {
    final isDirty = _dirtyPaths.isNotEmpty;
    if (isDirty == _lastDirty) return;
    _lastDirty = isDirty;
    widget.onDirtyChanged?.call(isDirty);
  }

  CodeEditorController _controllerForFile(StackRemoteFileContents file) {
    return _controllers.putIfAbsent(file.path, () {
      final controller = _createCodeController(text: file.contents);
      _registerController(file.path, controller);
      return controller;
    });
  }

  bool _isDirty(String path) {
    final controller = _controllers[path];
    if (controller == null) return false;
    return controller.text != (_initialContents[path] ?? '');
  }

  String _requiresLabel(StackFileRequires value) {
    return switch (value) {
      StackFileRequires.none => 'None',
      StackFileRequires.restart => 'Restart',
      StackFileRequires.redeploy => 'Redeploy',
    };
  }

  Future<void> _saveFile(StackRemoteFileContents file) async {
    final path = file.path;
    final controller = _controllers[path];
    if (controller == null || _savingPaths.contains(path)) return;

    setState(() => _savingPaths.add(path));
    final success = await widget.onSaveFile(
      path,
      controller.text,
      showSnackBar: true,
    );
    if (!mounted) return;
    setState(() {
      _savingPaths.remove(path);
      if (success) {
        _initialContents[path] = controller.text;
        _dirtyPaths.remove(path);
      }
    });
    _notifyDirtyChanged();
  }

  void _resetFile(String path) {
    final controller = _controllers[path];
    if (controller == null) return;
    controller.text = _initialContents[path] ?? '';
    _updateDirtyForPath(path);
    if (!mounted) return;
    setState(() {});
  }

  Future<bool> saveAll() async {
    final dirtyPaths = _dirtyPaths.toList();
    if (dirtyPaths.isEmpty) return true;

    var allSuccess = true;
    for (final path in dirtyPaths) {
      final controller = _controllers[path];
      if (controller == null) continue;
      if (!mounted) break;
      setState(() => _savingPaths.add(path));
      final success = await widget.onSaveFile(
        path,
        controller.text,
        showSnackBar: false,
      );
      if (!mounted) break;
      setState(() => _savingPaths.remove(path));
      if (success) {
        _initialContents[path] = controller.text;
        _dirtyPaths.remove(path);
      } else {
        allSuccess = false;
      }
    }
    _notifyDirtyChanged();
    return allSuccess;
  }

  void resetAll() {
    for (final entry in _controllers.entries) {
      entry.value.text = _initialContents[entry.key] ?? '';
    }
    _dirtyPaths.clear();
    _notifyDirtyChanged();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final deployedConfig = widget.info.deployedConfig?.trim() ?? '';
    final hasFiles = _files.isNotEmpty;
    final hasDeployedConfig = deployedConfig.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasFiles)
          const EmptyStateView(
            icon: AppIcons.package,
            title: 'No file contents',
            message: 'Stack file contents will appear here once configured.',
          )
        else
          Column(
            children: [
              for (final file in _files) ...[
                DetailSubCard(
                  title: file.path.trim().isNotEmpty
                      ? file.path.trim()
                      : 'Stack file',
                  icon: AppIcons.package,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (file.services.isNotEmpty ||
                          file.requires != StackFileRequires.none) ...[
                        if (file.services.isNotEmpty)
                          DetailKeyValueRow(
                            label: 'Services',
                            value: file.services.join(', '),
                          ),
                        if (file.requires != StackFileRequires.none)
                          DetailKeyValueRow(
                            label: 'Requires',
                            value: _requiresLabel(file.requires),
                            bottomPadding: 0,
                          ),
                        const Gap(12),
                      ],
                      DetailCodeEditor(
                        controller: _controllerForFile(file),
                        maxHeight: 360,
                        fullscreenTitle: file.path.trim().isNotEmpty
                            ? file.path.trim()
                            : '',
                      ),
                    ],
                  ),
                ),
                const Gap(12),
              ],
            ],
          ),
        if (hasFiles || hasDeployedConfig) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Deployed config',
            icon: AppIcons.stacks,
            child: hasDeployedConfig
                ? DetailCodeBlock(
                    code: deployedConfig,
                    language: DetailCodeLanguage.yaml,
                  )
                : Text(
                    'No deployed config yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
          ),
        ],
      ],
    );
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
      return const EmptyStateView.inline(
        icon: AppIcons.logs,
        title: 'No logs available',
        message: 'Logs will appear here after running stack operations.',
      );
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
    return const AppSkeletonSurface();
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
