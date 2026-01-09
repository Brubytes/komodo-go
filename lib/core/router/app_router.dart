import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

import '../../features/auth/data/models/auth_state.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/views/auth_loading_view.dart';
import '../../features/auth/presentation/views/login_view.dart';
import '../../features/deployments/presentation/views/deployment_detail_view.dart';
import '../../features/deployments/presentation/views/deployments_list_view.dart';
import '../../features/home/presentation/views/home_view.dart';
import '../../features/builds/presentation/views/build_detail_view.dart';
import '../../features/builds/presentation/views/builds_list_view.dart';
import '../../features/actions/presentation/views/action_detail_view.dart';
import '../../features/actions/presentation/views/actions_list_view.dart';
import '../../features/syncs/presentation/views/sync_detail_view.dart';
import '../../features/syncs/presentation/views/syncs_list_view.dart';
import '../../features/containers/presentation/providers/containers_provider.dart';
import '../../features/containers/presentation/views/containers_view.dart';
import '../../features/containers/presentation/views/container_detail_view.dart';
import '../../features/notifications/presentation/views/notifications_view.dart';
import '../../features/resources/presentation/views/resources_view.dart';
import '../../features/repos/presentation/views/repo_detail_view.dart';
import '../../features/repos/presentation/views/repos_list_view.dart';
import '../../features/procedures/presentation/views/procedure_detail_view.dart';
import '../../features/procedures/presentation/views/procedures_list_view.dart';
import '../../features/servers/presentation/views/servers_list_view.dart';
import '../../features/servers/presentation/views/server_detail_view.dart';
import '../../features/stacks/presentation/views/stack_detail_view.dart';
import '../../features/stacks/presentation/views/stacks_list_view.dart';
import '../../features/settings/presentation/views/connections_view.dart';
import '../../features/settings/presentation/views/settings_view.dart';
import '../../features/builders/presentation/views/builders_view.dart';
import '../../features/alerters/presentation/views/alerters_view.dart';
import '../../features/tags/presentation/views/tags_view.dart';
import '../../features/variables/presentation/views/variables_view.dart';
import '../widgets/adaptive_bottom_navigation_bar.dart';

part 'app_router.g.dart';

Page<void> _noTransitionTabPage(Widget child) =>
    NoTransitionPage<void>(child: child);

Page<void> _adaptiveStackPage(BuildContext context, Widget child) {
  final platform = Theme.of(context).platform;
  final isCupertino =
      !kIsWeb &&
      (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS);

  return isCupertino
      ? CupertinoPage<void>(child: child)
      : MaterialPage<void>(child: child);
}

/// Route paths
abstract class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const home = '/';
  static const resources = '/resources';
  static const containers = '/containers';
  static const containerDetail = '/containers/:serverId/:container';
  static const notifications = '/notifications';
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
  static const komodoBuilders = '$settings/komodo/builders';
  static const komodoAlerters = '$settings/komodo/alerters';

  /// Legacy paths.
  static const legacyConnections = '/connections';
  static const legacyServers = '/servers';
  static const legacyDeployments = '/deployments';
  static const legacyStacks = '/stacks';
  static const legacyRepos = '/repos';
  static const legacySyncs = '/syncs';
  static const legacyBuilds = '/builds';
  static const legacyProcedures = '/procedures';
  static const legacyActions = '/actions';
}

String _withQuery(String location, Uri uri) {
  final query = uri.query;
  if (query.isEmpty) return location;
  return '$location?$query';
}

