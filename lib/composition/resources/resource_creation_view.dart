import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/deployments/deployment_detail_sections.dart';
import 'package:komodo_go/composition/stacks/stack_config_editor.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/actions/presentation/providers/actions_provider.dart';
import 'package:komodo_go/features/actions/presentation/views/action_detail_view.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:komodo_go/features/deployments/presentation/providers/deployments_provider.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/features/procedures/presentation/providers/procedures_provider.dart';
import 'package:komodo_go/features/procedures/presentation/views/procedure_detail_view.dart';
import 'package:komodo_go/features/providers/presentation/providers/docker_registry_provider.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/features/servers/presentation/views/server_detail/server_detail_sections.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_provider.dart';
import 'package:komodo_go/shared/resources/data/resource_management_repository.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';

enum ResourceCreationMode { template, copy, blank }

class ResourceCreationView extends ConsumerStatefulWidget {
  const ResourceCreationView({required this.kind, super.key});

  final ResourceKind kind;

  @override
  ConsumerState<ResourceCreationView> createState() =>
      _ResourceCreationViewState();
}

class _ResourceCreationViewState extends ConsumerState<ResourceCreationView> {
  final _nameController = TextEditingController();
  final _stagesController = TextEditingController(text: '[]');
  final _stackKey = GlobalKey<StackConfigEditorContentState>();
  final _deploymentKey = GlobalKey<DeploymentConfigEditorContentState>();
  final _serverKey = GlobalKey<ServerConfigEditorContentState>();
  final _actionKey = GlobalKey<ActionConfigEditorContentState>();
  final _procedureKey = GlobalKey<ProcedureConfigEditorContentState>();

  ResourceCreationMode _mode = ResourceCreationMode.template;
  String? _sourceId;
  String? _error;
  var _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _stagesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sources = _watchSources();
    final filteredSources = _mode == ResourceCreationMode.template
        ? sources.where((source) => source.template).toList()
        : sources;
    if (_sourceId != null &&
        !filteredSources.any((source) => source.id == _sourceId)) {
      _sourceId = null;
    }

