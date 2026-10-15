import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' show Either;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/resources/resource_advanced_menu.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_action_bar.dart';
import 'package:komodo_go/core/widgets/dialogs/confirm_destructive_dialog.dart';
import 'package:komodo_go/shared/resources/data/resource_management_repository.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_metadata.dart';

/// Builds the "Manage" group of a detail screen's More menu: edit metadata,
/// copy, rename and delete (same behaviour as [ResourceAdvancedMenuButton]).
DetailActionGroup buildResourceManageGroup({
  required BuildContext context,
  required WidgetRef ref,
  required ResourceMetadata metadata,
  required VoidCallback onMutated,
}) {
  final kindLabel = metadata.kind.singularLabel;

  Future<bool> run(
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
    final result = await request(repository);
    if (!context.mounted) return false;
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

  Future<void> editMetadata() async {
    final changed = await ResourceMetadataEditorSheet.show(
      context,
      metadata: metadata,
    );
    if (changed && context.mounted) onMutated();
  }

  Future<void> copy() async {
    final name = await promptResourceName(
      context,
      title: 'Copy $kindLabel',
      actionLabel: 'Copy',
      initialValue: '${metadata.name} copy',
    );
    if (name == null || !context.mounted) return;
    final ok = await run(
      (r) => r.copy(kind: metadata.kind, id: metadata.id, name: name),
    );
    if (!ok || !context.mounted) return;
    onMutated();
    AppSnackBar.show(context, 'Created $name', tone: AppSnackBarTone.success);
  }

  Future<void> rename() async {
    final name = await promptResourceName(
      context,
      title: 'Rename $kindLabel',
      actionLabel: 'Rename',
      initialValue: metadata.name,
    );
    if (name == null || name == metadata.name || !context.mounted) return;
    final ok = await run(
      (r) => r.rename(kind: metadata.kind, id: metadata.id, name: name),
    );
    if (!ok || !context.mounted) return;
    onMutated();
    AppSnackBar.show(
      context,
      'Renamed to $name',
      tone: AppSnackBarTone.success,
    );
    Navigator.of(context).maybePop();
  }

  Future<void> delete() async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete ${metadata.name}?',
      message:
          'This permanently deletes the ${kindLabel.toLowerCase()} '
          'resource from Komodo. This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !context.mounted) return;
    final ok = await run(
      (r) => r.delete(kind: metadata.kind, id: metadata.id),
    );
    if (!ok || !context.mounted) return;
    onMutated();
    Navigator.of(context).maybePop();
  }

  return DetailActionGroup(
    label: 'Manage',
    sheetLabel: 'Manage…',
    items: [
      DetailActionItem(
        label: 'Edit metadata',
        icon: AppIcons.tag,
        onSelected: editMetadata,
      ),
      DetailActionItem(
        label: 'Copy $kindLabel',
        icon: AppIcons.copy,
        onSelected: copy,
      ),
      DetailActionItem(
        label: 'Rename $kindLabel',
        icon: AppIcons.edit,
        onSelected: rename,
      ),
      DetailActionItem(
        label: 'Delete $kindLabel',
        icon: AppIcons.delete,
        destructive: true,
        onSelected: delete,
      ),
    ],
  );
}
