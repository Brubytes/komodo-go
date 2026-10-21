import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/utils/relative_time.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/empty_error_state.dart';
import 'package:komodo_go/core/widgets/empty_state_view.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/menus/komodo_select_menu_field.dart';
import 'package:komodo_go/features/builders/data/models/builder_list_item.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';

/// App bar status line for a build: state plus how long ago it was built.
MainAppBarStatus? buildAppBarStatus({
  required BuildListItem? listItem,
  required KomodoBuild? build,
}) {
  if (listItem == null) return null;
  final state = listItem.info.state;
  final builtAt = build?.info.lastBuiltAt ?? listItem.info.lastBuiltAt;
  final ago = builtAt > 0 ? ' · built ${formatTimeAgo(builtAt)}' : '';
  return switch (state) {
    BuildState.ok => MainAppBarStatus(
      label: 'Ok$ago',
      tone: PillTone.success,
    ),
    BuildState.failed => MainAppBarStatus(
      label: 'Failed$ago',
      tone: PillTone.alert,
    ),
    BuildState.building => const MainAppBarStatus(
      label: 'Building',
      tone: PillTone.warning,
    ),
    BuildState.unknown => const MainAppBarStatus(label: 'Unknown'),
  };
}

class BuildHeader extends StatelessWidget {
  const BuildHeader({
    required this.buildResource,
    required this.listItem,
    required this.builderLabel,
    this.onBuilderTap,
    this.onRepoTap,
    this.onRunBuild,
    super.key,
  });

  final KomodoBuild buildResource;
  final BuildListItem? listItem;
  final String? builderLabel;
  final VoidCallback? onBuilderTap;
  final VoidCallback? onRepoTap;
  final VoidCallback? onRunBuild;

  @override
  Widget build(BuildContext context) {
    final config = buildResource.config;
    final info = buildResource.info;
    final state = listItem?.info.state;
    final outOfDate =
        info.latestHash != null &&
        info.builtHash != null &&
        info.latestHash != info.builtHash;

    final repo = config.repo.isNotEmpty
        ? config.repo
        : (listItem?.info.repo ?? '');
    final branch = config.branch.isNotEmpty
        ? config.branch
        : (listItem?.info.branch ?? '');
    final repoValue = [
      if (repo.isNotEmpty) repo,
      if (branch.isNotEmpty) branch,
    ].join(' · ');

    DetailAttentionBanner? banner;
    if (state == BuildState.failed) {
      banner = DetailAttentionBanner(
        icon: AppIcons.error,
        tone: PillTone.alert,
        message: 'Last build failed',
        actionLabel: onRunBuild == null ? null : 'Build',
        onAction: onRunBuild,
      );
    } else if (outOfDate && state != BuildState.building) {
      banner = DetailAttentionBanner(
        icon: AppIcons.warning,
        message: 'Source is out of date',
        actionLabel: onRunBuild == null ? null : 'Build',
        onAction: onRunBuild,
      );
    }

    return DetailResourceHeader(
      banner: banner,
      facts: [
        DetailFact(
          icon: AppIcons.tag,
          label: 'Version',
          value: config.version.label,
        ),
        if ((builderLabel ?? '').trim().isNotEmpty)
          DetailFact(
            icon: AppIcons.factory,
            label: 'Builder',
            value: builderLabel!,
            onTap: onBuilderTap,
          ),
        if (repoValue.isNotEmpty)
          DetailFact(
            icon: AppIcons.repos,
            label: 'Repo',
            value: repoValue,
            fullValue: repoValue,
            onTap: onRepoTap,
          ),
      ],
      tags: buildResource.tags,
      description: buildResource.description,
    );
  }
}

class BuildConfigEditorContent extends StatefulWidget {
  const BuildConfigEditorContent({
    required this.initialConfig,
    this.onDirtyChanged,
    this.builders = const [],
    this.repos = const [],
    super.key,
  });

  final BuildConfig initialConfig;
  final ValueChanged<bool>? onDirtyChanged;
  final List<BuilderListItem> builders;
  final List<RepoListItem> repos;