@riverpod
GoRouter appRouter(Ref ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isOnSplash = state.matchedLocation == AppRoutes.splash;
      final isOnLogin = state.matchedLocation == AppRoutes.login;
      final isAuthLoading = authState.isLoading;

      if (isAuthLoading) {
        return isOnSplash ? null : AppRoutes.splash;
      }

      final isAuthenticated = authState.value?.isAuthenticated ?? false;

      // If not authenticated and not on login page, redirect to login
      if (!isAuthenticated) {
        return isOnLogin ? null : AppRoutes.login;
      }

      // If authenticated and on auth pages, redirect to home
      if (isAuthenticated && (isOnLogin || isOnSplash)) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      // Startup splash while auth state is being restored/validated
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const AuthLoadingView(),
      ),

      // Login
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginView(),
      ),

      // Legacy redirects (pre-stateful-shell paths).
      GoRoute(
        path: AppRoutes.legacyConnections,
        redirect: (context, state) =>
            _withQuery(AppRoutes.connections, state.uri),
      ),
      GoRoute(
        path: AppRoutes.legacyServers,
        redirect: (context, state) => _withQuery(AppRoutes.servers, state.uri),
        routes: [
          GoRoute(
            path: ':id',
            redirect: (context, state) => _withQuery(
              '${AppRoutes.servers}/${state.pathParameters['id']!}',
              state.uri,
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.legacyDeployments,
        redirect: (context, state) =>
            _withQuery(AppRoutes.deployments, state.uri),
      ),
      GoRoute(
        path: AppRoutes.legacyStacks,
        redirect: (context, state) => _withQuery(AppRoutes.stacks, state.uri),
        routes: [
          GoRoute(
            path: ':id',
            redirect: (context, state) => _withQuery(
              '${AppRoutes.stacks}/${state.pathParameters['id']!}',
              state.uri,
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.legacyRepos,
        redirect: (context, state) => _withQuery(AppRoutes.repos, state.uri),
        routes: [
          GoRoute(
            path: ':id',
            redirect: (context, state) => _withQuery(
              '${AppRoutes.repos}/${state.pathParameters['id']!}',
              state.uri,
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.legacySyncs,
        redirect: (context, state) => _withQuery(AppRoutes.syncs, state.uri),
        routes: [
          GoRoute(
            path: ':id',
            redirect: (context, state) => _withQuery(
              '${AppRoutes.syncs}/${state.pathParameters['id']!}',
              state.uri,
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.legacyBuilds,
        redirect: (context, state) => _withQuery(AppRoutes.builds, state.uri),
        routes: [
          GoRoute(
            path: ':id',
            redirect: (context, state) => _withQuery(
              '${AppRoutes.builds}/${state.pathParameters['id']!}',
              state.uri,
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.legacyProcedures,
        redirect: (context, state) =>
            _withQuery(AppRoutes.procedures, state.uri),
        routes: [
          GoRoute(
            path: ':id',
            redirect: (context, state) => _withQuery(
              '${AppRoutes.procedures}/${state.pathParameters['id']!}',
              state.uri,
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.legacyActions,
        redirect: (context, state) => _withQuery(AppRoutes.actions, state.uri),
        routes: [
          GoRoute(
            path: ':id',
            redirect: (context, state) => _withQuery(
              '${AppRoutes.actions}/${state.pathParameters['id']!}',
              state.uri,
            ),
          ),
        ],
      ),

      // Bottom navigation with stateful branch navigators.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                pageBuilder: (context, state) =>
                    _noTransitionTabPage(const HomeView()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.resources,
                pageBuilder: (context, state) =>
                    _noTransitionTabPage(const ResourcesView()),
                routes: [
                  GoRoute(
                    path: 'servers',
                    pageBuilder: (context, state) =>
                        _adaptiveStackPage(context, const ServersListView()),
                    routes: [
                      GoRoute(
                        path: ':id',
                        pageBuilder: (context, state) {
                          final id = state.pathParameters['id']!;
                          final name =
                              state.uri.queryParameters['name'] ?? 'Server';
                          return _adaptiveStackPage(
                            context,
                            ServerDetailView(serverId: id, serverName: name),
                          );
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'deployments',
                    pageBuilder: (context, state) => _adaptiveStackPage(
                      context,
                      const DeploymentsListView(),
                    ),
                    routes: [
                      GoRoute(
                        path: ':id',
                        pageBuilder: (context, state) {
                          final id = state.pathParameters['id']!;
                          final name = state.uri.queryParameters['name'] ?? 'Deployment';
                          return _adaptiveStackPage(
                            context,
                            DeploymentDetailView(deploymentId: id, deploymentName: name),
                          );
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'stacks',
                    pageBuilder: (context, state) =>
                        _adaptiveStackPage(context, const StacksListView()),
                    routes: [
                      GoRoute(
                        path: ':id',
                        pageBuilder: (context, state) {
                          final id = state.pathParameters['id']!;
                          final name =
                              state.uri.queryParameters['name'] ?? 'Stack';
                          return _adaptiveStackPage(
                            context,
                            StackDetailView(stackId: id, stackName: name),
                          );
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'repos',
                    pageBuilder: (context, state) =>
                        _adaptiveStackPage(context, const ReposListView()),
                    routes: [
                      GoRoute(
                        path: ':id',
                        pageBuilder: (context, state) {
                          final id = state.pathParameters['id']!;
                          final name =
                              state.uri.queryParameters['name'] ?? 'Repo';
                          return _adaptiveStackPage(
                            context,
                            RepoDetailView(repoId: id, repoName: name),
                          );
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'syncs',
                    pageBuilder: (context, state) =>
                        _adaptiveStackPage(context, const SyncsListView()),
                    routes: [
                      GoRoute(
                        path: ':id',
                        pageBuilder: (context, state) {
                          final id = state.pathParameters['id']!;
                          final name =
                              state.uri.queryParameters['name'] ?? 'Sync';
                          return _adaptiveStackPage(
                            context,
                            SyncDetailView(syncId: id, syncName: name),
                          );
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'builds',
                    pageBuilder: (context, state) =>
                        _adaptiveStackPage(context, const BuildsListView()),
                    routes: [
                      GoRoute(
                        path: ':id',
                        pageBuilder: (context, state) {
                          final id = state.pathParameters['id']!;
                          final name =
                              state.uri.queryParameters['name'] ?? 'Build';
                          return _adaptiveStackPage(
                            context,
                            BuildDetailView(buildId: id, buildName: name),
                          );
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'procedures',
                    pageBuilder: (context, state) =>
                        _adaptiveStackPage(context, const ProceduresListView()),
                    routes: [
                      GoRoute(
                        path: ':id',
                        pageBuilder: (context, state) {
                          final id = state.pathParameters['id']!;
                          final name =
                              state.uri.queryParameters['name'] ?? 'Procedure';
                          return _adaptiveStackPage(
                            context,
                            ProcedureDetailView(
                              procedureId: id,
                              procedureName: name,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'actions',
                    pageBuilder: (context, state) =>
                        _adaptiveStackPage(context, const ActionsListView()),
                    routes: [
                      GoRoute(
                        path: ':id',
                        pageBuilder: (context, state) {
                          final id = state.pathParameters['id']!;
                          final name =
                              state.uri.queryParameters['name'] ?? 'Action';
                          return _adaptiveStackPage(
                            context,
                            ActionDetailView(actionId: id, actionName: name),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.containers,
                pageBuilder: (context, state) =>
                    _noTransitionTabPage(const ContainersView()),
                routes: [
                  GoRoute(
                    path: ':serverId/:container',
                    pageBuilder: (context, state) {
                      final serverId = state.pathParameters['serverId']!;
                      final container = state.pathParameters['container']!;
                      return _adaptiveStackPage(
                        context,
                        ContainerDetailView(
                          serverId: serverId,
                          containerIdOrName: container,
                          initialItem: state.extra is ContainerOverviewItem
                              ? state.extra as ContainerOverviewItem
                              : null,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.notifications,
                pageBuilder: (context, state) =>
                    _noTransitionTabPage(const NotificationsView()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                pageBuilder: (context, state) =>
                    _noTransitionTabPage(const SettingsView()),
                routes: [
                  GoRoute(
                    path: 'connections',
                    pageBuilder: (context, state) =>
                        _adaptiveStackPage(context, const ConnectionsView()),
                  ),
                  GoRoute(
                    path: 'komodo/variables',
                    pageBuilder: (context, state) =>
                        _adaptiveStackPage(context, const VariablesView()),
                  ),
                  GoRoute(
                    path: 'komodo/tags',
                    pageBuilder: (context, state) =>
                        _adaptiveStackPage(context, const TagsView()),
                  ),
                  GoRoute(
                    path: 'komodo/builders',
                    pageBuilder: (context, state) =>
                        _adaptiveStackPage(context, const BuildersView()),
                  ),
                  GoRoute(
                    path: 'komodo/alerters',
                    pageBuilder: (context, state) =>
                        _adaptiveStackPage(context, const AlertersView()),
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

/// Main shell with bottom navigation.
class MainShell extends StatelessWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AdaptiveBottomNavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onTap: _onItemTapped,
        items: const [
          AdaptiveNavigationItem(
            icon: Icon(AppIcons.home),
            activeIcon: Icon(AppIcons.home),
            label: 'Home',
          ),
          AdaptiveNavigationItem(
            icon: Icon(AppIcons.resources),
            activeIcon: Icon(AppIcons.resources),
            label: 'Resources',
          ),
          AdaptiveNavigationItem(
            icon: Icon(AppIcons.containers),
            activeIcon: Icon(AppIcons.containers),
            label: 'Containers',
          ),
          AdaptiveNavigationItem(
            icon: Icon(AppIcons.notifications),
            activeIcon: Icon(AppIcons.notificationsActive),
            label: 'Notifications',
          ),
          AdaptiveNavigationItem(
            icon: Icon(AppIcons.settings),
            activeIcon: Icon(AppIcons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
