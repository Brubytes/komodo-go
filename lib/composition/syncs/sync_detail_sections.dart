import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/menus/komodo_select_menu_field.dart';
import 'package:komodo_go/features/providers/data/models/git_provider_account.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';

class SyncConfigEditorContent extends StatefulWidget {
  const SyncConfigEditorContent({
    required this.initialConfig,
    this.onDirtyChanged,
    this.repos = const [],
    this.gitProviders = const [],
    super.key,
  });

  final ResourceSyncConfig initialConfig;
  final ValueChanged<bool>? onDirtyChanged;
  final List<RepoListItem> repos;
  final List<GitProviderAccount> gitProviders;

  @override
  State<SyncConfigEditorContent> createState() =>
      SyncConfigEditorContentState();
}

class SyncConfigEditorContentState extends State<SyncConfigEditorContent> {
  late ResourceSyncConfig _initial;

  var _suppressDirtyNotify = false;
  var _lastDirty = false;

  late final TextEditingController _linkedRepo;
  late final TextEditingController _gitProvider;
  late final TextEditingController _gitAccount;
  late final TextEditingController _repo;
  late final TextEditingController _branch;
  late final TextEditingController _commit;
  late final TextEditingController _resourcePath;
  late final TextEditingController _matchTags;
  late final TextEditingController _webhookSecret;
  late final TextEditingController _fileContents;

  var _gitHttps = false;
  var _webhookEnabled = false;
  var _filesOnHost = false;
  var _managed = false;
  var _delete = false;
  var _includeResources = false;
  var _includeVariables = false;
  var _includeUserGroups = false;
  var _pendingAlert = false;

  @override
  void initState() {
    super.initState();
    _initial = widget.initialConfig;

    _linkedRepo = TextEditingController(text: _initial.linkedRepo);
    _gitProvider = TextEditingController(text: _initial.gitProvider);
    _gitAccount = TextEditingController(text: _initial.gitAccount);
    _repo = TextEditingController(text: _initial.repo);
    _branch = TextEditingController(text: _initial.branch);
    _commit = TextEditingController(text: _initial.commit);
    _resourcePath = TextEditingController(
      text: _initial.resourcePath.join('/'),
    );
    _matchTags = TextEditingController(text: _initial.matchTags.join('\n'));
    _webhookSecret = TextEditingController(text: _initial.webhookSecret);
    _fileContents = TextEditingController(text: _initial.fileContents);

    _gitHttps = _initial.gitHttps;
    _webhookEnabled = _initial.webhookEnabled;
    _filesOnHost = _initial.filesOnHost;
    _managed = _initial.managed;
    _delete = _initial.delete;
    _includeResources = _initial.includeResources;
    _includeVariables = _initial.includeVariables;
    _includeUserGroups = _initial.includeUserGroups;
    _pendingAlert = _initial.pendingAlert;

    for (final c in <TextEditingController>[
      _linkedRepo,
      _gitProvider,
      _gitAccount,
      _repo,
      _branch,
      _commit,
      _resourcePath,
      _matchTags,
      _webhookSecret,
      _fileContents,
    ]) {
      c.addListener(_notifyDirtyIfChanged);
    }
  }

