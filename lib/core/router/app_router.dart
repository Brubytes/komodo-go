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
import '../../features/stacks/presentation/views/stack_detail_view.dart';
import '../../features/stacks/presentation/views/stacks_list_view.dart';
import '../../features/settings/presentation/views/connections_view.dart';
import '../../features/settings/presentation/views/settings_view.dart';
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

  static const servers = '/servers';
  static const serverDetail = '/servers/:id';
  static const deployments = '/deployments';
  static const stacks = '/stacks';
  static const repos = '/repos';
  static const syncs = '/syncs';
  static const builds = '/builds';
  static const procedures = '/procedures';
  static const actions = '/actions';

  /// Legacy path (renamed to [settings]).
  static const connections = '/connections';
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

      // Shell route for bottom navigation
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) =>
                _noTransitionTabPage(const HomeView()),
          ),
          GoRoute(
            path: AppRoutes.resources,
            pageBuilder: (context, state) =>
                _noTransitionTabPage(const ResourcesView()),
          ),
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
          GoRoute(
            path: AppRoutes.notifications,
            pageBuilder: (context, state) =>
                _noTransitionTabPage(const NotificationsView()),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) =>
                _noTransitionTabPage(const SettingsView()),
          ),
          GoRoute(
            path: AppRoutes.connections,
            pageBuilder: (context, state) =>
                _adaptiveStackPage(context, const ConnectionsView()),
          ),

          GoRoute(
            path: AppRoutes.servers,
            pageBuilder: (context, state) =>
                _adaptiveStackPage(context, const ServersListView()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id']!;
                  final name = state.uri.queryParameters['name'] ?? 'Server';
                  return _adaptiveStackPage(
                    context,
                    ServerDetailView(serverId: id, serverName: name),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.deployments,
            pageBuilder: (context, state) =>
                _adaptiveStackPage(context, const DeploymentsListView()),
          ),
          GoRoute(
            path: AppRoutes.stacks,
            pageBuilder: (context, state) =>
                _adaptiveStackPage(context, const StacksListView()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id']!;
                  final name = state.uri.queryParameters['name'] ?? 'Stack';
                  return _adaptiveStackPage(
                    context,
                    StackDetailView(stackId: id, stackName: name),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.repos,
            pageBuilder: (context, state) =>
                _adaptiveStackPage(context, const ReposListView()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id']!;
                  final name = state.uri.queryParameters['name'] ?? 'Repo';
                  return _adaptiveStackPage(
                    context,
                    RepoDetailView(repoId: id, repoName: name),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.syncs,
            pageBuilder: (context, state) =>
                _adaptiveStackPage(context, const SyncsListView()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id']!;
                  final name = state.uri.queryParameters['name'] ?? 'Sync';
                  return _adaptiveStackPage(
                    context,
                    SyncDetailView(syncId: id, syncName: name),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.builds,
            pageBuilder: (context, state) =>
                _adaptiveStackPage(context, const BuildsListView()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id']!;
                  final name = state.uri.queryParameters['name'] ?? 'Build';
                  return _adaptiveStackPage(
                    context,
                    BuildDetailView(buildId: id, buildName: name),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.procedures,
            pageBuilder: (context, state) =>
                _adaptiveStackPage(context, const ProceduresListView()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id']!;
                  final name = state.uri.queryParameters['name'] ?? 'Procedure';
                  return _adaptiveStackPage(
                    context,
                    ProcedureDetailView(procedureId: id, procedureName: name),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.actions,
            pageBuilder: (context, state) =>
                _adaptiveStackPage(context, const ActionsListView()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id']!;
                  final name = state.uri.queryParameters['name'] ?? 'Action';
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
  );
}

/// Main shell with bottom navigation.
class MainShell extends StatelessWidget {
  const MainShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: AdaptiveBottomNavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(context, index),
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

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(AppRoutes.resources)) return 1;
    if (location.startsWith(AppRoutes.servers)) return 1;
    if (location.startsWith(AppRoutes.deployments)) return 1;
    if (location.startsWith(AppRoutes.stacks)) return 1;
    if (location.startsWith(AppRoutes.repos)) return 1;
    if (location.startsWith(AppRoutes.syncs)) return 1;
    if (location.startsWith(AppRoutes.builds)) return 1;
    if (location.startsWith(AppRoutes.procedures)) return 1;
    if (location.startsWith(AppRoutes.actions)) return 1;

    if (location.startsWith(AppRoutes.containers)) return 2;

    if (location.startsWith(AppRoutes.notifications)) return 3;

    if (location.startsWith(AppRoutes.settings)) return 4;
    if (location.startsWith(AppRoutes.connections)) return 4;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.resources);
        break;
      case 2:
        context.go(AppRoutes.containers);
        break;
      case 3:
        context.go(AppRoutes.notifications);
        break;
      case 4:
        context.go(AppRoutes.settings);
        break;
    }
  }
}
