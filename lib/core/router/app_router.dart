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
import '../../features/repos/presentation/views/repo_detail_view.dart';
import '../../features/repos/presentation/views/repos_list_view.dart';
import '../../features/procedures/presentation/views/procedure_detail_view.dart';
import '../../features/procedures/presentation/views/procedures_list_view.dart';
import '../../features/servers/presentation/views/servers_list_view.dart';
import '../../features/stacks/presentation/views/stack_detail_view.dart';
import '../../features/stacks/presentation/views/stacks_list_view.dart';
import '../widgets/adaptive_bottom_navigation_bar.dart';

part 'app_router.g.dart';

/// Route paths
abstract class AppRoutes {
  static const login = '/login';
  static const home = '/';
  static const servers = '/servers';
  static const serverDetail = '/servers/:id';
  static const deployments = '/deployments';
  static const stacks = '/stacks';
  static const repos = '/repos';
  static const builds = '/builds';
  static const procedures = '/procedures';
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
            icon: Icon(Icons.dns_outlined),
            activeIcon: Icon(Icons.dns),
            label: 'Servers',
          ),
          AdaptiveNavigationItem(
            icon: Icon(Icons.rocket_launch_outlined),
            activeIcon: Icon(Icons.rocket_launch),
            label: 'Deployments',
          ),
          AdaptiveNavigationItem(
            icon: Icon(Icons.layers_outlined),
            activeIcon: Icon(Icons.layers),
            label: 'Stacks',
          ),
          AdaptiveNavigationItem(
            icon: Icon(Icons.source_outlined),
            activeIcon: Icon(Icons.source),
            label: 'Repos',
          ),
          AdaptiveNavigationItem(
            icon: Icon(Icons.build_circle_outlined),
            activeIcon: Icon(Icons.build_circle),
            label: 'Builds',
          ),
          AdaptiveNavigationItem(
            icon: Icon(Icons.playlist_play_outlined),
            activeIcon: Icon(Icons.playlist_play),
            label: 'Procedures',
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(AppRoutes.servers)) return 1;
    if (location.startsWith(AppRoutes.deployments)) return 2;
    if (location.startsWith(AppRoutes.stacks)) return 3;
    if (location.startsWith(AppRoutes.repos)) return 4;
    if (location.startsWith(AppRoutes.builds)) return 5;
    if (location.startsWith(AppRoutes.procedures)) return 6;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
      case 1:
        context.go(AppRoutes.servers);
      case 2:
        context.go(AppRoutes.deployments);
      case 3:
        context.go(AppRoutes.stacks);
      case 4:
        context.go(AppRoutes.repos);
      case 5:
        context.go(AppRoutes.builds);
      case 6:
        context.go(AppRoutes.procedures);
    }
  }
}
