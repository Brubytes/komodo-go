import 'package:flutter/material.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

/// Shared Domain / Username / Token fields for git provider and docker
/// registry account editors. Shows inline "required" errors once the user has
/// interacted with a field.
class AccountEditorFields extends StatefulWidget {
  const AccountEditorFields({
    required this.domainController,
    required this.usernameController,
    required this.tokenController,
    required this.isEditing,
    required this.onChanged,
    super.key,
    this.footer,
  });

  final TextEditingController domainController;
  final TextEditingController usernameController;
  final TextEditingController tokenController;
  final bool isEditing;
  final VoidCallback onChanged;
  final Widget? footer;

  @override
  State<AccountEditorFields> createState() => _AccountEditorFieldsState();
}

class _AccountEditorFieldsState extends State<AccountEditorFields> {
  var _obscureToken = true;
  final _touched = <String>{};

  String? _required(String field, TextEditingController c, String message) {
    if (!_touched.contains(field)) return null;
    return c.text.trim().isEmpty ? message : null;
  }

  void _changed(String field) {
    setState(() => _touched.add(field));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.domainController,
          textInputAction: TextInputAction.next,
          onChanged: (_) => _changed('domain'),
          decoration: InputDecoration(
            labelText: 'Domain',
            prefixIcon: const Icon(AppIcons.network),
            errorText: _required(
              'domain',
              widget.domainController,
              'Enter a domain.',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: widget.usernameController,
          textInputAction: TextInputAction.next,
          onChanged: (_) => _changed('username'),
          decoration: InputDecoration(
            labelText: 'Username',
            prefixIcon: const Icon(AppIcons.user),
            errorText: _required(
              'username',
              widget.usernameController,
              'Enter a username.',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: widget.tokenController,
          textInputAction: TextInputAction.done,
          obscureText: _obscureToken,
          onChanged: (_) => _changed('token'),
          decoration: InputDecoration(
            labelText: 'Token',
            prefixIcon: const Icon(AppIcons.key),
            helperText: widget.isEditing
                ? 'Leave blank to keep the existing token.'
                : null,
            errorText: widget.isEditing
                ? null
                : _required('token', widget.tokenController, 'Enter a token.'),
            suffixIcon: IconButton(
              tooltip: _obscureToken ? 'Show' : 'Hide',
              icon: Icon(_obscureToken ? AppIcons.eye : AppIcons.eyeOff),
              onPressed: () => setState(() => _obscureToken = !_obscureToken),
            ),
          ),
        ),
        if (widget.footer != null) ...[
          const SizedBox(height: AppSpacing.sm),
          widget.footer!,
        ],
      ],
    );
  }
}
