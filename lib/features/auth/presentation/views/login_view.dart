import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/providers/connections_provider.dart';
import '../../data/models/auth_state.dart';
import '../providers/auth_provider.dart';

/// Login screen for entering Komodo API credentials.
class LoginView extends HookConsumerWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final connectionsAsync = ref.watch(connectionsProvider);
    final formKey = useMemoized(GlobalKey<FormState>.new);

    final baseUrlController = useTextEditingController();
    final apiKeyController = useTextEditingController();
    final apiSecretController = useTextEditingController();

    final obscureSecret = useState(true);

    Future<void> handleLogin() async {
      if (formKey.currentState?.validate() ?? false) {
        await ref
            .read(authProvider.notifier)
            .login(
              baseUrl: baseUrlController.text,
              apiKey: apiKeyController.text,
              apiSecret: apiSecretController.text,
            );
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo/Title
                    Icon(
                      Icons.cloud_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const Gap(16),
                    Text(
                      'Komodo',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const Gap(8),
                    Text(
                      'Connect to your Komodo instance',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Gap(32),

                    // Existing connections
                    connectionsAsync.when(
                      data: (connectionsState) {
                        final connections = connectionsState.connections;
                        if (connections.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Saved connections',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const Gap(8),
                            Card(
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  for (final connection in connections)
                                    ListTile(
                                      title: Text(connection.name),
                                      subtitle: Text(connection.baseUrl),
                                      leading: Icon(
                                        Icons.dns_outlined,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      trailing: IconButton(
                                        tooltip: 'Delete',
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () async {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text(
                                                'Delete connection',
                                              ),
                                              content: Text(
                                                'Remove "${connection.name}"?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    context,
                                                  ).pop(false),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  onPressed: () => Navigator.of(
                                                    context,
                                                  ).pop(true),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirmed == true) {
                                            await ref
                                                .read(
                                                  connectionsProvider.notifier,
                                                )
                                                .deleteConnection(
                                                  connection.id,
                                                );
                                          }
                                        },
                                      ),
                                      onTap: authState.isLoading
                                          ? null
                                          : () async {
                                              await ref
                                                  .read(authProvider.notifier)
                                                  .selectConnection(
                                                    connection.id,
                                                  );
                                            },
                                    ),
                                ],
                              ),
                            ),
                            const Gap(24),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    // Error message
                    if (authState.value is AuthStateError) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const Gap(8),
                            Expanded(
                              child: Text(
                                (authState.value! as AuthStateError)
                                    .failure
                                    .displayMessage,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Gap(16),
                    ],

                    // Server URL
                    TextFormField(
                      controller: baseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Server URL',
                        hintText: 'https://komodo.example.com',
                        prefixIcon: Icon(Icons.dns_outlined),
                      ),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the server URL';
                        }
                        return null;
                      },
                    ),
                    const Gap(16),

                    // API Key
                    TextFormField(
                      controller: apiKeyController,
                      decoration: const InputDecoration(
                        labelText: 'API Key',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your API key';
                        }
                        return null;
                      },
                    ),
                    const Gap(16),

                    // API Secret
                    TextFormField(
                      controller: apiSecretController,
                      decoration: InputDecoration(
                        labelText: 'API Secret',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureSecret.value
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            obscureSecret.value = !obscureSecret.value;
                          },
                        ),
                      ),
                      obscureText: obscureSecret.value,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      onFieldSubmitted: (_) => handleLogin(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your API secret';
                        }
                        return null;
                      },
                    ),
                    const Gap(24),

                    // Login Button
                    FilledButton(
                      onPressed: authState.isLoading ? null : handleLogin,
                      child: authState.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Connect'),
                    ),
                    const Gap(16),

                    // Help text
                    Text(
                      'You can generate API keys in the Komodo web interface '
                      'under your user settings.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
