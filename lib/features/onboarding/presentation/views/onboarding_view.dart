import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/connections/connection_profile.dart';
import 'package:komodo_go/core/demo/demo_config.dart';
import 'package:komodo_go/core/providers/connections_provider.dart';
import 'package:komodo_go/core/providers/onboarding_provider.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/features/auth/presentation/providers/auth_provider.dart';

class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({super.key});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  bool _isBusy = false;

  Future<void> _handleUseDemo() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    try {
      final store = await ref.read(connectionsStoreProvider.future);
      final connections = await store.listConnections();
      ConnectionProfile? demoConnection;
      for (final connection in connections) {
        if (connection.name == demoConnectionName) {
          demoConnection = connection;
          break;
        }
      }

      if (demoConnection == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demo connection not available.')),
        );
        return;
      }

      await ref.read(onboardingProvider.notifier).markCompleted();
      await ref
          .read(authProvider.notifier)
          .selectConnection(demoConnection.id);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _handleAddOwn() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    try {
      await ref.read(onboardingProvider.notifier).markCompleted();
      await ref.read(authProvider.notifier).logout();
      if (!mounted) return;
      context.go(AppRoutes.login);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scheme.outlineVariant,
                        width: 2,
                      ),
                    ),
                    child: Image.asset(
                      'assets/komodo-go-logo_circle.png',
                      width: 96,
                      height: 96,
                    ),
                  ),
                  const Gap(16),
                  Text(
                    'Welcome to Komodo Go',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Gap(8),
                  Text(
                    'Choose how you want to get started.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const Gap(32),
                  Card(
                    elevation: 0,
                    color: scheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(AppIcons.server, color: scheme.primary),
                              const Gap(8),
                              Text(
                                'Use demo instance',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const Gap(8),
                          Text(
                            'Explore Komodo with a pre-configured local demo backend.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          const Gap(16),
                          FilledButton.icon(
                            onPressed:
                                (!_isBusy && demoAvailable) ? _handleUseDemo : null,
                            icon: const Icon(AppIcons.play),
                            label: const Text('Start with demo'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Gap(16),
                  Card(
                    elevation: 0,
                    color: scheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(AppIcons.add, color: scheme.primary),
                              const Gap(8),
                              Text(
                                'Connect your own instance',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const Gap(8),
                          Text(
                            'Provide the URL and API credentials for your Komodo server.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          const Gap(16),
                          OutlinedButton.icon(
                            onPressed: _isBusy ? null : _handleAddOwn,
                            icon: const Icon(AppIcons.add),
                            label: const Text('Add connection'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!demoAvailable) ...[
                    const Gap(16),
                    Text(
                      'Demo mode is not available in this build.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
