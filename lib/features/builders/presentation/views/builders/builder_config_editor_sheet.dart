import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';

class BuilderConfigEditorResult {
  const BuilderConfigEditorResult({required this.config, required this.name});

  final Map<String, dynamic> config;
  final String name;
}

class BuilderConfigEditorSheet extends StatefulWidget {
  const BuilderConfigEditorSheet({
    required this.builderName,
    required this.builderType,
    required this.builderJson,
    super.key,
  });

  final String builderName;
  final String builderType;
  final Map<String, dynamic> builderJson;

  static Future<BuilderConfigEditorResult?> show(
    BuildContext context, {
    required String builderName,
    required String builderType,
    required Map<String, dynamic> builderJson,
  }) {
    return showModalBottomSheet<BuilderConfigEditorResult>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => BuilderConfigEditorSheet(
        builderName: builderName,
        builderType: builderType,
        builderJson: builderJson,
      ),
    );
  }

  @override
  State<BuilderConfigEditorSheet> createState() =>
      _BuilderConfigEditorSheetState();
}

class _BuilderConfigEditorSheetState extends State<BuilderConfigEditorSheet> {
  late final _BuilderConfigShape _shape;

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _passkeyController;
  late final TextEditingController _serverIdController;

  late final TextEditingController _awsRegionController;
  late final TextEditingController _awsInstanceTypeController;
  late final TextEditingController _awsVolumeGbController;
  late final TextEditingController _awsPortController;
  bool _awsUseHttps = false;
  bool _awsAssignPublicIp = false;
  bool _awsUsePublicIp = false;

  bool _showPasskey = false;

  @override
  void initState() {
    super.initState();

    _shape = _parseBuilderConfig(
      widget.builderJson['config'],
      fallbackType: widget.builderType,
    );

    final inner = _shape.inner;
    _nameController = TextEditingController(text: widget.builderName);
    _addressController = TextEditingController(
      text: (inner['address'] ?? '').toString(),
    );
    _passkeyController = TextEditingController(
      text: (inner['passkey'] ?? '').toString(),
    );
    _serverIdController = TextEditingController(
      text: (inner['server_id'] ?? '').toString(),
    );

    _awsRegionController = TextEditingController(
      text: (inner['region'] ?? '').toString(),
    );
    _awsInstanceTypeController = TextEditingController(
      text: (inner['instance_type'] ?? '').toString(),
    );
    _awsVolumeGbController = TextEditingController(
      text: (inner['volume_gb'] ?? '').toString(),
    );
    _awsPortController = TextEditingController(
      text: (inner['port'] ?? '').toString(),
    );

    _awsUseHttps = _toBool(inner['use_https']) ?? false;
    _awsAssignPublicIp = _toBool(inner['assign_public_ip']) ?? false;
    _awsUsePublicIp = _toBool(inner['use_public_ip']) ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _passkeyController.dispose();
    _serverIdController.dispose();
    _awsRegionController.dispose();
    _awsInstanceTypeController.dispose();
    _awsVolumeGbController.dispose();
    _awsPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.builderJson['config'];
    final description = (widget.builderJson['description'] ?? '')
        .toString()
        .trim();
    final template = _toBool(widget.builderJson['template']) ?? false;

    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'Edit builder',
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
          const Gap(6),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(AppIcons.tag),
            ),
          ),
          const Gap(12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextPill(label: _shape.variant),
              if (template) const TextPill(label: 'Template'),
              if (description.isNotEmpty)
                const TextPill(label: 'Has description'),
            ],
          ),
          const Gap(14),
          if (config is! Map<String, dynamic>)
            Text(
              'Builder config format not supported yet.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            )
          else
            _buildConfigForm(context),
          const Gap(16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: config is Map<String, dynamic> ? _onSave : null,
              child: const Text('Save'),
            ),
          ),
          const Gap(12),
        ],
      ),
    );
  }

  Widget _buildConfigForm(BuildContext context) {
    return switch (_shape.variant) {
      'Url' => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _addressController,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Address',
              prefixIcon: Icon(AppIcons.network),
            ),
          ),
          const Gap(12),
          TextField(
            controller: _passkeyController,
            textInputAction: TextInputAction.done,
            obscureText: !_showPasskey,
            decoration: InputDecoration(
              labelText: 'Passkey',
              prefixIcon: const Icon(AppIcons.lock),
              suffixIcon: IconButton(
                tooltip: _showPasskey ? 'Hide' : 'Show',
                icon: Icon(
                  _showPasskey ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _showPasskey = !_showPasskey),
              ),
            ),
          ),
        ],
      ),
      'Server' => TextField(
        controller: _serverIdController,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Server ID',
          prefixIcon: Icon(AppIcons.server),
        ),
      ),
      'Aws' => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _awsRegionController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Region',
              prefixIcon: Icon(Icons.public),
            ),
          ),
          const Gap(12),
          TextField(
            controller: _awsInstanceTypeController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Instance type',
              prefixIcon: Icon(AppIcons.factory),
            ),
          ),
          const Gap(12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _awsVolumeGbController,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Volume (GB)',
                    prefixIcon: Icon(Icons.storage_outlined),
                  ),
                ),
              ),
              const Gap(12),
              Expanded(
                child: TextField(
                  controller: _awsPortController,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    prefixIcon: Icon(Icons.settings_ethernet),
                  ),
                ),
              ),
            ],
          ),
          const Gap(12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use HTTPS'),
            value: _awsUseHttps,
            onChanged: (v) => setState(() => _awsUseHttps = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Assign public IP'),
            value: _awsAssignPublicIp,
            onChanged: (v) => setState(() => _awsAssignPublicIp = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use public IP'),
            value: _awsUsePublicIp,
            onChanged: (v) => setState(() => _awsUsePublicIp = v),
          ),
        ],
      ),
      _ => const SizedBox.shrink(),
    };
  }

  void _onSave() {
    final next = _shape.updated((inner) {
      return switch (_shape.variant) {
        'Url' => <String, dynamic>{
          ...inner,
          'address': _addressController.text.trim(),
          'passkey': _passkeyController.text,
        },
        'Server' => <String, dynamic>{
          ...inner,
          'server_id': _serverIdController.text.trim(),
        },
        'Aws' => <String, dynamic>{
          ...inner,
          'region': _awsRegionController.text.trim(),
          'instance_type': _awsInstanceTypeController.text.trim(),
          'volume_gb': int.tryParse(_awsVolumeGbController.text.trim()),
          'port': int.tryParse(_awsPortController.text.trim()),
          'use_https': _awsUseHttps,
          'assign_public_ip': _awsAssignPublicIp,
          'use_public_ip': _awsUsePublicIp,
        }..removeWhere((k, v) => v == null),
        _ => inner,
      };
    });

    Navigator.of(context).pop(
      BuilderConfigEditorResult(
        config: next,
        name: _nameController.text.trim(),
      ),
    );
  }
}

