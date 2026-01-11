import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/features/providers/data/models/git_provider_account.dart';

class GitProviderEditorResult {
  const GitProviderEditorResult({
    required this.domain,
    required this.username,
    required this.token,
    required this.https,
  });

  final String domain;
  final String username;
  final String token;
  final bool https;
}

class GitProviderEditorSheet extends StatefulWidget {
  const GitProviderEditorSheet({super.key, this.initial});

  final GitProviderAccount? initial;

  static Future<GitProviderEditorResult?> show(
    BuildContext context, {
    GitProviderAccount? initial,
  }) {
    return showModalBottomSheet<GitProviderEditorResult>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => GitProviderEditorSheet(initial: initial),
    );
  }

  @override
  State<GitProviderEditorSheet> createState() => _GitProviderEditorSheetState();
}

class _GitProviderEditorSheetState extends State<GitProviderEditorSheet> {
  late final TextEditingController _domainController;
  late final TextEditingController _usernameController;
  late final TextEditingController _tokenController;
  var _https = true;
  var _obscureToken = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _domainController = TextEditingController(text: initial?.domain ?? '');
    _usernameController = TextEditingController(text: initial?.username ?? '');
    _tokenController = TextEditingController();
    _https = initial?.https ?? true;
  }

  @override
  void dispose() {
    _domainController.dispose();
    _usernameController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        top: 8,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  isEditing ? 'Edit provider' : 'New provider',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(AppIcons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Gap(12),
            TextField(
              controller: _domainController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Domain',
                prefixIcon: Icon(AppIcons.network),
              ),
            ),
            const Gap(12),
            TextField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(AppIcons.user),
              ),
            ),
            const Gap(12),
            TextField(
              controller: _tokenController,
              textInputAction: TextInputAction.done,
              obscureText: _obscureToken,
              decoration: InputDecoration(
                labelText: 'Token',
                prefixIcon: const Icon(AppIcons.key),
                helperText: isEditing
                    ? 'Leave blank to keep the existing token.'
                    : null,
                suffixIcon: IconButton(
                  tooltip: _obscureToken ? 'Show' : 'Hide',
                  icon: Icon(_obscureToken ? AppIcons.eye : AppIcons.eyeOff),
                  onPressed: () =>
                      setState(() => _obscureToken = !_obscureToken),
                ),
              ),
            ),
            const Gap(10),
            SwitchListTile.adaptive(
              value: _https,
              onChanged: (value) => setState(() => _https = value),
              title: const Text('Use HTTPS'),
              subtitle: const Text(
                'Enable HTTPS for provider authentication requests.',
              ),
            ),
            const Gap(12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final domain = _domainController.text.trim();
                  final username = _usernameController.text.trim();
                  final token = _tokenController.text.trim();

                  if (domain.isEmpty || username.isEmpty) {
                    return;
                  }
                  if (!isEditing && token.isEmpty) {
                    return;
                  }
                  Navigator.of(context).pop(
                    GitProviderEditorResult(
                      domain: domain,
                      username: username,
                      token: token,
                      https: _https,
                    ),
                  );
                },
                child: Text(isEditing ? 'Save' : 'Create'),
              ),
            ),
            const Gap(12),
          ],
        ),
      ),
    );
  }
}