  @override
  void didUpdateWidget(covariant SyncConfigEditorContent oldWidget) {
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
      _linkedRepo,
      _gitProvider,
      _gitAccount,
      _repo,
      _branch,
      _commit,
      _resourcePath,
      _matchTags,
      _webhookSecret,
      _fileContents,
    ]) {
      c.removeListener(_notifyDirtyIfChanged);
    }
    _linkedRepo.dispose();
    _gitProvider.dispose();
    _gitAccount.dispose();
    _repo.dispose();
    _branch.dispose();
    _commit.dispose();
    _resourcePath.dispose();
    _matchTags.dispose();
    _webhookSecret.dispose();
    _fileContents.dispose();
    super.dispose();
  }

  void resetTo(ResourceSyncConfig config) {
    _suppressDirtyNotify = true;
    setState(() {
      _initial = config;

      _linkedRepo.text = config.linkedRepo;
      _gitProvider.text = config.gitProvider;
      _gitAccount.text = config.gitAccount;
      _repo.text = config.repo;
      _branch.text = config.branch;
      _commit.text = config.commit;
      _resourcePath.text = config.resourcePath.join('/');
      _matchTags.text = config.matchTags.join('\n');
      _webhookSecret.text = config.webhookSecret;
      _fileContents.text = config.fileContents;

      _gitHttps = config.gitHttps;
      _webhookEnabled = config.webhookEnabled;
      _filesOnHost = config.filesOnHost;
      _managed = config.managed;
      _delete = config.delete;
      _includeResources = config.includeResources;
      _includeVariables = config.includeVariables;
      _includeUserGroups = config.includeUserGroups;
      _pendingAlert = config.pendingAlert;
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
      if (value != initialValue) params[key] = value;
    }

    setIfChanged('linked_repo', _linkedRepo.text.trim(), _initial.linkedRepo);
    setIfChanged(
      'git_provider',
      _gitProvider.text.trim(),
      _initial.gitProvider,
    );
    setIfChanged('git_account', _gitAccount.text.trim(), _initial.gitAccount);
    setIfChanged('git_https', _gitHttps, _initial.gitHttps);

    setIfChanged('repo', _repo.text.trim(), _initial.repo);
    setIfChanged('branch', _branch.text.trim(), _initial.branch);
    setIfChanged('commit', _commit.text.trim(), _initial.commit);

    setIfChanged('webhook_enabled', _webhookEnabled, _initial.webhookEnabled);
    setIfChanged(
      'webhook_secret',
      _webhookSecret.text.trim(),
      _initial.webhookSecret,
    );

    setIfChanged('files_on_host', _filesOnHost, _initial.filesOnHost);
    setIfChanged('managed', _managed, _initial.managed);
    setIfChanged('delete', _delete, _initial.delete);

    setIfChanged(
      'include_resources',
      _includeResources,
      _initial.includeResources,
    );
    setIfChanged(
      'include_variables',
      _includeVariables,
      _initial.includeVariables,
    );
    setIfChanged(
      'include_user_groups',
      _includeUserGroups,
      _initial.includeUserGroups,
    );
    setIfChanged('pending_alert', _pendingAlert, _initial.pendingAlert);

    final resourcePath = _normalizePathSegments(_resourcePath.text);
    if (!_listEquals(resourcePath, _initial.resourcePath)) {
      params['resource_path'] = resourcePath;
    }

    final matchTags = _normalizeList(_matchTags.text);
    if (!_listEquals(matchTags, _initial.matchTags)) {
      params['match_tags'] = matchTags;
    }

    final fileContents = _fileContents.text;
    if (fileContents != _initial.fileContents) {
      params['file_contents'] = fileContents;
    }

    return params;
  }

  List<String> _normalizeList(String input) {
    final parts = input
        .split(RegExp('[\n,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    return parts;
  }

  List<String> _normalizePathSegments(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return const [];
    return trimmed
        .split('/')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
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

    final sortedRepos = [...widget.repos]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final linkedRepoInList =
        _linkedRepo.text.isEmpty ||
        sortedRepos.any((r) => r.id == _linkedRepo.text);

    final repoPathOptions =
        <String>{
            for (final r in sortedRepos)
              if (r.info.repo.trim().isNotEmpty) r.info.repo.trim(),
          }.toList(growable: false)
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final repoInList =
        _repo.text.trim().isEmpty ||
        repoPathOptions.contains(_repo.text.trim());

    final sortedAccounts = [...widget.gitProviders]
      ..sort((a, b) {
        final d = a.domain.toLowerCase().compareTo(b.domain.toLowerCase());
        if (d != 0) return d;
        return a.username.toLowerCase().compareTo(b.username.toLowerCase());
      });

    final gitProviderDomains =
        <String>{
            for (final a in sortedAccounts)
              if (a.domain.trim().isNotEmpty) a.domain.trim(),
          }.toList(growable: false)
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final providerDomainInList =
        _gitProvider.text.isEmpty ||
        gitProviderDomains.contains(_gitProvider.text.trim());

    final selectedDomain = _gitProvider.text.trim();
    final accountsForDomain = selectedDomain.isEmpty
        ? <GitProviderAccount>[]
        : sortedAccounts
              .where((a) => a.domain.trim() == selectedDomain)
              .toList(growable: false);

    final accountInList =
        _gitAccount.text.isEmpty ||
        accountsForDomain.any((a) => a.username == _gitAccount.text.trim());

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
                value: _managed,
                title: const Text('Managed'),
                onChanged: (v) {
                  setState(() => _managed = v);
                  _notifyDirtyIfChanged();
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _delete,
                title: const Text('Delete missing'),
                onChanged: (v) {
                  setState(() => _delete = v);
                  _notifyDirtyIfChanged();
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _filesOnHost,
                title: const Text('Files on host'),
                onChanged: (v) {
                  setState(() => _filesOnHost = v);
                  _notifyDirtyIfChanged();
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _pendingAlert,
                title: const Text('Pending alert'),
                onChanged: (v) {
                  setState(() => _pendingAlert = v);
                  _notifyDirtyIfChanged();
                },
              ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Includes',
          icon: AppIcons.widgets,
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _includeResources,
                title: const Text('Include resources'),
                onChanged: (v) {
                  setState(() => _includeResources = v);
                  _notifyDirtyIfChanged();
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _includeVariables,
                title: const Text('Include variables'),
                onChanged: (v) {
                  setState(() => _includeVariables = v);
                  _notifyDirtyIfChanged();
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _includeUserGroups,
                title: const Text('Include user groups'),
                onChanged: (v) {
                  setState(() => _includeUserGroups = v);
                  _notifyDirtyIfChanged();
                },
              ),
              TextFormField(
                controller: _matchTags,
                minLines: 2,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'Match tags (comma or line separated)',
                  prefixIcon: const Icon(AppIcons.tag),
                  helperStyle: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Repository',
          icon: AppIcons.repos,
          child: Column(
            children: [
              if (sortedRepos.isNotEmpty)
                KomodoSelectMenuField<String>(
                  key: ValueKey('sync_linked_repo_${sortedRepos.length}'),
                  value: linkedRepoInList ? _linkedRepo.text : null,
                  decoration: const InputDecoration(
                    labelText: 'Linked repo',
                    prefixIcon: Icon(AppIcons.repos),
                  ),
                  items: [
                    const KomodoSelectMenuItem(value: '', label: '—'),
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
              const Gap(12),
              if (gitProviderDomains.isNotEmpty)
                KomodoSelectMenuField<String>(
                  key: ValueKey(
                    'sync_git_provider_${gitProviderDomains.length}',
                  ),
                  value: providerDomainInList ? _gitProvider.text.trim() : null,
                  decoration: const InputDecoration(
                    labelText: 'Git provider',
                    prefixIcon: Icon(AppIcons.repos),
                  ),
                  items: [
                    const KomodoSelectMenuItem(value: '', label: '—'),
                    for (final domain in gitProviderDomains)
                      KomodoSelectMenuItem(value: domain, label: domain),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _gitProvider.text = value;
                      final newDomain = value.trim();
                      final options = sortedAccounts
                          .where((a) => a.domain.trim() == newDomain)
                          .map((a) => a.username)
                          .toSet();
                      if (!options.contains(_gitAccount.text.trim())) {
                        _gitAccount.text = '';
                      }
                    });
                  },
                )
              else
                TextFormField(
                  controller: _gitProvider,
                  decoration: const InputDecoration(
                    labelText: 'Git provider',
                    prefixIcon: Icon(AppIcons.repos),
                  ),
                ),
              if (gitProviderDomains.isNotEmpty && !providerDomainInList) ...[
                const Gap(8),
                TextFormField(
                  controller: _gitProvider,
                  decoration: const InputDecoration(
                    labelText: 'Git provider (manual)',
                    prefixIcon: Icon(AppIcons.tag),
                    helperText: 'Current value not found in provider list.',
                  ),
                ),
              ],
              const Gap(12),
              if (accountsForDomain.isNotEmpty)
                KomodoSelectMenuField<String>(
                  key: ValueKey(
                    '${selectedDomain}_${accountsForDomain.length}',
                  ),
                  value: accountInList ? _gitAccount.text.trim() : null,
                  decoration: const InputDecoration(
                    labelText: 'Git account',
                    prefixIcon: Icon(AppIcons.user),
                  ),
                  items: [
                    const KomodoSelectMenuItem(value: '', label: '—'),
                    for (final account in accountsForDomain)
                      KomodoSelectMenuItem(
                        value: account.username,
                        label: account.username,
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _gitAccount.text = value);
                  },
                )
              else
                TextFormField(
                  controller: _gitAccount,
                  decoration: InputDecoration(
                    labelText: 'Git account',
                    prefixIcon: const Icon(AppIcons.user),
                    helperStyle: TextStyle(color: scheme.onSurfaceVariant),
                    helperText: selectedDomain.isEmpty
                        ? 'Select a git provider to see accounts.'
                        : 'No accounts for this provider; enter manually.',
                  ),
                ),
              if (accountsForDomain.isNotEmpty && !accountInList) ...[
                const Gap(8),
                TextFormField(
                  controller: _gitAccount,
                  decoration: const InputDecoration(
                    labelText: 'Git account (manual)',
                    prefixIcon: Icon(AppIcons.tag),
                    helperText: 'Current value not found in account list.',
                  ),
                ),
              ],
              const Gap(12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _gitHttps,
                title: const Text('Git HTTPS'),
                onChanged: (v) {
                  setState(() => _gitHttps = v);
                  _notifyDirtyIfChanged();
                },
              ),
              const Gap(12),
              if (repoPathOptions.isNotEmpty)
                KomodoSelectMenuField<String>(
                  key: ValueKey('sync_repo_${repoPathOptions.length}'),
                  value: repoInList ? _repo.text.trim() : null,
                  decoration: const InputDecoration(
                    labelText: 'Repo',
                    prefixIcon: Icon(AppIcons.repos),
                  ),
                  items: [
                    for (final repoPath in repoPathOptions)
                      KomodoSelectMenuItem(value: repoPath, label: repoPath),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _repo.text = value);
                  },
                )
              else
                TextFormField(
                  controller: _repo,
                  decoration: const InputDecoration(
                    labelText: 'Repo',
                    prefixIcon: Icon(AppIcons.repos),
                  ),
                ),
              const Gap(12),
              TextFormField(
                controller: _branch,
                decoration: const InputDecoration(
                  labelText: 'Branch',
                  prefixIcon: Icon(AppIcons.repos),
                ),
              ),
              const Gap(12),
              TextFormField(
                controller: _commit,
                decoration: const InputDecoration(
                  labelText: 'Commit',
                  prefixIcon: Icon(AppIcons.tag),
                ),
              ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Webhook',
          icon: AppIcons.notifications,
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _webhookEnabled,
                title: const Text('Webhook enabled'),
                onChanged: (v) {
                  setState(() => _webhookEnabled = v);
                  _notifyDirtyIfChanged();
                },
              ),
              TextFormField(
                controller: _webhookSecret,
                decoration: const InputDecoration(
                  labelText: 'Webhook secret',
                  prefixIcon: Icon(AppIcons.tag),
                ),
              ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Path',
          icon: AppIcons.package,
          child: Column(
            children: [
              TextFormField(
                controller: _resourcePath,
                decoration: const InputDecoration(
                  labelText: 'Resource path (slash separated)',
                  prefixIcon: Icon(AppIcons.package),
                ),
              ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'File Contents',
          icon: AppIcons.hardDrive,
          child: Column(
            children: [
              TextFormField(
                controller: _fileContents,
                minLines: 4,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: 'File contents',
                  prefixIcon: Icon(AppIcons.hardDrive),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
