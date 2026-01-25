import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/app_floating_action_button.dart';
import 'package:komodo_go/core/widgets/detail/detail_pills.dart';
import 'package:komodo_go/core/widgets/empty_error_state.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/providers/data/models/docker_registry_account.dart';
import 'package:komodo_go/features/providers/data/models/git_provider_account.dart';
import 'package:komodo_go/features/providers/presentation/providers/docker_registry_provider.dart';
import 'package:komodo_go/features/providers/presentation/providers/git_providers_provider.dart';
import 'package:komodo_go/features/providers/presentation/widgets/docker_registry_editor_sheet.dart';
import 'package:komodo_go/features/providers/presentation/widgets/git_provider_editor_sheet.dart';

class ProvidersView extends ConsumerWidget {
  const ProvidersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providersAsync = ref.watch(gitProvidersProvider);
    final registriesAsync = ref.watch(dockerRegistryAccountsProvider);
    final gitActionsState = ref.watch(gitProviderActionsProvider);
    final registryActionsState = ref.watch(dockerRegistryActionsProvider);
    final isBusy = gitActionsState.isLoading || registryActionsState.isLoading;

    return Scaffold(
      appBar: const MainAppBar(
        title: 'Providers',
        icon: AppIcons.repos,
        centerTitle: true,
      ),
      floatingActionButton: AppSecondaryFab.extended(
        onPressed: isBusy ? null : () => _createProvider(context, ref),
        icon: const Icon(AppIcons.add),
        label: const Text('Add'),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await Future.wait<void>([
                ref.read(gitProvidersProvider.notifier).refresh(),
                ref.read(dockerRegistryAccountsProvider.notifier).refresh(),
              ]);
            },
            child: providersAsync.when(
              data: (providers) => registriesAsync.when(
                data: (registries) {
                  if (providers.isEmpty && registries.isEmpty) {
                    return const _EmptyState();
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const _SectionHeader(title: 'Git Providers'),
                      const Gap(8),
                      if (providers.isEmpty)
                        const _SectionHint(
                          message: 'No git provider accounts yet.',
                        )
                      else
                        ..._buildCards(
                          providers.map(
                            (provider) => _ProviderTile(
                              provider: provider,
                              onEdit: () =>
                                  _editGitProvider(context, ref, provider),
                              onDelete: () =>
                                  _deleteGitProvider(context, ref, provider),
                            ),
                          ),
                        ),
                      const Gap(20),
                      const _SectionHeader(title: 'Registry Accounts'),
                      const Gap(8),
                      if (registries.isEmpty)
                        const _SectionHint(message: 'No registry accounts yet.')
                      else
                        ..._buildCards(
                          registries.map(
                            (registry) => _RegistryTile(
                              registry: registry,
                              onEdit: () =>
                                  _editRegistry(context, ref, registry),
                              onDelete: () =>
                                  _deleteRegistry(context, ref, registry),
                            ),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ErrorStateView(
                  title: 'Failed to load registries',
                  message: error.toString(),
                  onRetry: () => ref.invalidate(dockerRegistryAccountsProvider),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorStateView(
                title: 'Failed to load providers',
                message: error.toString(),
                onRetry: () => ref.invalidate(gitProvidersProvider),
              ),
            ),
          ),
          if (isBusy)
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

  List<Widget> _buildCards(Iterable<Widget> tiles) {
    final items = <Widget>[];
    var index = 0;
    for (final tile in tiles) {
      items.add(
        AppFadeSlide(
          delay: AppMotion.stagger(index),
          play: index < 10,
          child: tile,
        ),
      );
      index += 1;
      items.add(const Gap(12));
    }
    if (items.isNotEmpty) {
      items.removeLast();
    }
    return items;
  }

  Future<void> _createProvider(BuildContext context, WidgetRef ref) async {
    final type = await _ProviderTypeSheet.show(context);
    if (type == null) return;

    switch (type) {
      case _ProviderType.git:
        final result = await GitProviderEditorSheet.show(context);
        if (result == null) return;

        final ok = await ref
            .read(gitProviderActionsProvider.notifier)
            .create(
              domain: result.domain,
              username: result.username,
              token: result.token,
              https: result.https,
            );

        if (!context.mounted) return;
        AppSnackBar.show(
          context,
          ok ? 'Provider created' : 'Failed to create provider',
          tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
        );
      case _ProviderType.registry:
        final result = await DockerRegistryEditorSheet.show(context);
        if (result == null) return;

        final ok = await ref
            .read(dockerRegistryActionsProvider.notifier)
            .create(
              domain: result.domain,
              username: result.username,
              token: result.token,
            );

        if (!context.mounted) return;
        AppSnackBar.show(
          context,
          ok ? 'Registry created' : 'Failed to create registry',
          tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
        );
    }
  }

  Future<void> _editGitProvider(
    BuildContext context,
    WidgetRef ref,
    GitProviderAccount provider,
  ) async {
    final result = await GitProviderEditorSheet.show(
      context,
      initial: provider,
    );
    if (result == null) return;

    final ok = await ref
        .read(gitProviderActionsProvider.notifier)
        .update(
          original: provider,
          domain: result.domain,
          username: result.username,
          https: result.https,
          token: result.token,
        );

    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      ok ? 'Provider updated' : 'Failed to update provider',
      tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }

  Future<void> _deleteGitProvider(
    BuildContext context,
    WidgetRef ref,
    GitProviderAccount provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete provider'),
        content: Text('Delete ${provider.username}@${provider.domain}?'),
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
        .read(gitProviderActionsProvider.notifier)
        .delete(provider.id);

    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      ok ? 'Provider deleted' : 'Failed to delete provider',
      tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }

  Future<void> _editRegistry(
    BuildContext context,
    WidgetRef ref,
    DockerRegistryAccount registry,
  ) async {
    final result = await DockerRegistryEditorSheet.show(
      context,
      initial: registry,
    );
    if (result == null) return;

    final ok = await ref
        .read(dockerRegistryActionsProvider.notifier)
        .update(
          original: registry,
          domain: result.domain,
          username: result.username,
          token: result.token,
        );

    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      ok ? 'Registry updated' : 'Failed to update registry',
      tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }

  Future<void> _deleteRegistry(
    BuildContext context,
    WidgetRef ref,
    DockerRegistryAccount registry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete registry'),
        content: Text('Delete ${registry.username}@${registry.domain}?'),
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
        .read(dockerRegistryActionsProvider.notifier)
        .delete(registry.id);

    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      ok ? 'Registry deleted' : 'Failed to delete registry',
      tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }
}

enum _ProviderAction { edit, delete }

enum _ProviderType { git, registry }

class _ProviderTypeSheet extends StatelessWidget {
  const _ProviderTypeSheet();

  static Future<_ProviderType?> show(BuildContext context) {
    return showModalBottomSheet<_ProviderType>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const _ProviderTypeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Add provider',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          const Gap(12),
          ListTile(
            leading: const Icon(AppIcons.repos),
            title: const Text('Git provider'),
            subtitle: const Text('Connect GitHub, GitLab, and more'),
            onTap: () => Navigator.of(context).pop(_ProviderType.git),
          ),
          const Gap(4),
          ListTile(
            leading: const Icon(AppIcons.package),
            title: const Text('Registry account'),
            subtitle: const Text('Authenticate to container registries'),
            onTap: () => Navigator.of(context).pop(_ProviderType.registry),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(
            title,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.1,
            ),
          ),
          const Spacer(),
          Container(
            width: 34,
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}

class _SectionHint extends StatelessWidget {
  const _SectionHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.provider,
    required this.onEdit,
    required this.onDelete,
  });

  final GitProviderAccount provider;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = '${provider.username}@${provider.domain}';

    final cardRadius = BorderRadius.circular(AppTokens.radiusLg);

    return AppCardSurface(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: cardRadius,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(AppIcons.repos, color: scheme.primary, size: 18),
          ),
          title: Text(
            provider.domain,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextPill(label: provider.https ? 'HTTPS' : 'HTTP'),
              const Gap(6),
              PopupMenuButton<_ProviderAction>(
                onSelected: (action) {
                  switch (action) {
                    case _ProviderAction.edit:
                      onEdit();
                    case _ProviderAction.delete:
                      onDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _ProviderAction.edit,
                    child: Row(
                      children: [
                        Icon(AppIcons.edit, color: scheme.primary, size: 18),
                        const Gap(10),
                        const Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _ProviderAction.delete,
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
      ),
    );
  }
}

class _RegistryTile extends StatelessWidget {
  const _RegistryTile({
    required this.registry,
    required this.onEdit,
    required this.onDelete,
  });

  final DockerRegistryAccount registry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = '${registry.username}@${registry.domain}';

    final cardRadius = BorderRadius.circular(AppTokens.radiusLg);

    return AppCardSurface(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: cardRadius,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.tertiary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(AppIcons.package, color: scheme.tertiary, size: 18),
          ),
          title: Text(
            registry.domain,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: PopupMenuButton<_ProviderAction>(
            onSelected: (action) {
              switch (action) {
                case _ProviderAction.edit:
                  onEdit();
                case _ProviderAction.delete:
                  onDelete();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _ProviderAction.edit,
                child: Row(
                  children: [
                    Icon(AppIcons.edit, color: scheme.primary, size: 18),
                    const Gap(10),
                    const Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _ProviderAction.delete,
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
          onTap: onEdit,
        ),
      ),
    );
  }
}

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
          AppIcons.repos,
          size: 64,
          color: scheme.primary.withValues(alpha: 0.5),
        ),
        const Gap(16),
        Text(
          'No providers found',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const Gap(8),
        Text(
          'Create git providers and registry accounts to access private sources.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
