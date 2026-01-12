import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/syntax_highlight/app_syntax_highlight.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
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
    final state = deployment.info?.state ?? DeploymentState.unknown;
    final status = deployment.info?.status;
    final updateAvailable = deployment.info?.updateAvailable ?? false;
    final image = deployment.imageLabel;
    final serverId =
        deployment.config?.serverId ?? deployment.info?.serverId ?? '';

    return DetailHeroPanel(
      tintColor: scheme.primary,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (deployment.description?.trim().isNotEmpty ?? false) ...[
            DetailIconInfoRow(
              icon: AppIcons.tag,
              label: 'Description',
              value: deployment.description!.trim(),
            ),
            const Gap(10),
          ],
          if (image.isNotEmpty) ...[
            DetailIconInfoRow(
              icon: AppIcons.deployments,
              label: 'Image',
              value: image,
            ),
            const Gap(10),
          ],
          if (serverId.isNotEmpty)
            DetailIconInfoRow(
              icon: AppIcons.server,
              label: 'Server',
              value: serverName ?? serverId,
            ),
        ],
      ),
      metrics: [
        DetailMetricTileData(
          icon: _stateIcon(state),
          label: 'State',
          value: state.displayName,
          tone: _stateTone(state),
        ),
        if (status?.trim().isNotEmpty ?? false)
          DetailMetricTileData(
            icon: AppIcons.activity,
            label: 'Status',
            value: status!.trim(),
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
      ],
      footer: DetailPillList(items: deployment.tags, emptyLabel: 'No tags'),
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
    final ports = config.ports.trim();
    final volumes = config.volumes.trim();
    final environment = config.environment.trim();
    final labels = config.labels.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
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
            StatusPill.onOff(
              isOn: config.redeployOnBuild,
              onLabel: 'Redeploy on build',
              offLabel: 'Manual redeploy',
              onIcon: AppIcons.ok,
              offIcon: AppIcons.pause,
            ),
          ],
        ),
        const Gap(14),
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
                label: 'Registry',
                value: config.imageRegistryAccount.isNotEmpty
                    ? config.imageRegistryAccount
                    : '—',
                bottomPadding: 0,
              ),
            ],
          ),
        ),
        if (serverId.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Server',
            icon: AppIcons.server,
            child: DetailKeyValueRow(
              label: 'Server',
              value: serverName ?? serverId,
              bottomPadding: 0,
            ),
          ),
        ],
        if (config.network.isNotEmpty ||
            config.restart != null ||
            config.terminationTimeout > 0) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Container',
            icon: AppIcons.settings,
            child: Column(
              children: [
                if (config.network.isNotEmpty)
                  DetailKeyValueRow(label: 'Network', value: config.network),
                if (config.restart != null)
                  DetailKeyValueRow(
                    label: 'Restart',
                    value: config.restart.toString(),
                  ),
                if (config.terminationTimeout > 0)
                  DetailKeyValueRow(
                    label: 'Term timeout',
                    value: '${config.terminationTimeout}s',
                    bottomPadding: 0,
                  ),
              ],
            ),
          ),
        ],
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
        if (ports.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Ports',
            icon: AppIcons.settings,
            child: DetailCodeBlock(code: ports),
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
        if (environment.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Environment',
            icon: AppIcons.settings,
            child: DetailCodeBlock(code: environment),
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
        if (config.links.isNotEmpty) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Links',
            icon: AppIcons.network,
            child: DetailPillList(items: config.links, emptyLabel: 'No links'),
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
  late final TextEditingController _links;
  late final TextEditingController _extraArgs;
  late final TextEditingController _image;

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
    _links = TextEditingController(text: _initial.links.join('\n'));
    _extraArgs = TextEditingController(text: _initial.extraArgs.join('\n'));

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
      _links,
      _extraArgs,
      _image,
      _portsController,
      _volumesController,
      _environmentController,
      _labelsController,
    ]) {
      c.addListener(_notifyDirtyIfChanged);
    }
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
      _links,
      _extraArgs,
      _image,
      _portsController,
      _volumesController,
      _environmentController,
      _labelsController,
    ]) {
      c.removeListener(_notifyDirtyIfChanged);
    }

    _serverId.dispose();
    _imageRegistryAccount.dispose();
    _network.dispose();
    _command.dispose();
    _terminationTimeout.dispose();
    _termSignalLabels.dispose();
    _links.dispose();
    _extraArgs.dispose();
    _image.dispose();

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
    setState(() {
      _initial = config;
      _serverId.text = config.serverId;
      _imageRegistryAccount.text = config.imageRegistryAccount;
      _network.text = config.network;
      _command.text = config.command;
      _terminationTimeout.text = config.terminationTimeout.toString();
      _termSignalLabels.text = config.termSignalLabels;
      _links.text = config.links.join('\n');
      _extraArgs.text = config.extraArgs.join('\n');
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

    final links = _links.text.split('\n');
    setListIfChanged('links', links, _initial.links);

    final extraArgs = _extraArgs.text.split('\n');
    setListIfChanged('extra_args', extraArgs, _initial.extraArgs);

    // Optional: allow editing image (supports Image variant only).
    final imageText = _image.text.trim();
    final initialImageText = _imageTextFromDynamic(_initial.image).trim();
    if (imageText.isNotEmpty && imageText != initialImageText) {
      partial['image'] = {
        'Image': {'image': imageText},
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailSubCard(
          title: 'Flags',
          icon: AppIcons.settings,
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _autoUpdate,
                title: const Text('Auto update'),
                onChanged: (v) {
                  setState(() => _autoUpdate = v);
                  _notifyDirtyIfChanged();
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _pollForUpdates,
                title: const Text('Poll for updates'),
                onChanged: (v) {
                  setState(() => _pollForUpdates = v);
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
                  helperText: 'Only supports external image (Image variant).',
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
                  helperText: sortedRegistries.isNotEmpty
                      ? 'Select a saved registry account.'
                      : 'No registry accounts found. Add one under Providers.',
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
                    helperText: 'Changing server may move/cleanup deployment.',
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
                    helperText: 'Changing server may move/cleanup deployment.',
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
        DetailSubCard(
          title: 'Container',
          icon: AppIcons.settings,
          child: Column(
            children: [
              TextFormField(
                controller: _network,
                decoration: const InputDecoration(
                  labelText: 'Network',
                  prefixIcon: Icon(AppIcons.network),
                ),
              ),
              const Gap(12),
              KomodoSelectMenuField<String>(
                value: (_restartOptions.contains(_restart) ? _restart : null),
                decoration: const InputDecoration(
                  labelText: 'Restart',
                  prefixIcon: Icon(AppIcons.settings),
                ),
                items: [
                  for (final v in _restartOptions)
                    KomodoSelectMenuItem(
                      value: v,
                      label: _restartLabels[v] ?? v,
                    ),
                ],
                onChanged: (v) {
                  setState(() => _restart = v);
                  _notifyDirtyIfChanged();
                },
              ),
              const Gap(12),
              KomodoSelectMenuField<String>(
                value: (_terminationSignalOptions.contains(_terminationSignal)
                    ? _terminationSignal
                    : null),
                decoration: const InputDecoration(
                  labelText: 'Termination signal',
                  prefixIcon: Icon(AppIcons.warning),
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
                  labelText: 'Term signal labels',
                  prefixIcon: Icon(AppIcons.tag),
                ),
              ),
              const Gap(12),
              TextFormField(
                controller: _command,
                decoration: const InputDecoration(
                  labelText: 'Command',
                  prefixIcon: Icon(AppIcons.activity),
                ),
              ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Ports',
          icon: AppIcons.settings,
          child: DetailCodeEditor(controller: _portsController, maxHeight: 180),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Volumes',
          icon: AppIcons.package,
          child: DetailCodeEditor(
            controller: _volumesController,
            maxHeight: 180,
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Environment',
          icon: AppIcons.settings,
          child: DetailCodeEditor(
            controller: _environmentController,
            maxHeight: 220,
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Labels',
          icon: AppIcons.tag,
          child: DetailCodeEditor(
            controller: _labelsController,
            maxHeight: 180,
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Links',
          icon: AppIcons.network,
          child: TextFormField(
            controller: _links,
            minLines: 2,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Links (one per line)',
              prefixIcon: Icon(AppIcons.network),
            ),
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Extra Args',
          icon: AppIcons.settings,
          child: TextFormField(
            controller: _extraArgs,
            minLines: 2,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Args (one per line)',
              prefixIcon: Icon(AppIcons.settings),
            ),
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
    return const DetailSurface(
      child: Center(child: CircularProgressIndicator()),
    );
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
