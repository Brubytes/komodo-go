import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/empty_error_state.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/variables/data/models/variable.dart';
import 'package:komodo_go/features/variables/presentation/providers/variables_provider.dart';
import 'package:komodo_go/features/variables/presentation/widgets/variable_editor_sheet.dart';

class VariablesView extends ConsumerWidget {
  const VariablesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variablesAsync = ref.watch(variablesProvider);
    final actionsState = ref.watch(variableActionsProvider);

    return Scaffold(
      appBar: const MainAppBar(
        title: 'Variables',
        icon: AppIcons.key,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: actionsState.isLoading
            ? null
            : () async {
                final result = await VariableEditorSheet.show(context);
                if (result == null) return;

                final ok = await ref
                    .read(variableActionsProvider.notifier)
                    .create(
                      name: result.name,
                      value: result.value,
                      description: result.description,
                      isSecret: result.isSecret,
                    );

                if (!context.mounted) return;
                AppSnackBar.show(
                  context,
                  ok ? 'Variable created' : 'Failed to create variable',
                  tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
                );
              },
        icon: const Icon(AppIcons.add),
        label: const Text('Add'),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => ref.read(variablesProvider.notifier).refresh(),
            child: variablesAsync.when(
              data: (variables) {
                if (variables.isEmpty) {
                  return const _EmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: variables.length,
                  separatorBuilder: (_, __) => const Gap(12),
                  itemBuilder: (context, index) => _VariableTile(
                    variable: variables[index],
                    onEdit: () async {
                      final variable = variables[index];
                      final result = await VariableEditorSheet.show(
                        context,
                        initial: variable,
                      );
                      if (result == null) return;

                      final ok = await ref
                          .read(variableActionsProvider.notifier)
                          .update(
                            original: variable,
                            value: result.value,
                            description: result.description,
                            isSecret: result.isSecret,
                          );

                      if (!context.mounted) return;
                      AppSnackBar.show(
                        context,
                        ok ? 'Variable updated' : 'Failed to update variable',
                        tone: ok
                            ? AppSnackBarTone.success
                            : AppSnackBarTone.error,
                      );
                    },
                    onDelete: () async {
                      final variable = variables[index];
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete variable'),
                          content: Text('Delete "${variable.name}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;

                      final ok = await ref
                          .read(variableActionsProvider.notifier)
                          .delete(variable.name);

                      if (!context.mounted) return;
                      AppSnackBar.show(
                        context,
                        ok ? 'Variable deleted' : 'Failed to delete variable',
                        tone: ok
                            ? AppSnackBarTone.success
                            : AppSnackBarTone.error,
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorStateView(
                title: 'Failed to load variables',
                message: error.toString(),
                onRetry: () => ref.invalidate(variablesProvider),
              ),
            ),
          ),
          if (actionsState.isLoading)
            ColoredBox(
              color: Theme.of(
                context,
              ).colorScheme.scrim.withValues(alpha: 0.25),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _VariableTile extends StatelessWidget {
  const _VariableTile({
    required this.variable,
    required this.onEdit,
    required this.onDelete,
  });

  final KomodoVariable variable;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = variable.description.trim().isNotEmpty
        ? variable.description.trim()
        : (variable.isSecret ? 'Secret value' : 'Value: ${variable.value}');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(
          variable.isSecret ? AppIcons.lock : AppIcons.key,
          color: variable.isSecret ? scheme.tertiary : scheme.primary,
        ),
        title: Text(
          variable.name,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (variable.isSecret) const TextPill(label: 'Secret'),
            const Gap(8),
            PopupMenuButton<_VariableAction>(
              onSelected: (action) {
                switch (action) {
                  case _VariableAction.edit:
                    onEdit();
                  case _VariableAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _VariableAction.edit,
                  child: Row(
                    children: [
                      Icon(AppIcons.edit, color: scheme.primary, size: 18),
                      const Gap(10),
                      const Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _VariableAction.delete,
                  child: Row(
                    children: [
                      Icon(AppIcons.delete, color: scheme.error, size: 18),
                      const Gap(10),
                      const Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

enum _VariableAction { edit, delete }

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Gap(48),
        Icon(
          AppIcons.key,
          size: 64,
          color: scheme.primary.withValues(alpha: 0.5),
        ),
        const Gap(16),
        Text(
          'No variables found',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const Gap(8),
        Text(
          'Create global variables for interpolation in deployments/builds.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
