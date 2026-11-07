import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/builds/build_detail_sections.dart';
import 'package:komodo_go/composition/resources/resource_manage_actions.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/router/resource_routes.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/async/action_busy_overlay.dart';
import 'package:komodo_go/core/widgets/async/async_content.dart';
import 'package:komodo_go/core/widgets/async/detail_skeletons.dart';
import 'package:komodo_go/core/widgets/async/editor_host.dart';
import 'package:komodo_go/core/widgets/async/refresh_helpers.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/dialogs/confirm_destructive_dialog.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/builders/presentation/providers/builders_provider.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/builds/presentation/providers/builds_provider.dart';
import 'package:komodo_go/features/builds/presentation/widgets/build_card.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_metadata.dart';

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

class _BuildDetailViewState extends ConsumerState<BuildDetailView>
    with DetailDirtySnackBarMixin<BuildDetailView> {
  final _configEditorKey = GlobalKey<BuildConfigEditorContentState>();
  var _configSaveInFlight = false;
  var _dirty = false;

  /// A pull-to-refresh is running; its spinner replaces the thin progress bars.
  var _pulling = false;

  void _setDirty(bool dirty) {
    if (_dirty == dirty) return;
    _dirty = dirty;
    // Lets the config EditorHost adopt data it held back while dirty.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _retry() => ref.invalidate(buildDetailProvider(widget.buildId));

  Future<void> _pullAll() async {
    setState(() => _pulling = true);
    try {
      await refreshProviders(ref, [
        buildDetailProvider(widget.buildId).future,
        buildsProvider.future,
      ]);
    } finally {
      if (mounted) setState(() => _pulling = false);
    }
  }

  void _onDirtyChanged(bool dirty, KomodoBuild build) {
    _setDirty(dirty);
    syncDirtySnackBar(
      dirty: dirty,
      onDiscard: () => _discardConfig(build),
      onSave: () => _saveConfig(build: build),
      saving: _configSaveInFlight,
    );
  }

  Future<void> _confirmAndCancel(String buildId) async {
    final ok = await confirmDestructive(
      context,
      title: 'Cancel build?',
      message: 'The running build will be cancelled.',
      confirmLabel: 'Cancel build',
    );
    if (!ok || !mounted) return;
    await _handleAction(buildId, BuildAction.cancel);
  }

  @override
  Widget build(BuildContext context) {
    final buildId = widget.buildId;
    final buildAsync = ref.watch(buildDetailProvider(buildId));
    final buildsListAsync = ref.watch(buildsProvider);
    final actionsState = ref.watch(buildActionsProvider);
    final buildersAsync = ref.watch(buildersProvider);
    final reposAsync = ref.watch(reposProvider);
    final build = buildAsync.value;
    final builderId = build?.config.builderId ?? '';
    final builderNameAsync = builderId.isEmpty
        ? const AsyncValue<String?>.data(null)
        : ref.watch(builderNameProvider(builderId));
    // Falls back to the id while the name is unknown, never to a loading text.
    final builderName = builderNameAsync.value?.trim() ?? '';
    final builderLabel = builderName.isNotEmpty
        ? builderName
        : (builderId.isNotEmpty ? builderId : null);
    BuildListItem? listItem;
    final list = buildsListAsync.value;
    if (list != null) {
      for (final item in list) {
        if (item.id == buildId) {
          listItem = item;
          break;
        }
      }
    }
    final isBuilding = listItem?.info.state == BuildState.building;

    return UnsavedChangesGuard(
      dirty: _dirty,
      onDiscarded: hideDirtySnackBar,
      child: Scaffold(
        appBar: MainAppBar(
          title: widget.buildName,
          icon: AppIcons.builds,
          markColor: AppTokens.resourceBuilds,
          markUseGradient: true,
          centerTitle: true,
          status: buildAppBarStatus(listItem: listItem, build: build),
        ),
        body: Stack(
          children: [
            DetailTabScaffold(
              headerSlivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AsyncContent<KomodoBuild?>(
                          value: buildAsync,
                          errorTitle: 'Failed to load build',
                          onRetry: _retry,
                          showProgress: !_pulling,
                          bannerPadding: const EdgeInsets.only(
                            bottom: AppSpacing.sm,
                          ),
                          skeletonBuilder: (_) => const DetailHeaderSkeleton(
                            facts: 2,
                            showActions: false,
                          ),
                          builder: (context, build) {
                            if (build == null) {
                              return const BuildMessageSurface(
                                message: 'Build not found',
                              );
                            }

                            final linkedRepo = build.config.linkedRepo.trim();
                            return BuildHeader(
                              buildResource: build,
                              listItem: listItem,
                              builderLabel: builderLabel,
                              onBuilderTap: builderId.isEmpty
                                  ? null
                                  : () => context.push(
                                      AppRoutes.komodoBuilders,
                                    ),
                              onRepoTap: linkedRepo.isEmpty
                                  ? null
                                  : () => context.push(
                                      resourceDetailRoute(
                                        AppRoutes.repos,
                                        linkedRepo,
                                      ),
                                    ),
                              onRunBuild: isBuilding
                                  ? null
                                  : () => _handleAction(
                                      buildId,
                                      BuildAction.run,
                                    ),
                            );
                          },
                        ),
                        const Gap(AppSpacing.md),
                        DetailActionBar(
                          primary: isBuilding
                              ? DetailActionButton(
                                  label: 'Cancel build',
                                  icon: AppIcons.stop,
                                  onPressed: () => _confirmAndCancel(buildId),
                                )
                              : DetailActionButton(
                                  label: 'Run build',
                                  icon: AppIcons.play,
                                  onPressed: () =>
                                      _handleAction(buildId, BuildAction.run),
                                ),
                          moreGroups: [
                            if (build != null)
                              buildResourceManageGroup(
                                context: context,
                                ref: ref,
                                metadata: ResourceMetadata(
                                  kind: ResourceKind.builds,
                                  id: build.id,
                                  name: build.name,
                                  description: build.description,
                                  template: build.template,
                                  tags: build.tags,
                                ),
                                onMutated: () {
                                  ref
                                    ..invalidate(buildsProvider)
                                    ..invalidate(buildDetailProvider(buildId));
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              tabs: [
                DetailTabSpec(
                  id: 'config',
                  label: 'Config',
                  icon: AppIcons.bolt,
                  body: RefreshIndicator(
                    onRefresh: _pullAll,
                    child: DetailTabScrollView.box(
                      scrollKey: PageStorageKey(
                        'build_${widget.buildId}_config',
                      ),
                      // The header already shows this provider's progress and
                      // stale-error banner.
                      child: EditorHost<KomodoBuild>(
                        value: buildAsync,
                        isDirty: () => _dirty,
                        errorTitle: 'Failed to load build',
                        onRetry: _retry,
                        showProgress: false,
                        showStaleBanner: false,
                        skeletonBuilder: (_) => const DetailTabSkeleton(),
                        emptyBuilder: (_) => const BuildMessageSurface(
                          message: 'Build not found',
                        ),
                        builder: (context, build) {
                          final builders = buildersAsync.value ?? const [];
                          final repos = reposAsync.value ?? const [];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              BuildConfigEditorContent(
                                key: _configEditorKey,
                                initialConfig: build.config,
                                builders: builders,
                                repos: repos,
                                onDirtyChanged: (dirty) =>
                                    _onDirtyChanged(dirty, build),
                              ),
                              AppExpand(
                                expanded:
                                    build.info.latestHash != null ||
                                    build.info.builtHash != null,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSpacing.md,
                                  ),
                                  child: BuildHashesContent(
                                    buildResource: build,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                DetailTabSpec(
                  id: 'logs',
                  label: 'Logs',
                  icon: AppIcons.logs,
                  body: RefreshIndicator(
                    onRefresh: _pullAll,
                    child: DetailTabScrollView.box(
                      scrollKey: PageStorageKey('build_${widget.buildId}_logs'),
                      maxContentWidth: 1100,
                      child: AsyncContent<KomodoBuild?>(
                        value: buildAsync,
                        errorTitle: 'Failed to load build',
                        onRetry: _retry,
                        showProgress: false,
                        showStaleBanner: false,
                        skeletonBuilder: (_) =>
                            const DetailTabSkeleton(count: 2),
                        builder: (context, build) {
                          if (build == null) {
                            return const BuildMessageSurface(
                              message: 'Build not found',
                            );
                          }

                          final hasAnyLogs =
                              (build.info.remoteError != null &&
                                  build.info.remoteError!.trim().isNotEmpty) ||
                              (build.info.remoteContents != null &&
                                  build.info.remoteContents!
                                      .trim()
                                      .isNotEmpty) ||
                              (build.info.builtContents != null &&
                                  build.info.builtContents!.trim().isNotEmpty);

                          if (!hasAnyLogs) {
                            return const BuildMessageSurface(
                              message: 'No log output',
                              icon: AppIcons.logs,
                            );
                          }

                          return BuildLogsContent(buildResource: build);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ActionBusyOverlay(busy: actionsState.isLoading),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(String buildId, BuildAction action) async {
    final actions = ref.read(buildActionsProvider.notifier);
    final success = await switch (action) {
      BuildAction.run => actions.run(buildId),
      BuildAction.cancel => actions.cancel(buildId),
    };

    if (!mounted) return;

    if (success) {
      ref.invalidate(buildDetailProvider(buildId));
    }

    if (!mounted) return;

    AppSnackBar.show(
      context,
      success
          ? 'Action submitted. Check updates for the result.'
          : 'Action failed. Please try again.',
      tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
    );
  }

  void _discardConfig(KomodoBuild build) {
    final latest = ref.read(buildDetailProvider(widget.buildId)).value ?? build;
    _configEditorKey.currentState?.resetTo(latest.config);
    hideDirtySnackBar();
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
      hideDirtySnackBar();
      return;
    }

    final actions = ref.read(buildActionsProvider.notifier);
    _configSaveInFlight = true;
    syncDirtySnackBar(
      dirty: true,
      onDiscard: () => _discardConfig(build),
      onSave: () => _saveConfig(build: build),
      saving: true,
    );
    final updated = await actions.updateBuildConfig(
      buildId: build.id,
      partialConfig: partialConfig,
    );
    _configSaveInFlight = false;

    if (!mounted) return;

    if (updated != null) {
      ref
        ..invalidate(buildDetailProvider(build.id))
        ..invalidate(buildsProvider);

      _configEditorKey.currentState?.resetTo(updated.config);
      _setDirty(false);
      hideDirtySnackBar();
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
      reShowDirtySnackBarIfStillDirty(
        isStillDirty: () {
          return _configEditorKey.currentState
                  ?.buildPartialConfigParams()
                  .isNotEmpty ??
              false;
        },
        onDiscard: () => _discardConfig(build),
        onSave: () => _saveConfig(build: build),
      );

      return;
    }

    AppSnackBar.show(context, 'Build updated', tone: AppSnackBarTone.success);
  }
}