  @override
  State<BuildConfigEditorContent> createState() =>
      BuildConfigEditorContentState();
}

class BuildConfigEditorContentState extends State<BuildConfigEditorContent> {
  late BuildConfig _initial;

  var _suppressDirtyNotify = false;
  var _lastDirty = false;
  Set<String> _changedKeys = const {};

  late final TextEditingController _builderId;
  late final TextEditingController _versionMajor;
  late final TextEditingController _versionMinor;
  late final TextEditingController _versionPatch;
  late final TextEditingController _imageName;
  late final TextEditingController _imageTag;
  late final TextEditingController _linkedRepo;
  late final TextEditingController _repo;
  late final TextEditingController _branch;
  late final TextEditingController _commit;
  late final TextEditingController _buildPath;
  late final TextEditingController _dockerfilePath;
  late final TextEditingController _extraArgs;

  var _autoIncrementVersion = false;
  var _webhookEnabled = false;
  var _filesOnHost = false;
  var _skipSecretInterp = false;
  var _useBuildx = false;

  @override
  void initState() {
    super.initState();
    _initial = widget.initialConfig;

    _builderId = TextEditingController(text: _initial.builderId);
    _versionMajor = TextEditingController(text: '${_initial.version.major}');
    _versionMinor = TextEditingController(text: '${_initial.version.minor}');
    _versionPatch = TextEditingController(text: '${_initial.version.patch}');
    _imageName = TextEditingController(text: _initial.imageName);
    _imageTag = TextEditingController(text: _initial.imageTag);
    _linkedRepo = TextEditingController(text: _initial.linkedRepo);
    _repo = TextEditingController(text: _initial.repo);
    _branch = TextEditingController(text: _initial.branch);
    _commit = TextEditingController(text: _initial.commit);
    _buildPath = TextEditingController(text: _initial.buildPath);
    _dockerfilePath = TextEditingController(text: _initial.dockerfilePath);
    _extraArgs = TextEditingController(text: _initial.extraArgs.join('\n'));

    _autoIncrementVersion = _initial.autoIncrementVersion;
    _webhookEnabled = _initial.webhookEnabled;
    _filesOnHost = _initial.filesOnHost;
    _skipSecretInterp = _initial.skipSecretInterp;
    _useBuildx = _initial.useBuildx;

    for (final c in <TextEditingController>[
      _builderId,
      _versionMajor,
      _versionMinor,
      _versionPatch,
      _imageName,
      _imageTag,
      _linkedRepo,
      _repo,
      _branch,
      _commit,
      _buildPath,
      _dockerfilePath,
      _extraArgs,
    ]) {
      c.addListener(_notifyDirtyIfChanged);
    }
  }

