import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/data/models/auth_state.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/views/login_view.dart';
import '../../features/deployments/presentation/views/deployments_list_view.dart';
import '../../features/home/presentation/views/home_view.dart';
import '../../features/builds/presentation/views/build_detail_view.dart';
import '../../features/builds/presentation/views/builds_list_view.dart';
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
import '../widgets/adaptive_bottom_navigation_bar.dart';

part 'app_router.g.dart';

/// Route paths
abstract class AppRoutes {
  static const login = '/login';
  static const home = '/';
  static const resources = '/resources';
  static const notifications = '/notifications';
  static const settings = '/settings';

  static const servers = '/servers';
  static const serverDetail = '/servers/:id';
  static const deployments = '/deployments';
  static const stacks = '/stacks';
  static const repos = '/repos';
  static const builds = '/builds';
  static const procedures = '/procedures';

  /// Legacy path (renamed to [settings]).
  static const connections = '/connections';
}

@riverpod
GoRouter appRouter(Ref ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.value?.isAuthenticated ?? false;
      final isLoggingIn = state.matchedLocation == AppRoutes.login;

      // If not authenticated and not on login page, redirect to login
      if (!isAuthenticated && !isLoggingIn) {
        return AppRoutes.login;
      }

      // If authenticated and on login page, redirect to home
      if (isAuthenticated && isLoggingIn) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
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
                const NoTransitionPage(child: HomeView()),
          ),
          GoRoute(
            path: AppRoutes.resources,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ResourcesView()),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: NotificationsView()),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ConnectionsView()),
          ),

          GoRoute(
            path: AppRoutes.servers,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ServersListView()),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  final name = state.uri.queryParameters['name'] ?? 'Server';
                  return ServerDetailView(serverId: id, serverName: name);
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.deployments,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DeploymentsListView()),
          ),
          GoRoute(
            path: AppRoutes.stacks,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: StacksListView()),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  final name = state.uri.queryParameters['name'] ?? 'Stack';
                  return StackDetailView(stackId: id, stackName: name);
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.repos,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ReposListView()),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  final name = state.uri.queryParameters['name'] ?? 'Repo';
                  return RepoDetailView(repoId: id, repoName: name);
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.builds,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: BuildsListView()),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  final name = state.uri.queryParameters['name'] ?? 'Build';
                  return BuildDetailView(buildId: id, buildName: name);
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.procedures,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProceduresListView()),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  final name = state.uri.queryParameters['name'] ?? 'Procedure';
                  return ProcedureDetailView(
                    procedureId: id,
                    procedureName: name,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.connections,
            redirect: (_, __) => AppRoutes.settings,
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
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          AdaptiveNavigationItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view),
            label: 'Resources',
          ),
          AdaptiveNavigationItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          AdaptiveNavigationItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
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
    if (location.startsWith(AppRoutes.builds)) return 1;
    if (location.startsWith(AppRoutes.procedures)) return 1;

    if (location.startsWith(AppRoutes.notifications)) return 2;

    if (location.startsWith(AppRoutes.settings)) return 3;
    if (location.startsWith(AppRoutes.connections)) return 3;
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
        context.go(AppRoutes.notifications);
        break;
      case 3:
        context.go(AppRoutes.settings);
        break;
    }
  }
}
