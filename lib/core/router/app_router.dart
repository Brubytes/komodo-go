import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/alerters/alerter_detail_view.dart';
import 'package:komodo_go/composition/builds/build_detail_view.dart';
import 'package:komodo_go/composition/containers/containers_provider.dart';
import 'package:komodo_go/composition/containers/containers_view.dart';
import 'package:komodo_go/composition/deployments/deployment_detail_view.dart';
import 'package:komodo_go/composition/deployments/deployments_list_view.dart';
import 'package:komodo_go/composition/home/home_view.dart';
import 'package:komodo_go/composition/repos/repo_detail_view.dart';
import 'package:komodo_go/composition/resources/advanced_resource_detail_views.dart';
import 'package:komodo_go/composition/resources/resource_creation_view.dart';
import 'package:komodo_go/composition/resources/resource_name_resolver_provider.dart';
import 'package:komodo_go/composition/resources/resources_view.dart';
import 'package:komodo_go/composition/servers/servers_list_view.dart';
import 'package:komodo_go/composition/settings/auto_update_review_view.dart';
import 'package:komodo_go/composition/settings/connections_view.dart';
import 'package:komodo_go/composition/settings/settings_view.dart';
import 'package:komodo_go/composition/stacks/stack_detail_view.dart';
import 'package:komodo_go/composition/stacks/stacks_list_view.dart';
import 'package:komodo_go/composition/syncs/sync_detail_view.dart';
import 'package:komodo_go/core/platform/vertical_bar_info.dart';
import 'package:komodo_go/core/router/route_observer.dart';
import 'package:komodo_go/core/router/shell_state_provider.dart';
import 'package:komodo_go/core/router/split_aware_page.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/breakpoints.dart';
import 'package:komodo_go/core/widgets/adaptive_bottom_navigation_bar.dart';
import 'package:komodo_go/core/widgets/adaptive_navigation_rail.dart';
import 'package:komodo_go/core/widgets/layout/list_detail_layout.dart';
import 'package:komodo_go/features/actions/presentation/views/actions_list_view.dart';
import 'package:komodo_go/features/alerters/presentation/views/alerters_view.dart';
import 'package:komodo_go/features/auth/data/models/auth_state.dart';
import 'package:komodo_go/features/auth/presentation/providers/auth_provider.dart';
import 'package:komodo_go/features/auth/presentation/views/auth_loading_view.dart';
import 'package:komodo_go/features/auth/presentation/views/login_view.dart';
import 'package:komodo_go/features/builders/presentation/views/builders_view.dart';
import 'package:komodo_go/features/builds/presentation/views/builds_list_view.dart';
import 'package:komodo_go/features/containers/presentation/views/container_detail_view.dart';
import 'package:komodo_go/features/notifications/presentation/providers/alerts_provider.dart';
import 'package:komodo_go/features/notifications/presentation/providers/notifications_tab_provider.dart';
import 'package:komodo_go/features/notifications/presentation/views/alert_detail_view.dart';
import 'package:komodo_go/features/notifications/presentation/views/notifications_view.dart';
import 'package:komodo_go/features/notifications/presentation/views/update_detail_view.dart';
import 'package:komodo_go/features/procedures/presentation/views/procedures_list_view.dart';
import 'package:komodo_go/features/providers/presentation/views/providers_view.dart';
import 'package:komodo_go/features/repos/presentation/views/repos_list_view.dart';
import 'package:komodo_go/features/settings/presentation/views/credits_view.dart';
import 'package:komodo_go/features/syncs/presentation/views/syncs_list_view.dart';
import 'package:komodo_go/features/tags/presentation/views/tags_view.dart';
import 'package:komodo_go/features/variables/presentation/views/variables_view.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/providers/resource_name_resolver_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

Page<void> _noTransitionTabPage(Widget child) =>
    NoTransitionPage<void>(child: child);