  @override
  void didUpdateWidget(covariant BuildConfigEditorContent oldWidget) {
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
      _builderId,
      _versionMajor,
      _versionMinor,
      _versionPatch,
      _imageName,
      _imageTag,
      _linkedRepo,
      _repo,
      _branch,
      _commit,
      _buildPath,
      _dockerfilePath,
      _extraArgs,
    ]) {
      c.removeListener(_notifyDirtyIfChanged);
    }
    _builderId.dispose();
    _versionMajor.dispose();
    _versionMinor.dispose();
    _versionPatch.dispose();
    _imageName.dispose();
    _imageTag.dispose();
    _linkedRepo.dispose();
    _repo.dispose();
    _branch.dispose();
    _commit.dispose();
    _buildPath.dispose();
    _dockerfilePath.dispose();
    _extraArgs.dispose();
    super.dispose();
  }

  void resetTo(BuildConfig config) {
    _suppressDirtyNotify = true;
    setState(() {
      _initial = config;

      _builderId.text = config.builderId;
      _versionMajor.text = '${config.version.major}';
      _versionMinor.text = '${config.version.minor}';
      _versionPatch.text = '${config.version.patch}';
      _imageName.text = config.imageName;
      _imageTag.text = config.imageTag;
      _linkedRepo.text = config.linkedRepo;
      _repo.text = config.repo;
      _branch.text = config.branch;
      _commit.text = config.commit;
      _buildPath.text = config.buildPath;
      _dockerfilePath.text = config.dockerfilePath;
      _extraArgs.text = config.extraArgs.join('\n');

      _autoIncrementVersion = config.autoIncrementVersion;
      _webhookEnabled = config.webhookEnabled;
      _filesOnHost = config.filesOnHost;
      _skipSecretInterp = config.skipSecretInterp;
      _useBuildx = config.useBuildx;
    });

    _suppressDirtyNotify = false;
    _lastDirty = false;
    _changedKeys = const {};
    widget.onDirtyChanged?.call(false);
  }

  void _notifyDirtyIfChanged() {
    if (_suppressDirtyNotify) return;

    final keys = buildPartialConfigParams().keys.toSet();
    if (keys.length != _changedKeys.length || !keys.containsAll(_changedKeys)) {
      setState(() => _changedKeys = keys);
    }
    final dirty = keys.isNotEmpty;
    if (dirty == _lastDirty) return;
    _lastDirty = dirty;
    widget.onDirtyChanged?.call(dirty);
  }

  bool _modified(List<String> keys) => keys.any(_changedKeys.contains);

  String _togglesSummary() {
    final on = [
      if (_webhookEnabled) 'Webhook',
      if (_autoIncrementVersion) 'Auto version',
      if (_useBuildx) 'Buildx',
      if (_filesOnHost) 'Files on host',
      if (_skipSecretInterp) 'Skip secrets',
    ];
    return on.isEmpty ? 'All off' : on.join(' · ');
  }

  String _pathsSummary() {
    final parts = [
      if (_buildPath.text.trim().isNotEmpty) _buildPath.text.trim(),
      if (_dockerfilePath.text.trim().isNotEmpty) _dockerfilePath.text.trim(),
    ];
    return parts.isEmpty ? 'Defaults' : parts.join(' · ');
  }

  Map<String, dynamic> buildPartialConfigParams() {
    final params = <String, dynamic>{};

    void setIfChanged(String key, Object value, Object initialValue) {
      if (value != initialValue) {
        params[key] = value;
      }
    }

    final builderId = _builderId.text.trim();
    setIfChanged('builder_id', builderId, _initial.builderId);

    setIfChanged(
      'auto_increment_version',
      _autoIncrementVersion,
      _initial.autoIncrementVersion,
    );

    final imageName = _imageName.text.trim();
    setIfChanged('image_name', imageName, _initial.imageName);

    final imageTag = _imageTag.text.trim();
    setIfChanged('image_tag', imageTag, _initial.imageTag);

    final linkedRepo = _linkedRepo.text.trim();
    setIfChanged('linked_repo', linkedRepo, _initial.linkedRepo);

    final repo = _repo.text.trim();
    setIfChanged('repo', repo, _initial.repo);

    final branch = _branch.text.trim();
    setIfChanged('branch', branch, _initial.branch);

    final commit = _commit.text.trim();
    setIfChanged('commit', commit, _initial.commit);

    setIfChanged('webhook_enabled', _webhookEnabled, _initial.webhookEnabled);
    setIfChanged('files_on_host', _filesOnHost, _initial.filesOnHost);

    final buildPath = _buildPath.text.trim();
    setIfChanged('build_path', buildPath, _initial.buildPath);

    final dockerfilePath = _dockerfilePath.text.trim();
    setIfChanged('dockerfile_path', dockerfilePath, _initial.dockerfilePath);

    setIfChanged(
      'skip_secret_interp',
      _skipSecretInterp,
      _initial.skipSecretInterp,
    );
    setIfChanged('use_buildx', _useBuildx, _initial.useBuildx);

    final extraArgs = _extraArgs.text
        .split(RegExp(r'[\n,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (extraArgs.join('\n') != _initial.extraArgs.join('\n')) {
      params['extra_args'] = extraArgs;
    }

    final major = int.tryParse(_versionMajor.text.trim());
    final minor = int.tryParse(_versionMinor.text.trim());
    final patch = int.tryParse(_versionPatch.text.trim());
    final version = <String, dynamic>{
      'major': major ?? _initial.version.major,
      'minor': minor ?? _initial.version.minor,
      'patch': patch ?? _initial.version.patch,
    };
    final initialVersion = <String, dynamic>{
      'major': _initial.version.major,
      'minor': _initial.version.minor,
      'patch': _initial.version.patch,
    };
    if (version.toString() != initialVersion.toString()) {
      params['version'] = version;
    }

    return params;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final builders = widget.builders;
    final repos = widget.repos;

    final builderItems = [...builders]
      ..sort((a, b) => a.name.compareTo(b.name));
    final repoItems = [...repos]..sort((a, b) => a.name.compareTo(b.name));

    final builderIdOptions = builderItems.map((b) => b.id).toList();
    final hasBuilderInOptions = builderIdOptions.contains(
      _builderId.text.trim(),
    );

    final linkedRepoOptions = repoItems.map((r) => r.id).toList();
    final hasLinkedRepoInOptions = linkedRepoOptions.contains(
      _linkedRepo.text.trim(),
    );

    final repoPathOptions =
        repoItems
            .map((r) => r.info.repo.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final branchOptions =
        repoItems
            .map((r) => r.info.branch.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final hasRepoInOptions = repoPathOptions.contains(_repo.text.trim());
    final hasBranchInOptions = branchOptions.contains(_branch.text.trim());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailSubCard(
          title: 'Builder & Version',
          icon: AppIcons.factory,
          child: Column(
            children: [
              if (builderItems.isNotEmpty && hasBuilderInOptions)
                KomodoSelectMenuFormField<String>(
                  key: ValueKey('build_builder_${builderItems.length}'),
                  initialValue: _builderId.text.trim().isNotEmpty
                      ? _builderId.text.trim()
                      : null,
                  items: builderItems
                      .map(
                        (b) => KomodoSelectMenuItem(value: b.id, label: b.name),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _builderId.text = v);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Builder',
                    prefixIcon: Icon(AppIcons.factory),
                  ),
                )
              else
                TextFormField(
                  controller: _builderId,
                  decoration: const InputDecoration(
                    labelText: 'Builder id/name',
                    prefixIcon: Icon(AppIcons.factory),
                  ),
                ),
              const Gap(12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _versionMajor,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Major',
                        prefixText: 'M ',
                        prefixStyle: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                        floatingLabelStyle: TextStyle(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const Gap(8),
                  Expanded(
                    child: TextFormField(
                      controller: _versionMinor,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Minor',
                        prefixText: 'm ',
                        prefixStyle: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                        floatingLabelStyle: TextStyle(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const Gap(8),
                  Expanded(
                    child: TextFormField(
                      controller: _versionPatch,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Patch',
                        prefixText: 'p ',
                        prefixStyle: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                        floatingLabelStyle: TextStyle(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Image',
          icon: AppIcons.builds,
          child: Column(
            children: [
              TextFormField(
                controller: _imageName,
                decoration: const InputDecoration(
                  labelText: 'Image name',
                  prefixIcon: Icon(AppIcons.builds),
                ),
              ),
              const Gap(12),
              TextFormField(
                controller: _imageTag,
                decoration: const InputDecoration(
                  labelText: 'Image tag',
                  prefixIcon: Icon(AppIcons.tag),
                ),
              ),
              const Gap(12),
              TextFormField(
                controller: _extraArgs,
                minLines: 2,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Extra args (comma or line separated)',
                  prefixIcon: Icon(AppIcons.settings),
                ),
              ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Source',
          icon: AppIcons.repos,
          child: Column(
            children: [
              if (repoItems.isNotEmpty && hasLinkedRepoInOptions)
                KomodoSelectMenuFormField<String>(
                  key: ValueKey('build_linked_repo_${repoItems.length}'),
                  initialValue: _linkedRepo.text.trim().isNotEmpty
                      ? _linkedRepo.text.trim()
                      : null,
                  items: repoItems
                      .map(
                        (r) => KomodoSelectMenuItem(value: r.id, label: r.name),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _linkedRepo.text = v);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Linked repo',
                    prefixIcon: Icon(AppIcons.repos),
                  ),
                )
              else
                TextFormField(
                  controller: _linkedRepo,
                  decoration: const InputDecoration(
                    labelText: 'Linked repo (id)',
                    prefixIcon: Icon(AppIcons.repos),
                  ),
                ),
              const Gap(12),
              if (repoPathOptions.isNotEmpty && hasRepoInOptions)
                KomodoSelectMenuFormField<String>(
                  key: ValueKey('build_repo_${repoPathOptions.length}'),
                  initialValue: _repo.text.trim().isNotEmpty
                      ? _repo.text.trim()
                      : null,
                  items: repoPathOptions
                      .map((r) => KomodoSelectMenuItem(value: r, label: r))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _repo.text = v);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Repo',
                    prefixIcon: Icon(AppIcons.repos),
                  ),
                )
              else
                TextFormField(
                  controller: _repo,
                  decoration: const InputDecoration(
                    labelText: 'Repo (e.g. org/name)',
                    prefixIcon: Icon(AppIcons.repos),
                  ),
                ),
              const Gap(12),
              if (branchOptions.isNotEmpty && hasBranchInOptions)
                KomodoSelectMenuFormField<String>(
                  key: ValueKey('build_branch_${branchOptions.length}'),
                  initialValue: _branch.text.trim().isNotEmpty
                      ? _branch.text.trim()
                      : null,
                  items: branchOptions
                      .map((b) => KomodoSelectMenuItem(value: b, label: b))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _branch.text = v);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Branch',
                    prefixIcon: Icon(AppIcons.tag),
                  ),
                )
              else
                TextFormField(
                  controller: _branch,
                  decoration: const InputDecoration(
                    labelText: 'Branch',
                    prefixIcon: Icon(AppIcons.tag),
                  ),
                ),
              const Gap(12),
              TextFormField(
                controller: _commit,
                decoration: const InputDecoration(
                  labelText: 'Commit (optional)',
                  prefixIcon: Icon(AppIcons.tag),
                ),
              ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          key: const ValueKey('build_paths_card'),
          title: 'Paths',
          icon: AppIcons.package,
          collapsible: true,
          initiallyExpanded: false,
          summary: _pathsSummary(),
          modified: _modified(const ['build_path', 'dockerfile_path']),
          child: Column(
            children: [
              TextFormField(
                controller: _buildPath,
                decoration: const InputDecoration(
                  labelText: 'Build path',
                  prefixIcon: Icon(AppIcons.package),
                ),
              ),
              const Gap(12),
              TextFormField(
                controller: _dockerfilePath,
                decoration: const InputDecoration(
                  labelText: 'Dockerfile path',
                  prefixIcon: Icon(AppIcons.package),
                ),
              ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          key: const ValueKey('build_toggles_card'),
          title: 'Toggles',
          icon: AppIcons.settings,
          collapsible: true,
          initiallyExpanded: false,
          summary: _togglesSummary(),
          modified: _modified(const [
            'webhook_enabled',
            'auto_increment_version',
            'use_buildx',
            'files_on_host',
            'skip_secret_interp',
          ]),
          child: Column(
            children: [
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
                value: _autoIncrementVersion,
                onChanged: (v) {
                  setState(() => _autoIncrementVersion = v);
                  _notifyDirtyIfChanged();
                },
                title: const Text('Auto increment version'),
                secondary: const Icon(AppIcons.tag),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile.adaptive(
                value: _useBuildx,
                onChanged: (v) {
                  setState(() => _useBuildx = v);
                  _notifyDirtyIfChanged();
                },
                title: const Text('Use Buildx'),
                secondary: const Icon(AppIcons.builds),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile.adaptive(
                value: _filesOnHost,
                onChanged: (v) {
                  setState(() => _filesOnHost = v);
                  _notifyDirtyIfChanged();
                },
                title: const Text('Files on host'),
                secondary: const Icon(AppIcons.package),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile.adaptive(
                value: _skipSecretInterp,
                onChanged: (v) {
                  setState(() => _skipSecretInterp = v);
                  _notifyDirtyIfChanged();
                },
                title: const Text('Skip secret interpolation'),
                secondary: const Icon(AppIcons.warning),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Hashes Content
class BuildHashesContent extends StatelessWidget {
  const BuildHashesContent({required this.buildResource, super.key});

  final KomodoBuild buildResource;

  static String _short(String? hash) {
    if (hash == null || hash.isEmpty) return '—';
    return hash.length > 8 ? hash.substring(0, 8) : hash;
  }

  @override
  Widget build(BuildContext context) {
    final info = buildResource.info;

    return DetailSubCard(
      key: const ValueKey('build_hashes_card'),
      title: 'Hashes',
      icon: AppIcons.tag,
      collapsible: true,
      initiallyExpanded: false,
      summary:
          'latest ${_short(info.latestHash)} · built ${_short(info.builtHash)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info.latestHash != null)
            DetailKeyValueRow(label: 'Latest Hash', value: info.latestHash!),
          if (info.builtHash != null)
            DetailKeyValueRow(label: 'Built Hash', value: info.builtHash!),
          if (info.latestMessage != null && info.latestMessage!.isNotEmpty)
            DetailKeyValueRow(
              label: 'Latest Message',
              value: info.latestMessage!,
            ),
          if (info.builtMessage != null && info.builtMessage!.isNotEmpty)
            DetailKeyValueRow(
              label: 'Built Message',
              value: info.builtMessage!,
              bottomPadding: 0,
            ),
        ],
      ),
    );
  }
}

// Logs Content
class BuildLogsContent extends StatelessWidget {
  const BuildLogsContent({required this.buildResource, super.key});

  final KomodoBuild buildResource;

  @override
  Widget build(BuildContext context) {
    final info = buildResource.info;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (info.remoteError != null &&
            info.remoteError!.trim().isNotEmpty) ...[
          Text(
            'Remote Error',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(8),
          DetailCodeBlock(
            code: info.remoteError!.trim(),
            maxHeight: 280,
            tabletMaxHeight: 420,
          ),
        ],
        if (info.remoteError != null &&
            info.remoteError!.trim().isNotEmpty &&
            ((info.remoteContents != null &&
                    info.remoteContents!.trim().isNotEmpty) ||
                (info.builtContents != null &&
                    info.builtContents!.trim().isNotEmpty)))
          const Gap(16),
        if (info.remoteContents != null &&
            info.remoteContents!.trim().isNotEmpty) ...[
          Text(
            'Remote Contents',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(8),
          DetailCodeBlock(
            code: info.remoteContents!.trim(),
            tabletMaxHeight: 560,
          ),
        ],
        if (info.remoteContents != null &&
            info.remoteContents!.trim().isNotEmpty &&
            info.builtContents != null &&
            info.builtContents!.trim().isNotEmpty)
          const Gap(16),
        if (info.builtContents != null &&
            info.builtContents!.trim().isNotEmpty) ...[
          Text(
            'Built Contents',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(8),
          DetailCodeBlock(
            code: info.builtContents!.trim(),
            tabletMaxHeight: 560,
          ),
        ],
      ],
    );
  }
}

// Helper Surfaces
class BuildMessageSurface extends StatelessWidget {
  const BuildMessageSurface({
    required this.message,
    this.icon = AppIcons.info,
    super.key,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DetailSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: EmptyStateView.inline(icon: icon, title: message),
      ),
    );
  }
}

class BuildLoadingSurface extends StatelessWidget {
  const BuildLoadingSurface({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppSkeletonSurface();
  }
}

class BuildErrorSurface extends StatelessWidget {
  const BuildErrorSurface({
    required this.error,
    required this.onRetry,
    super.key,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DetailSurface(
      child: ErrorStateView.fromError(
        title: 'Could not load build',
        error: error,
        onRetry: onRetry,
      ),
    );
  }
}
