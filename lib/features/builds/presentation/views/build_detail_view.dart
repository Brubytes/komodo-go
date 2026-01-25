import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
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

class _BuildDetailViewState extends ConsumerState<BuildDetailView>
    with
        SingleTickerProviderStateMixin,
        DetailDirtySnackBarMixin<BuildDetailView> {
  late final TabController _tabController;
  final _configEditorKey = GlobalKey<BuildConfigEditorContentState>();
  var _configSaveInFlight = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: buildAsync.when(
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
                          data: (name) =>
                              (name != null && name.trim().isNotEmpty)
                              ? name.trim()
                              : (builderId.isNotEmpty ? builderId : null),
                          loading: () => 'Loading…',
                          error: (_, __) =>
                              builderId.isNotEmpty ? builderId : null,
                        );

                        return BuildHeroPanel(
                          buildResource: build,
                          listItem: listItem,
                          builderLabel: builderLabel,
                        );
                      },
                      loading: () => const BuildLoadingSurface(),
                      error: (error, _) =>
                          BuildErrorSurface(error: error.toString()),
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedTabBarHeaderDelegate(
                    backgroundColor: scheme.surface,
                    tabBar: buildDetailTabBar(
                      context: context,
                      controller: _tabController,
                      tabs: const [
                        Tab(
                          icon: Icon(AppIcons.bolt),
                          text: 'Config',
                        ),
                        Tab(
                          icon: Icon(AppIcons.logs),
                          text: 'Logs',
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _KeepAlive(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(buildDetailProvider(buildId));
                    },
                    child: ListView(
                      key: PageStorageKey('build_${widget.buildId}_config'),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        buildAsync.when(
                          data: (build) {
                            if (build == null) {
                              return const BuildMessageSurface(
                                message: 'Build not found',
                              );
                            }

                            final builders =
                                buildersAsync.asData?.value ?? const [];
                            final repos = reposAsync.asData?.value ?? const [];

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                BuildConfigEditorContent(
                                  key: _configEditorKey,
                                  initialConfig: build.config,
                                  builders: builders,
                                  repos: repos,
                                  onDirtyChanged: (dirty) {
                                    syncDirtySnackBar(
                                      dirty: dirty,
                                      onDiscard: () => _discardConfig(build),
                                      onSave: () => _saveConfig(build: build),
                                    );
                                  },
                                ),
                                if (build.info.latestHash != null ||
                                    build.info.builtHash != null) ...[
                                  const Gap(16),
                                  DetailSection(
                                    title: 'Commit Hashes',
                                    icon: AppIcons.tag,
                                    child: BuildHashesContent(
                                      buildResource: build,
                                    ),
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
                ),
                _KeepAlive(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(buildDetailProvider(buildId));
                    },
                    child: ListView(
                      key: PageStorageKey('build_${widget.buildId}_logs'),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        buildAsync.when(
                          data: (build) {
                            if (build == null) {
                              return const BuildMessageSurface(
                                message: 'Build not found',
                              );
                            }

                            final hasAnyLogs =
                                (build.info.remoteError != null &&
                                    build.info.remoteError!
                                        .trim()
                                        .isNotEmpty) ||
                                (build.info.remoteContents != null &&
                                    build.info.remoteContents!
                                        .trim()
                                        .isNotEmpty) ||
                                (build.info.builtContents != null &&
                                    build.info.builtContents!
                                        .trim()
                                        .isNotEmpty);

                            if (!hasAnyLogs) {
                              return const BuildMessageSurface(
                                message: 'No log output',
                              );
                            }

                            return BuildLogsContent(buildResource: build);
                          },
                          loading: () => const BuildLoadingSurface(),
                          error: (error, _) =>
                              BuildErrorSurface(error: error.toString()),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (actionsState.isLoading)
            ColoredBox(
              color: scheme.scrim.withValues(alpha: 0.25),
              child: const Center(child: AppSkeletonCard()),
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

  void _discardConfig(KomodoBuild build) {
    _configEditorKey.currentState?.resetTo(build.config);
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

class _PinnedTabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  _PinnedTabBarHeaderDelegate({
    required this.tabBar,
    required this.backgroundColor,
  });

  final TabBar tabBar;
  final Color backgroundColor;

  @override
  double get minExtent => tabBar.preferredSize.height + 1;

  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Align(alignment: Alignment.centerLeft, child: tabBar),
    );
  }

  @override
  bool shouldRebuild(_PinnedTabBarHeaderDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar ||
      backgroundColor != oldDelegate.backgroundColor;
}

class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin<_KeepAlive> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}

// Hero Panel