    return Scaffold(
      appBar: MainAppBar(
        title: 'Create ${widget.kind.singularLabel}',
        icon: widget.kind.icon,
        markColor: widget.kind.color,
        markUseGradient: true,
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<ResourceCreationMode>(
              key: const ValueKey('creation_mode'),
              segments: const [
                ButtonSegment(
                  value: ResourceCreationMode.template,
                  icon: Icon(Icons.auto_awesome_outlined),
                  label: Text('Template'),
                ),
                ButtonSegment(
                  value: ResourceCreationMode.copy,
                  icon: Icon(Icons.copy_outlined),
                  label: Text('Copy'),
                ),
                ButtonSegment(
                  value: ResourceCreationMode.blank,
                  icon: Icon(Icons.edit_note_outlined),
                  label: Text('Full form'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: _saving
                  ? null
                  : (selection) => setState(() {
                      _mode = selection.first;
                      _sourceId = null;
                      _error = null;
                    }),
            ),
            const Gap(16),
            TextField(
              key: const ValueKey('resource_name'),
              controller: _nameController,
              enabled: !_saving,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Unique resource name',
              ),
            ),
            const Gap(16),
            if (_mode != ResourceCreationMode.blank)
              DropdownButtonFormField<String>(
                key: const ValueKey('creation_source'),
                initialValue: _sourceId,
                decoration: InputDecoration(
                  labelText: _mode == ResourceCreationMode.template
                      ? 'Template'
                      : 'Resource to copy',
                  helperText: filteredSources.isEmpty
                      ? _mode == ResourceCreationMode.template
                            ? 'No templates are available.'
                            : 'No resources are available.'
                      : null,
                ),
                items: [
                  for (final source in filteredSources)
                    DropdownMenuItem(
                      value: source.id,
                      child: Text(source.name),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _sourceId = value),
              )
            else
              _buildFullForm(),
            if (_error != null) ...[
              const Gap(16),
              Text(
                _error!,
                key: const ValueKey('creation_error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const Gap(20),
            FilledButton.icon(
              key: const ValueKey('create_resource'),
              onPressed: _saving ? null : _create,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(_saving ? 'Creating…' : 'Create resource'),
            ),
            const Gap(32),
          ],
        ),
      ),
    );
  }

  List<_CreationSource> _watchSources() => switch (widget.kind) {
    ResourceKind.stacks =>
      ref
          .watch(stacksProvider)
          .maybeWhen(
            data: (items) => [
              for (final item in items)
                _CreationSource(
                  id: item.id,
                  name: item.name,
                  template: item.template,
                ),
            ],
            orElse: () => const [],
          ),
    ResourceKind.deployments =>
      ref
          .watch(deploymentsProvider)
          .maybeWhen(
            data: (items) => [
              for (final item in items)
                _CreationSource(
                  id: item.id,
                  name: item.name,
                  template: item.template,
                ),
            ],
            orElse: () => const [],
          ),
    ResourceKind.servers =>
      ref
          .watch(serversProvider)
          .maybeWhen(
            data: (items) => [
              for (final item in items)
                _CreationSource(
                  id: item.id,
                  name: item.name,
                  template: item.template,
                ),
            ],
            orElse: () => const [],
          ),
    ResourceKind.actions =>
      ref
          .watch(actionsProvider)
          .maybeWhen(
            data: (items) => [
              for (final item in items)
                _CreationSource(
                  id: item.id,
                  name: item.name,
                  template: item.template,
                ),
            ],
            orElse: () => const [],
          ),
    ResourceKind.procedures =>
      ref
          .watch(proceduresProvider)
          .maybeWhen(
            data: (items) => [
              for (final item in items)
                _CreationSource(
                  id: item.id,
                  name: item.name,
                  template: item.template,
                ),
            ],
            orElse: () => const [],
          ),
    _ => const [],
  };

  Widget _buildFullForm() {
    final servers =
        ref.watch(serversProvider).asData?.value ?? const <Server>[];
    final repos = ref.watch(reposProvider).asData?.value ?? const [];
    final registries =
        ref.watch(dockerRegistryAccountsProvider).asData?.value ?? const [];
    return switch (widget.kind) {
      ResourceKind.stacks => StackConfigEditorContent(
        key: _stackKey,
        stackIdOrName: 'new',
        initialConfig: const StackConfig(),
        servers: servers,
        repos: repos,
        registryAccounts: registries,
      ),
      ResourceKind.deployments => DeploymentConfigEditorContent(
        key: _deploymentKey,
        initialConfig: const DeploymentConfig(),
        imageLabel: 'Image',
        servers: servers,
        registryAccounts: registries,
      ),
      ResourceKind.servers => ServerConfigEditorContent(
        key: _serverKey,
        initialConfig: const ServerConfig(),
      ),
      ResourceKind.actions => ActionConfigEditorContent(
        key: _actionKey,
        initialConfig: const ActionConfig(),
      ),
      ResourceKind.procedures => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProcedureConfigEditorContent(
            key: _procedureKey,
            initialConfig: const ProcedureConfig(),
          ),
          const Gap(16),
          TextField(
            key: const ValueKey('procedure_stages'),
            controller: _stagesController,
            minLines: 5,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Stages (JSON)',
              helperText:
                  'Define the complete stages array. Leave [] for no stages.',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Map<String, dynamic>? _buildConfig() {
    switch (widget.kind) {
      case ResourceKind.stacks:
        return _stackKey.currentState?.buildPartialConfigParams();
      case ResourceKind.deployments:
        final state = _deploymentKey.currentState;
        final validation = state?.validateDraft();
        if (validation != null) {
          _error = validation;
          return null;
        }
        return state?.buildPartialConfigParams();
      case ResourceKind.servers:
        return _serverKey.currentState?.buildPartialConfigParams();
      case ResourceKind.actions:
        return _actionKey.currentState?.buildPartialConfigParams();
      case ResourceKind.procedures:
        final config = _procedureKey.currentState?.buildPartialConfigParams();
        if (config == null) return null;
        try {
          final stages = jsonDecode(_stagesController.text);
          if (stages is! List) {
            _error = 'Stages must be a JSON array.';
            return null;
          }
          return <String, dynamic>{...config, 'stages': stages};
        } on FormatException catch (error) {
          _error = 'Invalid stages JSON: ${error.message}';
          return null;
        }
      case ResourceKind.builds:
      case ResourceKind.repos:
      case ResourceKind.syncs:
      case ResourceKind.builders:
      case ResourceKind.alerters:
      case ResourceKind.system:
      case ResourceKind.unknown:
        return null;
    }
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a resource name.');
      return;
    }
    if (_mode != ResourceCreationMode.blank && _sourceId == null) {
      setState(() => _error = 'Select a source resource.');
      return;
    }
    final config = _mode == ResourceCreationMode.blank ? _buildConfig() : null;
    if (_mode == ResourceCreationMode.blank && config == null) {
      setState(() => _error ??= 'The config editor is not ready.');
      return;
    }
    final repository = ref.read(resourceManagementRepositoryProvider);
    if (repository == null) {
      setState(() => _error = 'No active Komodo connection.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = _mode == ResourceCreationMode.blank
        ? await repository.create(
            kind: widget.kind,
            name: name,
            config: config!,
          )
        : await repository.copyAndReturn(
            kind: widget.kind,
            id: _sourceId!,
            name: name,
          );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _saving = false;
        _error = failure.displayMessage;
      }),
      (created) {
        _invalidateList();
        AppSnackBar.show(
          context,
          '${widget.kind.singularLabel} created.',
          tone: AppSnackBarTone.success,
        );
        context.replace(_detailLocation(created));
      },
    );
  }

  void _invalidateList() {
    switch (widget.kind) {
      case ResourceKind.stacks:
        ref.invalidate(stacksProvider);
      case ResourceKind.deployments:
        ref.invalidate(deploymentsProvider);
      case ResourceKind.servers:
        ref.invalidate(serversProvider);
      case ResourceKind.actions:
        ref.invalidate(actionsProvider);
      case ResourceKind.procedures:
        ref.invalidate(proceduresProvider);
      case ResourceKind.builds:
      case ResourceKind.repos:
      case ResourceKind.syncs:
      case ResourceKind.builders:
      case ResourceKind.alerters:
      case ResourceKind.system:
      case ResourceKind.unknown:
        return;
    }
  }

  String _detailLocation(CreatedResource resource) {
    final base = switch (widget.kind) {
      ResourceKind.stacks => AppRoutes.stacks,
      ResourceKind.deployments => AppRoutes.deployments,
      ResourceKind.servers => AppRoutes.servers,
      ResourceKind.actions => AppRoutes.actions,
      ResourceKind.procedures => AppRoutes.procedures,
      _ => AppRoutes.resources,
    };
    return '$base/${resource.id}?name=${Uri.encodeComponent(resource.name)}';
  }
}

class _CreationSource {
  const _CreationSource({
    required this.id,
    required this.name,
    required this.template,
  });

  final String id;
  final String name;
  final bool template;
}