Page<void> _appStackPage(
  GoRouterState state,
  Widget child, {
  double splitMinWidth = kListDetailSplitMinWidth,
}) => SplitAwarePage(
  key: state.pageKey,
  splitMinWidth: splitMinWidth,
  child: child,
);

/// Stack page showing [detail] next to [list] on wide windows and alone on
/// narrow ones. [list] is the same list the list route shows, with the open
/// item selected.
Page<void> _splitPage(
  GoRouterState state, {
  required Widget list,
  required Widget detail,
  required IconData icon,
  required String label,
  double splitMinWidth = kListDetailSplitMinWidth,
  double? fixedListWidth,
  double? singlePaneMaxWidth,
}) {
  final layout = ListDetailLayout(
    list: list,
    detail: detail,
    placeholder: ListDetailPlaceholder(icon: icon, label: label),
    splitMinWidth: splitMinWidth,
    minListWidth: fixedListWidth ?? 320,
    maxListWidth: fixedListWidth ?? 420,
    singlePaneMaxWidth: singlePaneMaxWidth,
  );
  return _appStackPage(state, layout, splitMinWidth: splitMinWidth);
}

/// Settings split only on tablet-landscape widths; below that the index is a
/// single readable column, like on phones.
const double _settingsSplitMinWidth = 960;
const double _settingsListWidth = 380;
const double _settingsColumnMaxWidth = 720;

/// Resolves resource names through the composed resolver, which knows every
/// feature's resources.
Widget _withComposedNames(Widget child) => ProviderScope(
  overrides: [
    resourceNameResolverProvider.overrideWith(
      (ref) => ref.watch(composedResourceNameResolverProvider),
    ),
  ],
  child: child,
);

/// `/resources/<path>` list route with its `new` and `:id` children, all
/// rendered as list/detail layouts.
GoRoute _resourceRoute({
  required String path,
  required IconData icon,
  required String noun,
  required String fallbackName,
  required Widget Function(String? selectedId) list,
  required Widget Function(String id, String name) detail,
  ResourceKind? createKind,
}) {
  final label = 'Select a $noun';
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => _appStackPage(
      state,
      ListDetailLayout(
        list: list(null),
        placeholder: ListDetailPlaceholder(icon: icon, label: label),
      ),
    ),
    routes: [
      if (createKind != null)
        GoRoute(
          path: 'new',
          pageBuilder: (context, state) => _splitPage(
            state,
            list: list(null),
            detail: ResourceCreationView(kind: createKind),
            icon: icon,
            label: label,
          ),
        ),
      GoRoute(
        path: ':id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          final name = state.uri.queryParameters['name'] ?? fallbackName;
          return _splitPage(
            state,
            list: list(id),
            detail: detail(id, name),
            icon: icon,
            label: label,
          );
        },
      ),
    ],
  );
}

/// `/settings/<path>` page: the settings index with the page beside it on
/// wide windows.
GoRoute _settingsRoute({
  required String path,
  required String location,
  required Widget page,
  List<RouteBase> routes = const [],
}) => GoRoute(
  path: path,
  pageBuilder: (context, state) => _splitPage(
    state,
    list: SettingsView(activeRoute: location),
    detail: page,
    icon: AppIcons.settings,
    label: 'Select a setting',
    splitMinWidth: _settingsSplitMinWidth,
    fixedListWidth: _settingsListWidth,
    singlePaneMaxWidth: _settingsColumnMaxWidth,
  ),
  routes: routes,
);

