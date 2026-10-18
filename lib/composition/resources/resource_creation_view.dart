import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/deployments/deployment_detail_sections.dart';
import 'package:komodo_go/composition/stacks/stack_config_editor.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/segmented/app_segmented_control.dart';
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
  final _stackKey = GlobalKey<StackConfigEditorContentState>();
  final _deploymentKey = GlobalKey<DeploymentConfigEditorContentState>();
  final _serverKey = GlobalKey<ServerConfigEditorContentState>();
  final _actionKey = GlobalKey<ActionConfigEditorContentState>();
  final _procedureKey = GlobalKey<ProcedureConfigEditorContentState>();

  ResourceCreationMode _mode = ResourceCreationMode.blank;
  var _advancedExpanded = false;
  String? _sourceId;
  String? _error;
  var _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
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

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: MainAppBar(
        title: 'Create ${widget.kind.singularLabel}',
        icon: widget.kind.icon,
        markColor: widget.kind.color,
        markUseGradient: true,
        centerTitle: true,
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          TextField(
            key: const ValueKey('resource_name'),
            autocorrect: false,
            enableSuggestions: false,
            smartQuotesType: SmartQuotesType.disabled,
            smartDashesType: SmartDashesType.disabled,
            controller: _nameController,
            enabled: !_saving,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Unique resource name',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Start from',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSegmentedControl<ResourceCreationMode>(
            key: const ValueKey('creation_mode'),
            segments: const [
              AppSegmentOption(
                value: ResourceCreationMode.blank,
                icon: Icons.note_add_outlined,
                label: 'Empty',
              ),
              AppSegmentOption(
                value: ResourceCreationMode.template,
                icon: Icons.auto_awesome_outlined,
                label: 'Template',
              ),
              AppSegmentOption(
                value: ResourceCreationMode.copy,
                icon: Icons.copy_outlined,
                label: 'Copy',
              ),
            ],
            value: _mode,
            onChanged: _saving
                ? null
                : (mode) => setState(() {
                    _mode = mode;
                    _sourceId = null;
                    _error = null;
                  }),
          ),
          const SizedBox(height: AppSpacing.lg),
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
                  DropdownMenuItem(value: source.id, child: Text(source.name)),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _sourceId = value),
            )
          else if (_hasFullForm)
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: const ValueKey('configure_now'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                initiallyExpanded: _advancedExpanded,
                onExpansionChanged: (v) =>
                    setState(() => _advancedExpanded = v),
                title: const Text('Configure now (advanced)'),
                subtitle: const Text(
                  'Optional. You can also configure everything after creating.',
                ),
                children: [_buildFullForm()],
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              _error!,
              key: const ValueKey('creation_error'),
              style: TextStyle(color: scheme.error),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: FilledButton.icon(
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
        ),
      ),
    );
  }

  bool get _hasFullForm => switch (widget.kind) {
    ResourceKind.stacks ||
    ResourceKind.deployments ||
    ResourceKind.servers ||
    ResourceKind.actions ||
    ResourceKind.procedures => true,
    _ => false,
  };

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
      ResourceKind.procedures => ProcedureConfigEditorContent(
        key: _procedureKey,
        initialConfig: const ProcedureConfig(),
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
        return _procedureKey.currentState?.buildPartialConfigParams();
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
    final useConfig = _mode == ResourceCreationMode.blank;
    Map<String, dynamic>? config;
    if (useConfig) {
      config = _advancedExpanded ? _buildConfig() : <String, dynamic>{};
      if (config == null) {
        setState(() => _error ??= 'The config editor is not ready.');
        return;
      }
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
