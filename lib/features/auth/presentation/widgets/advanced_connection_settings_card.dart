import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/api/custom_header.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/always_paste_context_menu.dart';

class AdvancedConnectionSettingsCard extends StatelessWidget {
  const AdvancedConnectionSettingsCard({
    required this.expanded,
    required this.onToggle,
    required this.children,
    super.key,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(AppIcons.settings),
            title: const Text('Advanced config'),
            subtitle: const Text('Headers & more'),
            trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            onTap: onToggle,
          ),
          if (expanded) const Divider(height: 1),
          if (expanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _withSpacing(children),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> widgets) {
    final spaced = <Widget>[];
    for (var index = 0; index < widgets.length; index++) {
      if (index > 0) {
        spaced.add(const Gap(24));
      }
      spaced.add(widgets[index]);
    }
    return spaced;
  }
}

class AdvancedConnectionSection extends StatelessWidget {
  const AdvancedConnectionSection({
    required this.title,
    required this.child,
    this.description,
    this.showTopDivider = false,
    super.key,
  });

  final String title;
  final String? description;
  final Widget child;
  final bool showTopDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTopDivider) ...[
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const Gap(20),
        ],
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (description != null) ...[
          const Gap(8),
          Text(
            description!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ],
        const Gap(16),
        child,
      ],
    );
  }
}

