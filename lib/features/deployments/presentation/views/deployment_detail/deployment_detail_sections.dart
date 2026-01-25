import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/providers/dio_provider.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/syntax_highlight/app_syntax_highlight.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/menus/komodo_select_menu_field.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:komodo_go/features/providers/data/models/docker_registry_account.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:syntax_highlight/syntax_highlight.dart';

class DeploymentHeroPanel extends StatelessWidget {
  const DeploymentHeroPanel({
    required this.deployment,
    required this.serverName,
    super.key,
  });

  final Deployment deployment;
  final String? serverName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final state = deployment.info?.state ?? DeploymentState.unknown;
    final updateAvailable = deployment.info?.updateAvailable ?? false;
    final image = deployment.imageLabel;
    final serverId =
        deployment.config?.serverId ?? deployment.info?.serverId ?? '';
    final description = deployment.description?.trim() ?? '';
    final serverLabel = serverName ?? serverId;
    final metrics = <DetailMetricTileData>[
      DetailMetricTileData(
        icon: _stateIcon(state),
        label: 'State',
        value: state.displayName,
        tone: _stateTone(state),
      ),
      if (image.isNotEmpty)
        DetailMetricTileData(
          icon: AppIcons.deployments,
          label: 'Image',
          value: image,
          tone: DetailMetricTone.neutral,
        ),
      if (serverId.isNotEmpty)
        DetailMetricTileData(
          icon: AppIcons.server,
          label: 'Server',
          value: serverLabel,
          tone: DetailMetricTone.neutral,
        ),
      DetailMetricTileData(
        icon: updateAvailable ? AppIcons.updateAvailable : AppIcons.ok,
        label: 'Updates',
        value: updateAvailable ? 'Available' : 'Up to date',
        tone: updateAvailable
            ? DetailMetricTone.tertiary
            : DetailMetricTone.success,
      ),
    ];

