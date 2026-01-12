import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/menus/komodo_popup_menu.dart';
import 'package:komodo_go/features/builders/presentation/providers/builders_provider.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/builds/presentation/providers/builds_provider.dart';
import 'package:komodo_go/features/builds/presentation/views/build_detail/build_detail_sections.dart';
import 'package:komodo_go/features/builds/presentation/widgets/build_card.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';

/// View displaying detailed build information.
class BuildDetailView extends ConsumerStatefulWidget {
  const BuildDetailView({
    required this.buildId,
    required this.buildName,
    super.key,
  });

  final String buildId;
  final String buildName;

  @override
  ConsumerState<BuildDetailView> createState() => _BuildDetailViewState();
}

class _BuildDetailViewState extends ConsumerState<BuildDetailView> {
  final _configEditorKey = GlobalKey<BuildConfigEditorContentState>();

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
  _configDirtySnackBar;
  var _configSaveInFlight = false;

  @override
  Widget build(BuildContext context) {
    final buildId = widget.buildId;
    final buildAsync = ref.watch(buildDetailProvider(buildId));
    final buildsListAsync = ref.watch(buildsProvider);
    final actionsState = ref.watch(buildActionsProvider);
    final buildersAsync = ref.watch(buildersProvider);
    final reposAsync = ref.watch(reposProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: MainAppBar(
        title: widget.buildName,
        icon: AppIcons.builds,
        markColor: AppTokens.resourceBuilds,
        markUseGradient: true,
        centerTitle: true,
        actions: [
          PopupMenuButton<BuildAction>(
            icon: const Icon(AppIcons.moreVertical),
            onSelected: (action) => _handleAction(buildId, action),
            itemBuilder: (context) {
              final scheme = Theme.of(context).colorScheme;
              return [
                komodoPopupMenuItem(
                  value: BuildAction.run,
                  icon: AppIcons.play,
                  label: 'Run build',
                  iconColor: scheme.secondary,
                ),
                komodoPopupMenuItem(
                  value: BuildAction.cancel,
                  icon: AppIcons.stop,
                  label: 'Cancel',
                  destructive: true,
                ),
              ];
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(buildDetailProvider(buildId));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                buildAsync.when(
                  data: (build) {
                    if (build == null) {
                      return const BuildMessageSurface(
                        message: 'Build not found',
                      );
                    }

                    BuildListItem? listItem;
                    final list = buildsListAsync.asData?.value;
                    if (list != null) {
                      for (final item in list) {
                        if (item.id == build.id) {
                          listItem = item;
                          break;
                        }
                      }
                    }

                    final builderId = build.config.builderId;
                    final builderNameAsync = builderId.isEmpty
                        ? const AsyncValue<String?>.data(null)
                        : ref.watch(builderNameProvider(builderId));

                    final builderLabel = builderNameAsync.when(
                      data: (name) => (name != null && name.trim().isNotEmpty)
                          ? name.trim()
                          : (builderId.isNotEmpty ? builderId : null),
                      loading: () => 'Loading…',
                      error: (_, __) => builderId.isNotEmpty ? builderId : null,
                    );

                    final builders = buildersAsync.asData?.value ?? const [];
                    final repos = reposAsync.asData?.value ?? const [];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BuildHeroPanel(
                          buildResource: build,
                          listItem: listItem,
                          builderLabel: builderLabel,
                        ),
                        const Gap(16),
                        DetailSection(
                          title: 'Build Configuration',
                          icon: AppIcons.settings,
                          child: BuildConfigEditorContent(
                            key: _configEditorKey,
                            initialConfig: build.config,
                            builders: builders,
                            repos: repos,
                            onDirtyChanged: (dirty) {
                              _onConfigDirtyChanged(dirty: dirty, build: build);
                            },
                          ),
                        ),
                        const Gap(16),
                        DetailSection(
                          title: 'Source',
                          icon: AppIcons.repos,
                          child: BuildSourceContent(buildResource: build),
                        ),
                        if (build.info.latestHash != null ||
                            build.info.builtHash != null) ...[
                          const Gap(16),
                          DetailSection(
                            title: 'Commit Hashes',
                            icon: AppIcons.tag,
                            child: BuildHashesContent(buildResource: build),
                          ),
                        ],
                        if ((build.info.remoteError != null &&
                                build.info.remoteError!.trim().isNotEmpty) ||
                            (build.info.remoteContents != null &&
                                build.info.remoteContents!.trim().isNotEmpty) ||
                            (build.info.builtContents != null &&
                                build.info.builtContents!
                                    .trim()
                                    .isNotEmpty)) ...[
                          const Gap(16),
                          DetailSection(
                            title: 'Logs',
                            icon: AppIcons.package,
                            child: BuildLogsContent(buildResource: build),
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => const BuildLoadingSurface(),
                  error: (error, _) =>
                      BuildErrorSurface(error: error.toString()),
                ),
              ],
            ),
          ),
          if (actionsState.isLoading)
            ColoredBox(
              color: scheme.scrim.withValues(alpha: 0.25),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleAction(String buildId, BuildAction action) async {
    final actions = ref.read(buildActionsProvider.notifier);
    final success = await switch (action) {
      BuildAction.run => actions.run(buildId),
      BuildAction.cancel => actions.cancel(buildId),
    };

    if (success) {
      ref.invalidate(buildDetailProvider(buildId));
    }

    if (!mounted) return;

    AppSnackBar.show(
      context,
      success
          ? 'Action completed successfully'
          : 'Action failed. Please try again.',
      tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }

  void _onConfigDirtyChanged({
    required bool dirty,
    required KomodoBuild build,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!dirty) {
        _hideConfigDirtySnackBar();
      } else {
        _showConfigDirtySnackBar(build);
      }
    });
  }

  void _hideConfigDirtySnackBar() {
    if (_configDirtySnackBar == null) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _configDirtySnackBar = null;
  }

  void _showConfigDirtySnackBar(KomodoBuild build) {
    if (_configDirtySnackBar != null) return;

    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;

    final controller = messenger.showSnackBar(
      SnackBar(
        backgroundColor: scheme.inverseSurface,
        duration: const Duration(days: 1),
        dismissDirection: DismissDirection.none,
        behavior: SnackBarBehavior.floating,
        content: DefaultTextStyle(
          style: TextStyle(color: scheme.onInverseSurface),
          child: Row(
            children: [
              const Expanded(child: Text('Unsaved changes')),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onInverseSurface,
                ),
                onPressed: () => _discardConfig(build),
                child: const Text('Discard'),
              ),
              const Gap(8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _saveConfig(build: build),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );

    _configDirtySnackBar = controller;
    controller.closed.then((_) {
      if (!mounted) return;
      if (_configDirtySnackBar == controller) {
        _configDirtySnackBar = null;
      }
    });
  }

  void _discardConfig(KomodoBuild build) {
    _configEditorKey.currentState?.resetTo(build.config);
    _hideConfigDirtySnackBar();
  }

  Future<void> _saveConfig({required KomodoBuild build}) async {
    if (_configSaveInFlight) return;

    final draft = _configEditorKey.currentState;
    if (draft == null) {
      AppSnackBar.show(
        context,
        'Editor not ready',
        tone: AppSnackBarTone.error,
      );
      return;
    }

    final partialConfig = draft.buildPartialConfigParams();
    if (partialConfig.isEmpty) {
      _hideConfigDirtySnackBar();
      return;
    }

    final actions = ref.read(buildActionsProvider.notifier);
    _configSaveInFlight = true;
    final updated = await actions.updateBuildConfig(
      buildId: build.id,
      partialConfig: partialConfig,
    );
    _configSaveInFlight = false;

    if (updated != null) {
      ref
        ..invalidate(buildDetailProvider(build.id))
        ..invalidate(buildsProvider);

      _configEditorKey.currentState?.resetTo(updated.config);
      _hideConfigDirtySnackBar();
    }

    if (!mounted) return;

    if (updated == null) {
      final err = ref.read(buildActionsProvider).asError?.error;
      AppSnackBar.show(
        context,
        err != null ? 'Failed: $err' : 'Failed to update build',
        tone: AppSnackBarTone.error,
      );

      // AppSnackBar replaces the current snackbar; re-show the persistent
      // Save/Discard bar if we are still dirty.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final stillDirty =
            _configEditorKey.currentState
                ?.buildPartialConfigParams()
                .isNotEmpty ??
            false;
        if (stillDirty) _showConfigDirtySnackBar(build);
      });

      return;
    }

    AppSnackBar.show(context, 'Build updated', tone: AppSnackBarTone.success);
  }
}

// Hero Panel
