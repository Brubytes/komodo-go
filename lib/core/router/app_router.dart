import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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
import '../../features/settings/presentation/views/settings_view.dart';
import '../widgets/adaptive_bottom_navigation_bar.dart';

part 'app_router.g.dart';

Page<void> _noTransitionTabPage(Widget child) => NoTransitionPage<void>(
  child: child,
);

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
                _noTransitionTabPage(const HomeView()),
          ),
          GoRoute(
            path: AppRoutes.resources,
            pageBuilder: (context, state) =>
                _noTransitionTabPage(const ResourcesView()),
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
                    ProcedureDetailView(
                      procedureId: id,
                      procedureName: name,
                    ),
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