enum _ConfigEncoding { externalTagged, map }

class _BuilderConfigShape {
  const _BuilderConfigShape({
    required this.variant,
    required this.raw,
    required this.inner,
    required this.encoding,
  });

  final String variant;
  final Map<String, dynamic> raw;
  final Map<String, dynamic> inner;
  final _ConfigEncoding encoding;

  Map<String, dynamic> updated(
    Map<String, dynamic> Function(Map<String, dynamic> inner) updateInner,
  ) {
    final nextInner = updateInner(Map<String, dynamic>.from(inner));
    return switch (encoding) {
      _ConfigEncoding.externalTagged => <String, dynamic>{variant: nextInner},
      _ConfigEncoding.map => <String, dynamic>{...raw, ...nextInner},
    };
  }
}

_BuilderConfigShape _parseBuilderConfig(
  Object? raw, {
  required String fallbackType,
}) {
  if (raw is Map<String, dynamic>) {
    if (raw.length == 1) {
      final entry = raw.entries.first;
      if (entry.value is Map) {
        final inner = Map<String, dynamic>.from(entry.value as Map);
        return _BuilderConfigShape(
          variant: entry.key,
          raw: raw,
          inner: inner,
          encoding: _ConfigEncoding.externalTagged,
        );
      }
    }

    final inner = Map<String, dynamic>.from(raw);
    final type = (inner['type'] ?? inner['variant'])?.toString().trim();
    return _BuilderConfigShape(
      variant: (type?.isNotEmpty ?? false) ? type! : fallbackType,
      raw: inner,
      inner: inner,
      encoding: _ConfigEncoding.map,
    );
  }

  return _BuilderConfigShape(
    variant: fallbackType,
    raw: const <String, dynamic>{},
    inner: const <String, dynamic>{},
    encoding: _ConfigEncoding.map,
  );
}

bool? _toBool(Object? v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s == 'true') return true;
    if (s == 'false') return false;
  }
  return null;
}