class ProxyHeaderAuthSection extends StatelessWidget {
  const ProxyHeaderAuthSection({
    required this.enabled,
    required this.onEnabledChanged,
    required this.usernameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onSubmitted,
    super.key,
  });

  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final ValueNotifier<bool> obscurePassword;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
    );

    return AdvancedConnectionSection(
      title: 'Proxy Header Auth',
      description:
          'Optional. The app sends Authorization: Basic <base64(username:password)> on each request when enabled.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable proxy header auth'),
            subtitle: Text(
              enabled
                  ? 'Authorization will be sent on requests.'
                  : 'Stored credentials are kept, but Authorization is not sent.',
              style: bodyStyle,
            ),
            value: enabled,
            onChanged: onEnabledChanged,
          ),
          const Gap(8),
          Text(
            'Your proxy must validate that header and then clear or override Authorization before forwarding requests to Komodo. Otherwise Komodo may try to use Authorization instead of X-Api-Key and X-Api-Secret.',
            style: bodyStyle,
          ),
          const Gap(12),
          Text(
            'If you apply that Authorization override on the same public endpoint used by the Komodo web UI, the web UI login will usually fail. In practice this setup works best with a separate app/API endpoint.',
            style: bodyStyle,
          ),
          const Gap(12),
          Text(
            'Why prefer this over bypass rules? Keeping the API behind the proxy preserves the proxy as the first security layer and reduces the number of directly exposed backend paths you must rush to patch during security incidents.',
            style: bodyStyle,
          ),
          const Gap(16),
          TextFormField(
            controller: usernameController,
            decoration: const InputDecoration(
              labelText: 'Proxy Username',
              prefixIcon: Icon(AppIcons.key),
            ),
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableInteractiveSelection: true,
            contextMenuBuilder: alwaysPasteContextMenu,
            validator: (value) {
              if (!enabled) {
                return null;
              }
              final username = value?.trim() ?? '';
              final password = passwordController.text.trim();
              if (username.isEmpty && password.isNotEmpty) {
                return 'Please enter proxy username';
              }
              return null;
            },
          ),
          const Gap(16),
          TextFormField(
            controller: passwordController,
            decoration: InputDecoration(
              labelText: 'Proxy Password',
              prefixIcon: const Icon(AppIcons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword.value ? AppIcons.eye : AppIcons.eyeOff,
                ),
                onPressed: () {
                  obscurePassword.value = !obscurePassword.value;
                },
              ),
            ),
            obscureText: obscurePassword.value,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableInteractiveSelection: true,
            contextMenuBuilder: alwaysPasteContextMenu,
            onFieldSubmitted: (_) => onSubmitted(),
            validator: (value) {
              if (!enabled) {
                return null;
              }
              final password = value?.trim() ?? '';
              final username = usernameController.text.trim();
              if (password.isNotEmpty && username.isEmpty) {
                return 'Please enter proxy username';
              }
              if (password.isEmpty && username.isNotEmpty) {
                return 'Please enter proxy password';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class CustomHeadersSection extends StatefulWidget {
  const CustomHeadersSection({
    required this.headers,
    required this.onChanged,
    super.key,
  });

  final List<CustomHeader> headers;
  final ValueChanged<List<CustomHeader>> onChanged;

  @override
  State<CustomHeadersSection> createState() => _CustomHeadersSectionState();
}

class _CustomHeadersSectionState extends State<CustomHeadersSection> {
  late List<TextEditingController> _keyControllers;
  late List<TextEditingController> _valueControllers;

  @override
  void initState() {
    super.initState();
    _keyControllers = <TextEditingController>[];
    _valueControllers = <TextEditingController>[];
    _rebuildControllers(widget.headers);
  }

  @override
  void didUpdateWidget(covariant CustomHeadersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_controllersMatch(widget.headers)) {
      _rebuildControllers(widget.headers);
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
    );

    return AdvancedConnectionSection(
      title: 'Custom Headers',
      description:
          'Optional. Add additional headers to every request. Reserved auth headers such as Authorization, X-Api-Key, and X-Api-Secret cannot be overridden here.',
      showTopDivider: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.headers.isEmpty)
            Text(
              'No custom headers configured.',
              style: bodyStyle,
            ),
          for (var index = 0; index < widget.headers.length; index++) ...[
            if (index > 0) const Gap(12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _keyControllers[index],
                    decoration: const InputDecoration(
                      labelText: 'Key',
                    ),
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableInteractiveSelection: true,
                    contextMenuBuilder: alwaysPasteContextMenu,
                    onChanged: (value) {
                      _updateHeader(index, key: value);
                    },
                    validator: (value) {
                      final key = value?.trim() ?? '';
                      final rowValue = _valueControllers[index].text.trim();
                      if (key.isEmpty && rowValue.isEmpty) {
                        return null;
                      }
                      if (key.isEmpty) {
                        return 'Enter a key';
                      }
                      if (isReservedManagedHeaderName(key)) {
                        return 'Reserved by the app';
                      }
                      final occurrences = _keyControllers
                          .where(
                            (controller) =>
                                controller.text.trim().toLowerCase() ==
                                key.toLowerCase(),
                          )
                          .length;
                      if (occurrences > 1) {
                        return 'Duplicate header';
                      }
                      return null;
                    },
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: TextFormField(
                    controller: _valueControllers[index],
                    decoration: const InputDecoration(
                      labelText: 'Value',
                    ),
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableInteractiveSelection: true,
                    contextMenuBuilder: alwaysPasteContextMenu,
                    onChanged: (value) {
                      _updateHeader(index, value: value);
                    },
                  ),
                ),
                const Gap(8),
                IconButton(
                  tooltip: 'Remove header',
                  onPressed: () {
                    final next = [...widget.headers]..removeAt(index);
                    widget.onChanged(next);
                  },
                  icon: const Icon(AppIcons.delete),
                ),
              ],
            ),
          ],
          const Gap(16),
          OutlinedButton.icon(
            onPressed: () {
              widget.onChanged([
                ...widget.headers,
                const CustomHeader(key: '', value: ''),
              ]);
            },
            icon: const Icon(AppIcons.add),
            label: const Text('Add header'),
          ),
        ],
      ),
    );
  }

  void _updateHeader(int index, {String? key, String? value}) {
    final next = [...widget.headers];
    if (index >= next.length) {
      return;
    }
    next[index] = next[index].copyWith(
      key: key ?? next[index].key,
      value: value ?? next[index].value,
    );
    widget.onChanged(next);
  }

  void _rebuildControllers(List<CustomHeader> headers) {
    _disposeControllers();
    _keyControllers = [
      for (final header in headers) TextEditingController(text: header.key),
    ];
    _valueControllers = [
      for (final header in headers) TextEditingController(text: header.value),
    ];
  }

  void _disposeControllers() {
    for (final controller in _keyControllers) {
      controller.dispose();
    }
    for (final controller in _valueControllers) {
      controller.dispose();
    }
  }

  bool _controllersMatch(List<CustomHeader> headers) {
    if (_keyControllers.length != headers.length ||
        _valueControllers.length != headers.length) {
      return false;
    }
    for (var index = 0; index < headers.length; index++) {
      if (_keyControllers[index].text != headers[index].key ||
          _valueControllers[index].text != headers[index].value) {
        return false;
      }
    }
    return true;
  }
}