/// Route paths
abstract class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const home = '/';
  static const resources = '/resources';
  static const containers = '/containers';
  static const containerDetail = '/containers/:serverId/:container';
  static const notifications = '/notifications';
  static const updateDetails = '$notifications/updates';
  static const alertDetails = '$notifications/alerts';
  static const settings = '/settings';

  static const servers = '$resources/servers';
  static const serverDetail = '$servers/:id';
  static const deployments = '$resources/deployments';
  static const stacks = '$resources/stacks';
  static const repos = '$resources/repos';
  static const syncs = '$resources/syncs';
  static const builds = '$resources/builds';
  static const procedures = '$resources/procedures';
  static const actions = '$resources/actions';

  static const connections = '$settings/connections';
  static const komodoVariables = '$settings/komodo/variables';
  static const komodoTags = '$settings/komodo/tags';
  static const komodoProviders = '$settings/komodo/providers';
  static const komodoBuilders = '$settings/komodo/builders';
  static const komodoAlerters = '$settings/komodo/alerters';
  static const autoUpdateReview = '$settings/komodo/auto-updates';
  static const komodoAlerterDetail = '$komodoAlerters/:id';
  static const credits = '$settings/credits';
}

/// Decides where to send the user based on the current auth state.
///
/// Exposed as a top-level function so the redirect policy is unit-testable.
String? authRedirect({
  required AsyncValue<AuthState> authState,
  required String matchedLocation,
}) {
  final isOnSplash = matchedLocation == AppRoutes.splash;
  final isOnLogin = matchedLocation == AppRoutes.login;

  // Gate on the splash screen only while no auth state exists yet (initial
  // restore, explicit login/logout). During refreshes — e.g. a connection was
  // renamed — the previous value is retained and navigation stays untouched.
  if (authState.isLoading && !authState.hasValue) {
    return isOnSplash ? null : AppRoutes.splash;
  }

  final isAuthenticated = authState.value?.isAuthenticated ?? false;

  // If not authenticated and not on login page, redirect to login
  if (!isAuthenticated) {
    return isOnLogin ? null : AppRoutes.login;
  }

  // If authenticated and on auth pages, redirect to home
  if (isOnLogin || isOnSplash) {
    return AppRoutes.home;
  }

  return null;
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  // Recreating the router would reset the entire navigation stack, so it is
  // created exactly once; auth changes only re-run `redirect` via
  // refreshListenable.
  final authListenable = ValueNotifier(ref.read(authProvider));
  ref
    ..listen(authProvider, (_, next) => authListenable.value = next)
    ..onDispose(authListenable.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: kDebugMode,
    observers: [appRouteObserver],
    refreshListenable: authListenable,
    redirect: (context, state) => authRedirect(
      authState: authListenable.value,
      matchedLocation: state.matchedLocation,
    ),
    routes: [
      // Startup splash while auth state is being restored/validated
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) =>
            const VerticalBarSafeArea(child: AuthLoadingView()),
      ),

      // Login
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) =>
            const VerticalBarSafeArea(child: LoginView()),
      ),

      // Bottom navigation with stateful branch navigators.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            observers: [appShellBranchObservers[0]],
            routes: [
              GoRoute(
                path: AppRoutes.home,
                pageBuilder: (context, state) =>
                    _noTransitionTabPage(const HomeView()),
              ),
            ],
          ),
          StatefulShellBranch(
            observers: [appShellBranchObservers[1]],
            routes: [
              GoRoute(
                path: AppRoutes.resources,
                pageBuilder: (context, state) =>
                    _noTransitionTabPage(const ResourcesView()),
                routes: [
                  _resourceRoute(
                    path: 'servers',
                    icon: AppIcons.server,
                    noun: 'server',
                    fallbackName: 'Server',
                    createKind: ResourceKind.servers,
                    list: (selectedId) =>
                        ServersListView(selectedId: selectedId),
                    detail: (id, name) => AdvancedServerDetailView(
                      serverId: id,
                      serverName: name,
                    ),
                  ),
                  _resourceRoute(
                    path: 'deployments',
                    icon: AppIcons.deployments,
                    noun: 'deployment',
                    fallbackName: 'Deployment',
                    createKind: ResourceKind.deployments,
                    list: (selectedId) =>
                        DeploymentsListView(selectedId: selectedId),
                    detail: (id, name) => DeploymentDetailView(
                      deploymentId: id,
                      deploymentName: name,
                    ),
                  ),
                  _resourceRoute(
                    path: 'stacks',
                    icon: AppIcons.stacks,
                    noun: 'stack',
                    fallbackName: 'Stack',
                    createKind: ResourceKind.stacks,
                    list: (selectedId) =>
                        StacksListView(selectedId: selectedId),
                    detail: (id, name) =>
                        StackDetailView(stackId: id, stackName: name),
                  ),
                  _resourceRoute(
                    path: 'repos',
                    icon: AppIcons.repos,
                    noun: 'repo',
                    fallbackName: 'Repo',
                    list: (selectedId) => ReposListView(selectedId: selectedId),
                    detail: (id, name) =>
                        RepoDetailView(repoId: id, repoName: name),
                  ),
                  _resourceRoute(
                    path: 'syncs',
                    icon: AppIcons.syncs,
                    noun: 'sync',
                    fallbackName: 'Sync',
                    list: (selectedId) => SyncsListView(selectedId: selectedId),
                    detail: (id, name) =>
                        SyncDetailView(syncId: id, syncName: name),
                  ),
                  _resourceRoute(
                    path: 'builds',
                    icon: AppIcons.builds,
                    noun: 'build',
                    fallbackName: 'Build',
                    list: (selectedId) =>
                        BuildsListView(selectedId: selectedId),
                    detail: (id, name) =>
                        BuildDetailView(buildId: id, buildName: name),
                  ),
                  _resourceRoute(
                    path: 'procedures',
                    icon: AppIcons.procedures,
                    noun: 'procedure',
                    fallbackName: 'Procedure',
                    createKind: ResourceKind.procedures,
                    list: (selectedId) =>
                        ProceduresListView(selectedId: selectedId),
                    detail: (id, name) => AdvancedProcedureDetailView(
                      procedureId: id,
                      procedureName: name,
                    ),
                  ),
                  _resourceRoute(
                    path: 'actions',
                    icon: AppIcons.actions,
                    noun: 'action',
                    fallbackName: 'Action',
                    createKind: ResourceKind.actions,
                    list: (selectedId) =>
                        ActionsListView(selectedId: selectedId),
                    detail: (id, name) => AdvancedActionDetailView(
                      actionId: id,
                      actionName: name,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            observers: [appShellBranchObservers[2]],
            routes: [
              GoRoute(
                path: AppRoutes.containers,
                pageBuilder: (context, state) => _noTransitionTabPage(
                  const ListDetailLayout(
                    list: ContainersView(),
                    placeholder: ListDetailPlaceholder(
                      icon: AppIcons.containers,
                      label: 'Select a container',
                    ),
                  ),
                ),
                routes: [
                  GoRoute(
                    path: ':serverId/:container',
                    pageBuilder: (context, state) {
                      final serverId = state.pathParameters['serverId']!;
                      final container = state.pathParameters['container']!;
                      return _splitPage(
                        state,
                        list: ContainersView(
                          selectedId: '$serverId/$container',
                        ),
                        detail: ContainerDetailView(
                          serverId: serverId,
                          containerIdOrName: container,
                          initialItem: state.extra is ContainerOverviewItem
                              ? state.extra! as ContainerOverviewItem
                              : null,
                        ),
                        icon: AppIcons.containers,
                        label: 'Select a container',
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            observers: [appShellBranchObservers[3]],
            routes: [
              GoRoute(
                path: AppRoutes.notifications,
                pageBuilder: (context, state) => _noTransitionTabPage(
                  _withComposedNames(const NotificationsPane()),
                ),
                routes: [
                  GoRoute(
                    path: 'updates/:id',
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return _appStackPage(
                        state,
                        _withComposedNames(NotificationsPane(updateId: id)),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'alerts/:id',
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return _appStackPage(
                        state,
                        _withComposedNames(NotificationsPane(alertId: id)),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            observers: [appShellBranchObservers[4]],
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                pageBuilder: (context, state) => _noTransitionTabPage(
                  const ListDetailLayout(
                    list: SettingsView(),
                    placeholder: ListDetailPlaceholder(
                      icon: AppIcons.settings,
                      label: 'Select a setting',
                    ),
                    splitMinWidth: _settingsSplitMinWidth,
                    minListWidth: _settingsListWidth,
                    maxListWidth: _settingsListWidth,
                    singlePaneMaxWidth: _settingsColumnMaxWidth,
                  ),
                ),
                routes: [
                  _settingsRoute(
                    path: 'connections',
                    location: AppRoutes.connections,
                    page: const ConnectionsView(),
                  ),
                  _settingsRoute(
                    path: 'komodo/auto-updates',
                    location: AppRoutes.autoUpdateReview,
                    page: const AutoUpdateReviewView(),
                  ),
                  _settingsRoute(
                    path: 'komodo/variables',
                    location: AppRoutes.komodoVariables,
                    page: const VariablesView(),
                  ),
                  _settingsRoute(
                    path: 'komodo/tags',
                    location: AppRoutes.komodoTags,
                    page: const TagsView(),
                  ),
                  _settingsRoute(
                    path: 'komodo/providers',
                    location: AppRoutes.komodoProviders,
                    page: const ProvidersView(),
                  ),
                  _settingsRoute(
                    path: 'komodo/builders',
                    location: AppRoutes.komodoBuilders,
                    page: const BuildersView(),
                  ),
                  _settingsRoute(
                    path: 'komodo/alerters',
                    location: AppRoutes.komodoAlerters,
                    page: const AlertersView(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        pageBuilder: (context, state) {
                          final id = state.pathParameters['id']!;
                          return _splitPage(
                            state,
                            list: AlertersView(selectedId: id),
                            detail: AlerterDetailView(alerterIdOrName: id),
                            icon: AppIcons.notifications,
                            label: 'Select an alerter',
                          );
                        },
                      ),
                    ],
                  ),
                  _settingsRoute(
                    path: 'credits',
                    location: AppRoutes.credits,
                    page: const CreditsView(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Notifications: alerts and updates share one list/detail split. The
/// placeholder follows the active tab.
class NotificationsPane extends StatelessWidget {
  const NotificationsPane({this.updateId, this.alertId, super.key});

  final String? updateId;
  final String? alertId;

  @override
  Widget build(BuildContext context) {
    return ListDetailLayout(
      list: NotificationsView(
        selectedUpdateId: updateId,
        selectedAlertId: alertId,
      ),
      detail: updateId != null
          ? UpdateDetailView(updateId: updateId!)
          : alertId != null
          ? AlertDetailView(alertId: alertId!)
          : null,
      placeholder: const _NotificationsPlaceholder(),
    );
  }
}

class _NotificationsPlaceholder extends ConsumerWidget {
  const _NotificationsPlaceholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onUpdates = ref.watch(notificationsTabIndexProvider) == 1;
    return ListDetailPlaceholder(
      icon: AppIcons.notifications,
      label: onUpdates ? 'Select an update' : 'Select an alert',
    );
  }
}

/// Main shell: bottom navigation on compact windows, a left navigation rail
/// on wider ones.
///
/// The window resizes live on fold/unfold and in Split View, so the layout is
/// derived from the current constraints on every build. The
/// [navigationShell] is held under a [GlobalKey] so switching between bar and
/// rail reparents it instead of rebuilding (and resetting) every branch.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final GlobalKey _shellKey = GlobalKey(debugLabel: 'mainShellContent');

  StatefulNavigationShell get _shell => widget.navigationShell;

  @override
  Widget build(BuildContext context) {
    final currentIndex = _shell.currentIndex;
    final storedIndex = ref.watch(mainShellIndexProvider);
    if (storedIndex != currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(mainShellIndexProvider.notifier).index = currentIndex;
      });
    }

    // Reuses the alerts the dashboard already loads; no extra polling.
    final unresolvedAlerts = ref.watch(
      alertsProvider.select(
        (alerts) =>
            alerts.asData?.value.items.where((a) => !a.resolved).length ?? 0,
      ),
    );

    final items = [
      const AdaptiveNavigationItem(
        key: ValueKey('bottom_nav_home'),
        icon: Icon(AppIcons.home),
        activeIcon: Icon(AppIcons.home),
        label: 'Home',
      ),
      const AdaptiveNavigationItem(
        key: ValueKey('bottom_nav_resources'),
        icon: Icon(AppIcons.resources),
        activeIcon: Icon(AppIcons.resources),
        label: 'Resources',
      ),
      const AdaptiveNavigationItem(
        key: ValueKey('bottom_nav_containers'),
        icon: Icon(AppIcons.containers),
        activeIcon: Icon(AppIcons.containers),
        label: 'Containers',
      ),
      AdaptiveNavigationItem(
        key: const ValueKey('bottom_nav_notifications'),
        icon: const Icon(AppIcons.notifications),
        activeIcon: const Icon(AppIcons.notificationsActive),
        label: 'Notifications',
        badgeCount: unresolvedAlerts,
      ),
      const AdaptiveNavigationItem(
        key: ValueKey('bottom_nav_settings'),
        icon: Icon(AppIcons.settings),
        activeIcon: Icon(AppIcons.settings),
        label: 'Settings',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // The system may reserve a vertical bar strip (foldable iPhone inner
        // display). The app root leaves that inset to us: with a rail it is
        // the rail's home, otherwise it is padded here.
        final media = MediaQuery.of(context);
        final strip = verticalBarSides(context);
        final stripOnRight = strip.right;
        final stripInset = stripOnRight
            ? media.padding.right
            : media.padding.left;
        // With a strip the navigation always lives in it (any width class);
        // the bottom bar is only for windows without one.
        final railInStrip = (strip.left || strip.right) && stripInset > 0;
        final useRail =
            railInStrip || !WindowSizeClass.fromWidth(width).isCompact;
        final info = VerticalBarScope.maybeOf(context);
        final stripTopGap = railInStrip
            ? ((info?.occludedBottomInStrip(
                            windowWidth: media.size.width,
                            stripWidth: stripInset,
                            onRight: stripOnRight,
                          ) ??
                          0) +
                      8)
                  .clamp(media.padding.top + 8, double.infinity)
            : 0.0;

        // The strip is the rail's; screens must not pad for it again.
        final content = MediaQuery.removePadding(
          context: context,
          removeLeft: railInStrip && !stripOnRight,
          removeRight: railInStrip && stripOnRight,
          child: KeyedSubtree(key: _shellKey, child: _shell),
        );

        Widget rail({double? stripWidth}) => AdaptiveNavigationRail(
          selectedIndex: currentIndex,
          onTap: _onItemTapped,
          items: items,
          extended: stripWidth == null && width >= kExtendedRailMinWidth,
          stripWidth: stripWidth,
          stripTopGap: stripTopGap,
          stripOnRight: stripOnRight,
        );

        return SafeArea(
          top: false,
          bottom: false,
          left: strip.left && !railInStrip,
          right: strip.right && !railInStrip,
          child: Scaffold(
            body: useRail
                ? Row(
                    children: [
                      if (!railInStrip) rail(),
                      if (railInStrip && !stripOnRight)
                        rail(stripWidth: stripInset),
                      Expanded(child: content),
                      if (railInStrip && stripOnRight)
                        rail(stripWidth: stripInset),
                    ],
                  )
                : content,
            bottomNavigationBar: useRail
                ? null
                : AdaptiveBottomNavigationBar(
                    selectedIndex: currentIndex,
                    onTap: _onItemTapped,
                    items: items,
                  ),
          ),
        );
      },
    );
  }

  void _onItemTapped(int index) {
    _shell.goBranch(index, initialLocation: index == _shell.currentIndex);
    ref.read(mainShellIndexProvider.notifier).index = index;
  }
}
