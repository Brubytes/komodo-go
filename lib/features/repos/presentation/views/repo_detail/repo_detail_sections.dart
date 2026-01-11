import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/features/builders/data/models/builder_list_item.dart';
import 'package:komodo_go/features/providers/data/models/git_provider_account.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';

class RepoConfigEditorContent extends StatefulWidget {
  const RepoConfigEditorContent({
    required this.initialConfig,
    this.servers = const [],
    this.builders = const [],
    this.gitProviders = const [],
    super.key,
  });

  final RepoConfig initialConfig;
  final List<Server> servers;
  final List<BuilderListItem> builders;
  final List<GitProviderAccount> gitProviders;

  @override
  State<RepoConfigEditorContent> createState() =>
      RepoConfigEditorContentState();
}

class RepoConfigEditorContentState extends State<RepoConfigEditorContent> {
  late RepoConfig _initial;

  late final TextEditingController _serverId;
  late final TextEditingController _builderId;
  late final TextEditingController _gitProvider;
  late final TextEditingController _gitAccount;
  late final TextEditingController _repo;
  late final TextEditingController _branch;
  late final TextEditingController _commit;
  late final TextEditingController _path;

  var _webhookEnabled = false;
  var _gitHttps = false;
  var _skipSecretInterp = false;

  @override
  void initState() {
    super.initState();
    _initial = widget.initialConfig;

    _serverId = TextEditingController(text: _initial.serverId);
    _builderId = TextEditingController(text: _initial.builderId);
    _gitProvider = TextEditingController(text: _initial.gitProvider);
    _gitAccount = TextEditingController(text: _initial.gitAccount);
    _repo = TextEditingController(text: _initial.repo);
    _branch = TextEditingController(text: _initial.branch);
    _commit = TextEditingController(text: _initial.commit);
    _path = TextEditingController(text: _initial.path);

    _webhookEnabled = _initial.webhookEnabled;
    _gitHttps = _initial.gitHttps;
    _skipSecretInterp = _initial.skipSecretInterp;
  }

  @override
  void dispose() {
    _serverId.dispose();
    _builderId.dispose();
    _gitProvider.dispose();
    _gitAccount.dispose();
    _repo.dispose();
    _branch.dispose();
    _commit.dispose();
    _path.dispose();
    super.dispose();
  }

  void resetTo(RepoConfig config) {
    setState(() {
      _initial = config;

      _serverId.text = config.serverId;
      _builderId.text = config.builderId;
      _gitProvider.text = config.gitProvider;
      _gitAccount.text = config.gitAccount;
      _repo.text = config.repo;
      _branch.text = config.branch;
      _commit.text = config.commit;
      _path.text = config.path;

      _webhookEnabled = config.webhookEnabled;
      _gitHttps = config.gitHttps;
      _skipSecretInterp = config.skipSecretInterp;
    });
  }