    return DetailHeroPanel(
      tintColor: scheme.primary,
      metrics: metrics,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailPillList(items: deployment.tags, emptyLabel: 'No tags'),
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
            Text(
              description,
              style: textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  IconData _stateIcon(DeploymentState state) {
    return switch (state) {
      DeploymentState.running => AppIcons.ok,
      DeploymentState.deploying ||
      DeploymentState.restarting => AppIcons.loading,
      DeploymentState.paused => AppIcons.paused,
      DeploymentState.exited || DeploymentState.created => AppIcons.stopped,
      DeploymentState.dead || DeploymentState.removing => AppIcons.error,
      DeploymentState.notDeployed => AppIcons.pending,
      _ => AppIcons.unknown,
    };
  }

  DetailMetricTone _stateTone(DeploymentState state) {
    return switch (state) {
      DeploymentState.running => DetailMetricTone.success,
      DeploymentState.deploying ||
      DeploymentState.restarting => DetailMetricTone.primary,
      DeploymentState.paused => DetailMetricTone.secondary,
      DeploymentState.exited ||
      DeploymentState.created => DetailMetricTone.neutral,
      DeploymentState.dead => DetailMetricTone.alert,
      _ => DetailMetricTone.neutral,
    };
  }
}

class DeploymentConfigContent extends StatelessWidget {
  const DeploymentConfigContent({
    required this.deployment,
    required this.serverName,
    super.key,
  });

  final Deployment deployment;
  final String? serverName;

  @override
  Widget build(BuildContext context) {
    final config = deployment.config;
    if (config == null) {
      return const Text('Configuration not available');
    }

    final serverId = config.serverId;
    final isHostNetwork = config.network.trim().toLowerCase() == 'host';
    final ports = config.ports.trim();
    final volumes = config.volumes.trim();
    final environment = config.environment.trim();
    final labels = config.labels.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (serverId.isNotEmpty) ...[
          DetailSubCard(
            title: 'Server',
            icon: AppIcons.server,
            child: DetailKeyValueRow(
              label: 'Server',
              value: serverName ?? serverId,
              bottomPadding: 0,
            ),
          ),
          const Gap(12),
        ],
        DetailSubCard(
          title: 'Image',
          icon: AppIcons.deployments,
          child: Column(
            children: [
              DetailKeyValueRow(
                label: 'Image',
                value: deployment.imageLabel.isNotEmpty
                    ? deployment.imageLabel
                    : '—',
              ),
              DetailKeyValueRow(
                label: 'Registry account',
                value: config.imageRegistryAccount.trim().isNotEmpty
                    ? config.imageRegistryAccount.trim()
                    : '—',
                bottomPadding: 0,
              ),
            ],
          ),
        ),
        if (config.network.trim().isNotEmpty ||
            config.links.isNotEmpty ||
            (!isHostNetwork && ports.isNotEmpty)) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Network',
            icon: AppIcons.network,
            child: Column(
              children: [
                DetailKeyValueRow(
                  label: 'Network mode',
                  value: config.network.trim().isNotEmpty
                      ? config.network.trim()
                      : '—',
                ),
                if (!isHostNetwork && ports.isNotEmpty) ...[
                  DetailKeyValueRow(
                    label: 'Ports',
                    value: '',
                    bottomPadding: 8,
                  ),
                  DetailCodeBlock(code: ports),
                  if (config.links.isNotEmpty) const Gap(10),
                ],
                if (config.links.isNotEmpty)
                  DetailKeyValueRow(
                    label: 'Links',
                    value: '',
                    bottomPadding: 8,
                  ),
                if (config.links.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: DetailPillList(
                      items: config.links,
                      emptyLabel: 'No links',
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (environment.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Environment',
            icon: AppIcons.settings,
            child: DetailCodeBlock(code: environment),
          ),
        ],
        if (volumes.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Volumes',
            icon: AppIcons.package,
            child: DetailCodeBlock(code: volumes),
          ),
        ],
        if (config.restart != null) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Restart Mode',
            icon: AppIcons.settings,
            child: DetailKeyValueRow(
              label: 'Restart',
              value: config.restart.toString(),
              bottomPadding: 0,
            ),
          ),
        ],
        const Gap(12),
        DetailSubCard(
          title: 'Auto Update',
          icon: AppIcons.updateAvailable,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill.onOff(
                isOn: config.pollForUpdates,
                onLabel: 'Polling on',
                offLabel: 'Polling off',
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
                isOn: config.redeployOnBuild,
                onLabel: 'Redeploy on build',
                offLabel: 'Manual redeploy',
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
        ),
        if (config.command.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Command',
            icon: AppIcons.activity,
            child: DetailKeyValueRow(
              label: 'Command',
              value: config.command,
              bottomPadding: 0,
            ),
          ),
        ],
        if (labels.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Labels',
            icon: AppIcons.tag,
            child: DetailCodeBlock(code: labels),
          ),
        ],
        if (config.extraArgs.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Extra Args',
            icon: AppIcons.settings,
            child: DetailPillList(
              items: config.extraArgs,
              emptyLabel: 'No args',
            ),
          ),
        ],
        if (config.terminationSignal != null ||
            config.terminationTimeout > 0 ||
            config.termSignalLabels.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Termination',
            icon: AppIcons.warning,
            child: Column(
              children: [
                if (config.terminationSignal != null)
                  DetailKeyValueRow(
                    label: 'Default signal',
                    value: config.terminationSignal.toString(),
                  ),
                if (config.terminationTimeout > 0)
                  DetailKeyValueRow(
                    label: 'Timeout',
                    value: '${config.terminationTimeout}s',
                  ),
                if (config.termSignalLabels.isNotEmpty)
                  DetailKeyValueRow(
                    label: 'Signal labels',
                    value: config.termSignalLabels,
                    bottomPadding: 0,
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class DeploymentConfigEditorContent extends StatefulWidget {
  const DeploymentConfigEditorContent({
    required this.initialConfig,
    required this.imageLabel,
    this.servers = const [],
    this.registryAccounts = const [],
    this.onDirtyChanged,
    super.key,
  });

  final DeploymentConfig initialConfig;
  final String imageLabel;
  final List<Server> servers;
  final List<DockerRegistryAccount> registryAccounts;
  final ValueChanged<bool>? onDirtyChanged;

  @override
  State<DeploymentConfigEditorContent> createState() =>
      DeploymentConfigEditorContentState();
}

class DeploymentConfigEditorContentState
    extends State<DeploymentConfigEditorContent> {
  static const _builtinNetworkOptions = <String>['bridge', 'host'];

  // Komodo expects docker-style restart strings:
  //   no | on-failure | always | unless-stopped
  static const _restartOptions = <String>[
    'no',
    'on-failure',
    'always',
    'unless-stopped',
  ];

  static const _restartLabels = <String, String>{
    'no': 'No',
    'on-failure': 'On failure',
    'always': 'Always',
    'unless-stopped': 'Unless stopped',
  };

  static const _terminationSignalOptions = <String>[
    'SigHup',
    'SigInt',
    'SigQuit',
    'SigTerm',
  ];

  late DeploymentConfig _initial;

  var _lastDirty = false;
  var _suppressDirtyNotify = false;

  late final TextEditingController _serverId;
  late final TextEditingController _imageRegistryAccount;
  late final TextEditingController _network;
  late final TextEditingController _command;
  late final TextEditingController _terminationTimeout;
  late final TextEditingController _termSignalLabels;
  late final TextEditingController _image;

  final List<TextEditingController> _linkControllers = [];
  final List<TextEditingController> _extraArgControllers = [];

  var _networkOptions = <String>['', ..._builtinNetworkOptions];
  var _loadingNetworkOptions = false;
  String _networkOptionsForServer = '';

  late CodeEditorController _portsController;
  late CodeEditorController _volumesController;
  late CodeEditorController _environmentController;
  late CodeEditorController _labelsController;

  bool _skipSecretInterp = false;
  bool _redeployOnBuild = false;
  bool _pollForUpdates = false;
  bool _autoUpdate = false;
  bool _sendAlerts = false;

  String? _restart;
  String? _terminationSignal;

  @override
  void initState() {
    super.initState();
    _initial = widget.initialConfig;

    _serverId = TextEditingController(text: _initial.serverId);
    _imageRegistryAccount = TextEditingController(
      text: _initial.imageRegistryAccount,
    );
    _network = TextEditingController(text: _initial.network);
    _command = TextEditingController(text: _initial.command);
    _terminationTimeout = TextEditingController(
      text: _initial.terminationTimeout.toString(),
    );
    _termSignalLabels = TextEditingController(text: _initial.termSignalLabels);

    _setRowControllers(_linkControllers, _initial.links);
    _setRowControllers(_extraArgControllers, _initial.extraArgs);

    _image = TextEditingController(text: _imageTextFromDynamic(_initial.image));

    _skipSecretInterp = _initial.skipSecretInterp;
    _redeployOnBuild = _initial.redeployOnBuild;
    _pollForUpdates = _initial.pollForUpdates;
    _autoUpdate = _initial.autoUpdate;
    _sendAlerts = _initial.sendAlerts;

    _restart = _normalizeRestart(_initial.restart);
    _terminationSignal = _stringOrNull(_initial.terminationSignal);

    _portsController = _createCodeController(
      language: 'yaml',
      text: _initial.ports,
    );
    _volumesController = _createCodeController(
      language: 'yaml',
      text: _initial.volumes,
    );
    _environmentController = _createCodeController(
      language: 'yaml',
      text: _initial.environment,
    );
    _labelsController = _createCodeController(
      language: 'yaml',
      text: _initial.labels,
    );

    for (final c in <ChangeNotifier>[
      _serverId,
      _imageRegistryAccount,
      _network,
      _command,
      _terminationTimeout,
      _termSignalLabels,
      _image,
      _portsController,
      _volumesController,
      _environmentController,
      _labelsController,
    ]) {
      c.addListener(_notifyDirtyIfChanged);
    }

    _serverId.addListener(_maybeRefreshNetworkOptions);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshNetworkOptions(_serverId.text.trim());
    });
  }

  @override
  void didUpdateWidget(covariant DeploymentConfigEditorContent oldWidget) {
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
      _imageRegistryAccount,
      _network,
      _command,
      _terminationTimeout,
      _termSignalLabels,
      _image,
      _portsController,
      _volumesController,
      _environmentController,
      _labelsController,
    ]) {
      c.removeListener(_notifyDirtyIfChanged);
    }

    _serverId.removeListener(_maybeRefreshNetworkOptions);

    _serverId.dispose();
    _imageRegistryAccount.dispose();
    _network.dispose();
    _command.dispose();
    _terminationTimeout.dispose();
    _termSignalLabels.dispose();
    _image.dispose();

    _disposeRowControllers(_linkControllers);
    _disposeRowControllers(_extraArgControllers);

    _portsController.dispose();
    _volumesController.dispose();
    _environmentController.dispose();
    _labelsController.dispose();
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

  static String _imageTextFromDynamic(Object? image) {
    if (image == null) return '';
    if (image is String) return image;
    if (image is Map) {
      final params = image['params'];
      if (params is Map) {
        final nested = params['image'];
        if (nested is String) return nested;
      }

      final direct = image['image'];
      if (direct is String) return direct;

      final variant = image['Image'];
      if (variant is Map) {
        final nested = variant['image'];
        if (nested is String) return nested;
      }
    }
    return '';
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

  void _maybeRefreshNetworkOptions() {
    final serverId = _serverId.text.trim();
    if (serverId == _networkOptionsForServer) return;
    _refreshNetworkOptions(serverId);
  }

  Future<void> _refreshNetworkOptions(String serverId) async {
    final trimmed = serverId.trim();
    if (!mounted) return;

    if (trimmed.isEmpty) {
      setState(() {
        _networkOptionsForServer = '';
        _loadingNetworkOptions = false;
        _networkOptions = <String>['', ..._builtinNetworkOptions];
      });
      return;
    }

    setState(() {
      _networkOptionsForServer = trimmed;
      _loadingNetworkOptions = true;
    });

    final container = ProviderScope.containerOf(context, listen: false);
    final api = container.read(apiClientProvider);
    if (api == null) {
      if (!mounted) return;
      setState(() {
        _loadingNetworkOptions = false;
        _networkOptions = <String>['', ..._builtinNetworkOptions];
      });
      return;
    }

    try {
      final response = await api.read(
        RpcRequest(type: 'ListDockerNetworks', params: {'server': trimmed}),
      );

      final names = <String>[];
      if (response is List) {
        for (final item in response) {
          if (item is Map) {
            final name = item['name'];
            if (name is String && name.trim().isNotEmpty) {
              names.add(name.trim());
            }
          }
        }
      }

      final custom = names.toSet().toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      final options = <String>[
        '',
        ..._builtinNetworkOptions,
        ...custom.where((n) => !_builtinNetworkOptions.contains(n)),
      ];

      if (!mounted) return;
      if (_serverId.text.trim() != trimmed) return;
      setState(() {
        _loadingNetworkOptions = false;
        _networkOptions = options;
      });
    } catch (_) {
      if (!mounted) return;
      if (_serverId.text.trim() != trimmed) return;
      setState(() {
        _loadingNetworkOptions = false;
        _networkOptions = <String>['', ..._builtinNetworkOptions];
      });
    }
  }

  static String? _stringOrNull(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static String? _normalizeRestart(Object? value) {
    final raw = _stringOrNull(value);
    if (raw == null) return null;

    final lower = raw.toLowerCase();
    if (_restartOptions.contains(lower)) return lower;

    // Legacy values used by the UI previously / rust-style enum variant names.
    switch (raw) {
      case 'NoRestart':
        return 'no';
      case 'OnFailure':
        return 'on-failure';
      case 'Always':
        return 'always';
      case 'UnlessStopped':
        return 'unless-stopped';
    }

    // Best-effort normalization of other common shapes.
    switch (lower.replaceAll('_', '').replaceAll('-', '')) {
      case 'norestart':
        return 'no';
      case 'onfailure':
        return 'on-failure';
      case 'unlessstopped':
        return 'unless-stopped';
    }

    return null;
  }

  void resetTo(DeploymentConfig config) {
    _suppressDirtyNotify = true;

    _setRowControllers(_linkControllers, config.links);
    _setRowControllers(_extraArgControllers, config.extraArgs);

    setState(() {
      _initial = config;
      _serverId.text = config.serverId;
      _imageRegistryAccount.text = config.imageRegistryAccount;
      _network.text = config.network;
      _command.text = config.command;
      _terminationTimeout.text = config.terminationTimeout.toString();
      _termSignalLabels.text = config.termSignalLabels;
      _image.text = _imageTextFromDynamic(config.image);

      _skipSecretInterp = config.skipSecretInterp;
      _redeployOnBuild = config.redeployOnBuild;
      _pollForUpdates = config.pollForUpdates;
      _autoUpdate = config.autoUpdate;
      _sendAlerts = config.sendAlerts;

      _restart = _normalizeRestart(config.restart);
      _terminationSignal = _stringOrNull(config.terminationSignal);

      _portsController.text = config.ports;
      _volumesController.text = config.volumes;
      _environmentController.text = config.environment;
      _labelsController.text = config.labels;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshNetworkOptions(_serverId.text.trim());
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

  String? validateDraft() {
    final timeoutText = _terminationTimeout.text.trim();
    if (timeoutText.isNotEmpty && int.tryParse(timeoutText) == null) {
      return 'Termination timeout must be an integer.';
    }
    return null;
  }

  Map<String, dynamic> buildPartialConfigParams() {
    final partial = <String, dynamic>{};

    void setIfChanged(String key, Object? value, Object? initialValue) {
      if (value == null) return;
      if (value is String) {
        final v = value.trim();
        final i = (initialValue is String) ? initialValue.trim() : '';
        if (v != i) partial[key] = v;
        return;
      }
      if (value != initialValue) partial[key] = value;
    }

    void setListIfChanged(String key, List<String> list, List<String> initial) {
      final cleaned = list
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final initCleaned = initial
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (cleaned.length != initCleaned.length) {
        partial[key] = cleaned;
        return;
      }
      for (var i = 0; i < cleaned.length; i++) {
        if (cleaned[i] != initCleaned[i]) {
          partial[key] = cleaned;
          return;
        }
      }
    }

    setIfChanged('server_id', _serverId.text, _initial.serverId);
    setIfChanged(
      'image_registry_account',
      _imageRegistryAccount.text,
      _initial.imageRegistryAccount,
    );

    setIfChanged(
      'skip_secret_interp',
      _skipSecretInterp,
      _initial.skipSecretInterp,
    );
    setIfChanged(
      'redeploy_on_build',
      _redeployOnBuild,
      _initial.redeployOnBuild,
    );
    setIfChanged('poll_for_updates', _pollForUpdates, _initial.pollForUpdates);
    setIfChanged('auto_update', _autoUpdate, _initial.autoUpdate);
    setIfChanged('send_alerts', _sendAlerts, _initial.sendAlerts);

    setIfChanged('network', _network.text, _initial.network);
    setIfChanged('command', _command.text, _initial.command);

    final timeoutText = _terminationTimeout.text.trim();
    final timeout = int.tryParse(timeoutText);
    if (timeout != null && timeout != _initial.terminationTimeout) {
      partial['termination_timeout'] = timeout;
    }

    setIfChanged(
      'term_signal_labels',
      _termSignalLabels.text,
      _initial.termSignalLabels,
    );

    final ports = _portsController.text.trim();
    if (ports != _initial.ports.trim()) partial['ports'] = ports;

    final volumes = _volumesController.text.trim();
    if (volumes != _initial.volumes.trim()) partial['volumes'] = volumes;

    final environment = _environmentController.text.trim();
    if (environment != _initial.environment.trim()) {
      partial['environment'] = environment;
    }

    final labels = _labelsController.text.trim();
    if (labels != _initial.labels.trim()) partial['labels'] = labels;

    final links = _linkControllers.map((c) => c.text).toList();
    setListIfChanged('links', links, _initial.links);

    final extraArgs = _extraArgControllers.map((c) => c.text).toList();
    setListIfChanged('extra_args', extraArgs, _initial.extraArgs);

    // Optional: allow editing image (supports Image variant only).
    final imageText = _image.text.trim();
    final initialImageText = _imageTextFromDynamic(_initial.image).trim();
    // Treat clearing the field as a change too, so users can remove an image.
    if (imageText != initialImageText) {
      partial['image'] = {
        // Server expects a tagged enum here (serde `tag = "type"`).
        // Include both shapes for compatibility with different serde configs.
        'type': 'Image',
        'image': imageText,
        'params': {'image': imageText},
      };
    }

    if (_restart != null && _restart!.trim().isNotEmpty) {
      final initialRestart = _normalizeRestart(_initial.restart) ?? '';
      setIfChanged('restart', _restart!, initialRestart);
    }

    if (_terminationSignal != null && _terminationSignal!.trim().isNotEmpty) {
      final initialSignal = _stringOrNull(_initial.terminationSignal);
      setIfChanged(
        'termination_signal',
        _terminationSignal!,
        initialSignal ?? '',
      );
    }

    return partial;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final sortedServers = [...widget.servers]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final serverIdInList = sortedServers.any((s) => s.id == _serverId.text);

    final sortedRegistries = [...widget.registryAccounts]
      ..sort(
        (a, b) => a.domain.toLowerCase().compareTo(b.domain.toLowerCase()) != 0
            ? a.domain.toLowerCase().compareTo(b.domain.toLowerCase())
            : a.username.toLowerCase().compareTo(b.username.toLowerCase()),
      );
    final registryInList = sortedRegistries.any(
      (r) => r.id == _imageRegistryAccount.text,
    );

    final networkInList = _networkOptions.contains(_network.text);
    final networkIsHost = _network.text.trim().toLowerCase() == 'host';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Server
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

        // Image + Account
        DetailSubCard(
          title: 'Image',
          icon: AppIcons.deployments,
          child: Column(
            children: [
              DetailKeyValueRow(
                label: 'Current image',
                value: widget.imageLabel.isNotEmpty ? widget.imageLabel : '—',
              ),
              TextFormField(
                controller: _image,
                decoration: InputDecoration(
                  labelText: 'Image (optional)',
                  prefixIcon: const Icon(AppIcons.deployments),
                  helperStyle: TextStyle(color: scheme.onSurfaceVariant),
                  helperText: 'Either pass a docker image directly.',
                ),
              ),
              const Gap(12),
              KomodoSelectMenuField<String>(
                key: ValueKey(sortedRegistries.length),
                value: sortedRegistries.isNotEmpty
                    ? (registryInList
                          ? _imageRegistryAccount.text
                          : (_imageRegistryAccount.text.trim().isEmpty
                                ? ''
                                : null))
                    : '',
                decoration: InputDecoration(
                  labelText: 'Registry account',
                  prefixIcon: const Icon(AppIcons.package),
                  helperStyle: TextStyle(color: scheme.onSurfaceVariant),
                  helperText:
                      'Select the account used to log in to the provider.',
                ),
                items: sortedRegistries.isNotEmpty
                    ? [
                        const KomodoSelectMenuItem(value: '', label: '—'),
                        for (final registry in sortedRegistries)
                          KomodoSelectMenuItem(
                            value: registry.id,
                            label: '${registry.username}@${registry.domain}',
                          ),
                      ]
                    : const [
                        KomodoSelectMenuItem(
                          value: '',
                          label: 'No registry accounts',
                        ),
                      ],
                onChanged: sortedRegistries.isNotEmpty
                    ? (value) {
                        if (value == null) return;
                        setState(() => _imageRegistryAccount.text = value);
                      }
                    : null,
              ),
              if ((sortedRegistries.isEmpty &&
                      _imageRegistryAccount.text.trim().isNotEmpty) ||
                  (sortedRegistries.isNotEmpty &&
                      !registryInList &&
                      _imageRegistryAccount.text.trim().isNotEmpty)) ...[
                const Gap(8),
                TextFormField(
                  controller: _imageRegistryAccount,
                  decoration: const InputDecoration(
                    labelText: 'Registry account (manual)',
                    prefixIcon: Icon(AppIcons.tag),
                    helperText: 'Current value not found in registry accounts.',
                  ),
                ),
              ],
            ],
          ),
        ),
        const Gap(12),

        // Network + Ports + Links
        DetailSubCard(
          title: 'Network',
          icon: AppIcons.network,
          child: Column(
            children: [
              KomodoSelectMenuField<String>(
                key: ValueKey(_networkOptions.length),
                value: networkInList ? _network.text : null,
                decoration: InputDecoration(
                  labelText: 'Network mode',
                  prefixIcon: const Icon(AppIcons.network),
                  helperStyle: TextStyle(color: scheme.onSurfaceVariant),
                  helperText: _loadingNetworkOptions
                      ? 'Loading networks…'
                      : 'Choose the --network attached to container.',
                ),
                items: [
                  const KomodoSelectMenuItem(value: '', label: '—'),
                  for (final v in _networkOptions.where((e) => e.isNotEmpty))
                    KomodoSelectMenuItem(value: v, label: v),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _network.text = value);
                },
              ),
              if (!networkInList && _network.text.trim().isNotEmpty) ...[
                const Gap(8),
                TextFormField(
                  controller: _network,
                  decoration: const InputDecoration(
                    labelText: 'Network mode (manual)',
                    prefixIcon: Icon(AppIcons.tag),
                    helperText: 'Current value not found in network list.',
                  ),
                ),
              ],
              if (!networkIsHost) ...[
                const Gap(12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Ports',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const Gap(6),
                DetailCodeEditor(controller: _portsController, maxHeight: 180),
              ],
              const Gap(12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Links',
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
                          Align(
                            alignment: Alignment.center,
                            child: IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(AppIcons.delete),
                              onPressed: () => _removeRow(_linkControllers, i),
                            ),
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

        // Environment
        DetailSubCard(
          title: 'Environment',
          icon: AppIcons.settings,
          child: DetailCodeEditor(
            controller: _environmentController,
            maxHeight: 220,
          ),
        ),
        const Gap(12),

        // Volumes
        DetailSubCard(
          title: 'Volumes',
          icon: AppIcons.package,
          child: DetailCodeEditor(
            controller: _volumesController,
            maxHeight: 180,
          ),
        ),
        const Gap(12),

        // Restart mode
        DetailSubCard(
          title: 'Restart Mode',
          icon: AppIcons.settings,
          child: KomodoSelectMenuField<String>(
            value: (_restartOptions.contains(_restart) ? _restart : null),
            decoration: const InputDecoration(
              labelText: 'Restart',
              prefixIcon: Icon(AppIcons.settings),
              helperText: 'Configure the --restart behavior.',
            ),
            items: [
              for (final v in _restartOptions)
                KomodoSelectMenuItem(value: v, label: _restartLabels[v] ?? v),
            ],
            onChanged: (v) {
              setState(() => _restart = v);
              _notifyDirtyIfChanged();
            },
          ),
        ),
        const Gap(12),

        // Auto update (web-style ordering)
        DetailSubCard(
          title: 'Auto Update',
          icon: AppIcons.updateAvailable,
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _pollForUpdates,
                title: const Text('Poll for updates'),
                subtitle: const Text(
                  'Check for updates to the image on an interval.',
                ),
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
                  'Trigger a redeploy if a newer image is found.',
                ),
                onChanged: (v) {
                  setState(() => _autoUpdate = v);
                  _notifyDirtyIfChanged();
                },
              ),
            ],
          ),
        ),
        const Gap(12),

        // Advanced
        DetailSubCard(
          title: 'Advanced',
          icon: AppIcons.settings,
          child: Column(
            children: [
              TextFormField(
                controller: _command,
                decoration: const InputDecoration(
                  labelText: 'Command',
                  prefixIcon: Icon(AppIcons.activity),
                  helperText: 'Replace the CMD, or extend the ENTRYPOINT.',
                ),
              ),
              const Gap(12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Labels',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const Gap(4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Docker labels to apply to the container.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Gap(8),
              DetailCodeEditor(controller: _labelsController, maxHeight: 180),
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
                  "Pass extra arguments to 'docker run'.",
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
                                hintText: 'Arg',
                                prefixIcon: i == 0
                                    ? const Icon(AppIcons.settings)
                                    : null,
                              ),
                            ),
                          ),
                          const Gap(8),
                          Align(
                            alignment: Alignment.center,
                            child: IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(AppIcons.delete),
                              onPressed: () =>
                                  _removeRow(_extraArgControllers, i),
                            ),
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
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _sendAlerts,
                title: const Text('Send alerts'),
                onChanged: (v) {
                  setState(() => _sendAlerts = v);
                  _notifyDirtyIfChanged();
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _redeployOnBuild,
                title: const Text('Redeploy on build'),
                onChanged: (v) {
                  setState(() => _redeployOnBuild = v);
                  _notifyDirtyIfChanged();
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _skipSecretInterp,
                title: const Text('Skip secret interpolation'),
                onChanged: (v) {
                  setState(() => _skipSecretInterp = v);
                  _notifyDirtyIfChanged();
                },
              ),
            ],
          ),
        ),
        const Gap(12),

        // Termination
        DetailSubCard(
          title: 'Termination',
          icon: AppIcons.warning,
          child: Column(
            children: [
              KomodoSelectMenuField<String>(
                value: (_terminationSignalOptions.contains(_terminationSignal)
                    ? _terminationSignal
                    : null),
                decoration: const InputDecoration(
                  labelText: 'Default termination signal',
                  prefixIcon: Icon(AppIcons.warning),
                  helperText:
                      'Configure the signals used to stop the container.',
                ),
                items: [
                  for (final v in _terminationSignalOptions)
                    KomodoSelectMenuItem(value: v, label: v),
                ],
                onChanged: (v) {
                  setState(() => _terminationSignal = v);
                  _notifyDirtyIfChanged();
                },
              ),
              const Gap(12),
              TextFormField(
                controller: _terminationTimeout,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Termination timeout (seconds)',
                  prefixIcon: Icon(AppIcons.clock),
                ),
              ),
              const Gap(12),
              TextFormField(
                controller: _termSignalLabels,
                decoration: const InputDecoration(
                  labelText: 'Termination signal labels',
                  prefixIcon: Icon(AppIcons.tag),
                  helperText: 'Choose between multiple signals when stopping.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DeploymentLoadingSurface extends StatelessWidget {
  const DeploymentLoadingSurface({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppSkeletonSurface();
  }
}

class DeploymentMessageSurface extends StatelessWidget {
  const DeploymentMessageSurface({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DetailSurface(child: Text(message));
  }
}
