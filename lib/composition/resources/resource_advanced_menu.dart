import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' show Either;
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/menus/komodo_popup_menu.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';
import 'package:komodo_go/shared/resources/data/resource_management_repository.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_metadata.dart';

enum ResourceAdvancedAction { metadata, copy, rename, delete }

class ResourceAdvancedMenuButton extends ConsumerStatefulWidget {
  const ResourceAdvancedMenuButton({
    required this.metadata,
    required this.onMutated,
    super.key,
  });

  final ResourceMetadata metadata;
  final VoidCallback onMutated;

  @override
  ConsumerState<ResourceAdvancedMenuButton> createState() =>
      _ResourceAdvancedMenuButtonState();
}

class _ResourceAdvancedMenuButtonState
    extends ConsumerState<ResourceAdvancedMenuButton> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: AppInlineSkeleton(size: 20),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<ResourceAdvancedAction>(
      key: const ValueKey('resource_advanced_menu'),
      tooltip: 'Edit resource',
      icon: const Icon(AppIcons.edit),
      onSelected: _handleAction,
      itemBuilder: (context) => [
        komodoPopupMenuItem(
          key: const ValueKey('resource_edit_metadata'),
          value: ResourceAdvancedAction.metadata,
          icon: AppIcons.tag,
          label: 'Edit metadata',
          iconColor: scheme.primary,
        ),
        komodoPopupMenuItem(
          key: const ValueKey('resource_copy'),
          value: ResourceAdvancedAction.copy,
          icon: AppIcons.copy,
          label: 'Copy resource',
          iconColor: scheme.primary,
        ),
        komodoPopupMenuItem(
          key: const ValueKey('resource_rename'),
          value: ResourceAdvancedAction.rename,
          icon: AppIcons.edit,
          label: 'Rename resource',
          iconColor: scheme.primary,
        ),
        komodoPopupMenuDivider(),
        komodoPopupMenuItem(
          key: const ValueKey('resource_delete'),
          value: ResourceAdvancedAction.delete,
          icon: AppIcons.delete,
          label: 'Delete resource',
          destructive: true,
        ),
      ],
    );
  }

  Future<void> _handleAction(ResourceAdvancedAction action) async {
    switch (action) {
      case ResourceAdvancedAction.metadata:
        final changed = await ResourceMetadataEditorSheet.show(
          context,
          metadata: widget.metadata,
        );
        if (changed && mounted) widget.onMutated();
        return;
      case ResourceAdvancedAction.copy:
        return _copy();
      case ResourceAdvancedAction.rename:
        return _rename();
      case ResourceAdvancedAction.delete:
        return _delete();
    }
  }

  Future<void> _copy() async {
    final name = await _promptName(
      context,
      title: 'Copy ${widget.metadata.kind.singularLabel}',
      actionLabel: 'Copy',
      initialValue: '${widget.metadata.name} copy',
    );
    if (name == null || !mounted) return;

    final success = await _runMutation(
      (repository) => repository.copy(
        kind: widget.metadata.kind,
        id: widget.metadata.id,
        name: name,
      ),
    );
    if (!success || !mounted) return;
    widget.onMutated();
    AppSnackBar.show(
      context,
      'Created $name',
      tone: AppSnackBarTone.success,
    );
  }

  Future<void> _rename() async {
    final name = await _promptName(
      context,
      title: 'Rename ${widget.metadata.kind.singularLabel}',
      actionLabel: 'Rename',
      initialValue: widget.metadata.name,
    );
    if (name == null || name == widget.metadata.name || !mounted) return;

    final success = await _runMutation(
      (repository) => repository.rename(
        kind: widget.metadata.kind,
        id: widget.metadata.id,
        name: name,
      ),
    );
    if (!success || !mounted) return;
    widget.onMutated();
    AppSnackBar.show(
      context,
      'Renamed to $name',
      tone: AppSnackBarTone.success,
    );
    Navigator.of(context).maybePop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${widget.metadata.name}?'),
        content: Text(
          'This permanently deletes the ${widget.metadata.kind.singularLabel.toLowerCase()} '
          'resource from Komodo. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm_resource_delete'),
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final success = await _runMutation(
      (repository) => repository.delete(
        kind: widget.metadata.kind,
        id: widget.metadata.id,
      ),
    );
    if (!success || !mounted) return;
    widget.onMutated();
    Navigator.of(context).maybePop();
  }

  Future<bool> _runMutation(
    Future<Either<Failure, void>> Function(
      ResourceManagementRepository repository,
    )
    request,
  ) async {
    final repository = ref.read(resourceManagementRepositoryProvider);
    if (repository == null) {
      AppSnackBar.show(
        context,
        'Not authenticated',
        tone: AppSnackBarTone.error,
      );
      return false;
    }

    setState(() => _busy = true);
    final result = await request(repository);
    if (!mounted) return false;
    setState(() => _busy = false);

    return result.fold(
      (failure) {
        AppSnackBar.show(
          context,
          failure.displayMessage,
          tone: AppSnackBarTone.error,
        );
        return false;
      },
      (_) => true,
    );
  }
}