  Map<String, dynamic> buildPartialConfigParams() {
    final params = <String, dynamic>{};

    void setIfChanged(String key, Object value, Object initialValue) {
      if (value != initialValue) params[key] = value;
    }

    setIfChanged('server_id', _serverId.text.trim(), _initial.serverId);
    setIfChanged('builder_id', _builderId.text.trim(), _initial.builderId);
    setIfChanged(
      'git_provider',
      _gitProvider.text.trim(),
      _initial.gitProvider,
    );
    setIfChanged('git_account', _gitAccount.text.trim(), _initial.gitAccount);

    setIfChanged('repo', _repo.text.trim(), _initial.repo);
    setIfChanged('branch', _branch.text.trim(), _initial.branch);
    setIfChanged('commit', _commit.text.trim(), _initial.commit);
    setIfChanged('path', _path.text.trim(), _initial.path);

    setIfChanged('webhook_enabled', _webhookEnabled, _initial.webhookEnabled);
    setIfChanged('git_https', _gitHttps, _initial.gitHttps);
    setIfChanged(
      'skip_secret_interp',
      _skipSecretInterp,
      _initial.skipSecretInterp,
    );

    return params;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final sortedServers = [...widget.servers]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final sortedBuilders = [...widget.builders]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

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

    final serverIdInList = sortedServers.any((s) => s.id == _serverId.text);
    final builderIdInList =
        _builderId.text.isEmpty ||
        sortedBuilders.any((b) => b.id == _builderId.text);

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
                value: _webhookEnabled,
                title: const Text('Webhook enabled'),
                onChanged: (v) => setState(() => _webhookEnabled = v),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _gitHttps,
                title: const Text('Git HTTPS'),
                onChanged: (v) => setState(() => _gitHttps = v),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _skipSecretInterp,
                title: const Text('Skip secret interpolation'),
                onChanged: (v) => setState(() => _skipSecretInterp = v),
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
              if (gitProviderDomains.isNotEmpty)
                DropdownButtonFormField<String>(
                  key: ValueKey(gitProviderDomains.length),
                  value: providerDomainInList ? _gitProvider.text.trim() : null,
                  decoration: const InputDecoration(
                    labelText: 'Git provider',
                    prefixIcon: Icon(AppIcons.repos),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('—')),
                    for (final domain in gitProviderDomains)
                      DropdownMenuItem(value: domain, child: Text(domain)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _gitProvider.text = value;
                      // Reset account if it no longer matches the new domain options.
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
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    '${selectedDomain}_${accountsForDomain.length}',
                  ),
                  value: accountInList ? _gitAccount.text.trim() : null,
                  decoration: const InputDecoration(
                    labelText: 'Git account',
                    prefixIcon: Icon(AppIcons.user),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('—')),
                    for (final account in accountsForDomain)
                      DropdownMenuItem(
                        value: account.username,
                        child: Text(account.username),
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
          title: 'Paths',
          icon: AppIcons.package,
          child: Column(
            children: [
              TextFormField(
                controller: _path,
                decoration: const InputDecoration(
                  labelText: 'Path',
                  prefixIcon: Icon(AppIcons.package),
                ),
              ),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Deployment',
          icon: AppIcons.server,
          child: Column(
            children: [
              if (sortedServers.isNotEmpty)
                DropdownButtonFormField<String>(
                  key: ValueKey(sortedServers.length),
                  value: serverIdInList ? _serverId.text : null,
                  decoration: InputDecoration(
                    labelText: 'Server',
                    prefixIcon: const Icon(AppIcons.server),
                    helperStyle: TextStyle(color: scheme.onSurfaceVariant),
                    helperText:
                        'Changing server may cleanup the repo on the old server.',
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('—')),
                    for (final server in sortedServers)
                      DropdownMenuItem(
                        value: server.id,
                        child: Text(server.name),
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
                    helperText:
                        'Changing server may cleanup the repo on the old server.',
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
              const Gap(12),
              if (sortedBuilders.isNotEmpty)
                DropdownButtonFormField<String>(
                  key: ValueKey(sortedBuilders.length),
                  value: builderIdInList ? _builderId.text : null,
                  decoration: const InputDecoration(
                    labelText: 'Builder',
                    prefixIcon: Icon(AppIcons.factory),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('—')),
                    for (final builder in sortedBuilders)
                      DropdownMenuItem(
                        value: builder.id,
                        child: Text(builder.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _builderId.text = value);
                  },
                )
              else
                TextFormField(
                  controller: _builderId,
                  decoration: const InputDecoration(
                    labelText: 'Builder ID',
                    prefixIcon: Icon(AppIcons.factory),
                  ),
                ),
              if (sortedBuilders.isNotEmpty && !builderIdInList) ...[
                const Gap(8),
                TextFormField(
                  controller: _builderId,
                  decoration: const InputDecoration(
                    labelText: 'Builder ID (manual)',
                    prefixIcon: Icon(AppIcons.tag),
                    helperText: 'Current value not found in builder list.',
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