class ResourceMetadataEditorSheet extends ConsumerStatefulWidget {
  const ResourceMetadataEditorSheet({required this.metadata, super.key});

  final ResourceMetadata metadata;

  static Future<bool> show(
    BuildContext context, {
    required ResourceMetadata metadata,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => ResourceMetadataEditorSheet(metadata: metadata),
    );
    return result ?? false;
  }

  @override
  ConsumerState<ResourceMetadataEditorSheet> createState() =>
      _ResourceMetadataEditorSheetState();
}

class _ResourceMetadataEditorSheetState
    extends ConsumerState<ResourceMetadataEditorSheet> {
  late final TextEditingController _descriptionController;
  late final Set<String> _selectedTags;
  late bool _template;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.metadata.description,
    );
    _selectedTags = widget.metadata.tags.toSet();
    _template = widget.metadata.template;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Edit metadata',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(AppIcons.close),
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('resource_metadata_scroll'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Gap(12),
                    TextField(
                      key: const ValueKey('resource_description_field'),
                      controller: _descriptionController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const Gap(8),
                    SwitchListTile(
                      key: const ValueKey('resource_template_switch'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Template'),
                      subtitle: const Text(
                        'Template resources are reusable starting points.',
                      ),
                      value: _template,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _template = value),
                    ),
                    const Gap(8),
                    Text(
                      'Tags',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Gap(4),
                    tagsAsync.when(
                      data: _buildTags,
                      loading: () => const Column(
                        children: [
                          AppSkeletonCard(showChips: false),
                          Gap(12),
                          AppSkeletonCard(showChips: false),
                        ],
                      ),
                      error: (error, _) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('Failed to load tags: $error'),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const Gap(8),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const Gap(12),
                    FilledButton.icon(
                      key: const ValueKey('save_resource_metadata'),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const AppInlineSkeleton(size: 18)
                          : const Icon(AppIcons.check),
                      label: Text(_saving ? 'Saving…' : 'Save metadata'),
                    ),
                    const Gap(4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTags(List<KomodoTag> tags) {
    final knownIds = tags.map((tag) => tag.id).toSet();
    final unavailableIds = _selectedTags.difference(knownIds).toList()..sort();

    if (tags.isEmpty && unavailableIds.isEmpty) {
      return const Center(child: Text('No tags have been created yet.'));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final tag in tags)
          CheckboxListTile(
            key: ValueKey('resource_tag_${tag.id}'),
            contentPadding: EdgeInsets.zero,
            secondary: Icon(AppIcons.tag, color: tag.color.swatch),
            title: Text(tag.name),
            value: _selectedTags.contains(tag.id),
            onChanged: _saving
                ? null
                : (selected) {
                    setState(() {
                      if (selected ?? false) {
                        _selectedTags.add(tag.id);
                      } else {
                        _selectedTags.remove(tag.id);
                      }
                    });
                  },
          ),
        for (final id in unavailableIds)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(AppIcons.lock),
            title: const Text('Assigned tag unavailable'),
            subtitle: Text(id),
          ),
      ],
    );
  }

  Future<void> _save() async {
    final repository = ref.read(resourceManagementRepositoryProvider);
    if (repository == null) {
      setState(() => _error = 'Not authenticated');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final tags = _selectedTags.toList()..sort();
    final result = await repository.updateMetadata(
      metadata: widget.metadata,
      draft: ResourceMetadataDraft(
        description: _descriptionController.text.trim(),
        template: _template,
        tags: tags,
      ),
    );
    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _saving = false;
        _error = failure.displayMessage;
      }),
      (_) => Navigator.of(context).pop(true),
    );
  }
}

Future<String?> _promptName(
  BuildContext context, {
  required String title,
  required String actionLabel,
  required String initialValue,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _NamePromptDialog(
      title: title,
      actionLabel: actionLabel,
      initialValue: initialValue,
    ),
  );
}

class _NamePromptDialog extends StatefulWidget {
  const _NamePromptDialog({
    required this.title,
    required this.actionLabel,
    required this.initialValue,
  });

  final String title;
  final String actionLabel;
  final String initialValue;

  @override
  State<_NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<_NamePromptDialog> {
  late final TextEditingController _controller;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('resource_name_field'),
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: 'Name',
          errorText: _validationError,
        ),
        onSubmitted: _submit,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('confirm_resource_name'),
          onPressed: () => _submit(_controller.text),
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }

  void _submit(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() => _validationError = 'Name is required');
      return;
    }
    Navigator.of(context).pop(trimmed);
  }
}
