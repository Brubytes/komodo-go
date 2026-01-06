import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/widgets/always_paste_context_menu.dart';
import 'package:komodo_go/features/auth/data/models/auth_state.dart';
import 'package:komodo_go/features/auth/presentation/providers/auth_provider.dart';

class AddConnectionSheet extends HookConsumerWidget {
  const AddConnectionSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const AddConnectionSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);
    final formKey = useMemoized(GlobalKey<FormState>.new);

    final connectionNameController = useTextEditingController();
    final baseUrlController = useTextEditingController();
    final apiKeyController = useTextEditingController();
    final apiSecretController = useTextEditingController();

    final obscureSecret = useState(true);

    Future<void> handleSave() async {
      if (!(formKey.currentState?.validate() ?? false)) {
        return;
      }

      await ref
          .read(authProvider.notifier)
          .login(
            name: connectionNameController.text,
            baseUrl: baseUrlController.text,
            apiKey: apiKeyController.text,
            apiSecret: apiSecretController.text,
          );

      final nextState = ref.read(authProvider).value;
      if (context.mounted && nextState is! AuthStateError) {
        Navigator.of(context).pop();
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        top: 8,
        right: 24,
        bottom: 24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Add connection',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Gap(8),
                  Text(
                    'Add another Komodo instance by providing its URL and API credentials.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Gap(24),
                  if (authAsync.value is AuthStateError) ...[
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
                            AppIcons.formError,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const Gap(8),
                          Expanded(
                            child: Text(
                              (authAsync.value! as AuthStateError)
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
                  TextFormField(
                    controller: connectionNameController,
                    decoration: const InputDecoration(
                      labelText: 'Name (optional)',
                      hintText: 'Production',
                      prefixIcon: Icon(AppIcons.tag),
                    ),
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableInteractiveSelection: true,
                    contextMenuBuilder: alwaysPasteContextMenu,
                  ),
                  const Gap(16),
                  TextFormField(
                    controller: baseUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'https://komodo.example.com',
                      prefixIcon: Icon(AppIcons.server),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableInteractiveSelection: true,
                    contextMenuBuilder: alwaysPasteContextMenu,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter the server URL';
                      }
                      return null;
                    },
                  ),
                  const Gap(16),
                  TextFormField(
                    controller: apiKeyController,
                    decoration: const InputDecoration(
                      labelText: 'API Key',
                      prefixIcon: Icon(AppIcons.key),
                    ),
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableInteractiveSelection: true,
                    contextMenuBuilder: alwaysPasteContextMenu,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your API key';
                      }
                      return null;
                    },
                  ),
                  const Gap(16),
                  TextFormField(
                    controller: apiSecretController,
                    decoration: InputDecoration(
                      labelText: 'API Secret',
                      prefixIcon: const Icon(AppIcons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureSecret.value
                              ? AppIcons.eye
                              : AppIcons.eyeOff,
                        ),
                        onPressed: () {
                          obscureSecret.value = !obscureSecret.value;
                        },
                      ),
                    ),
                    obscureText: obscureSecret.value,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableInteractiveSelection: true,
                    contextMenuBuilder: alwaysPasteContextMenu,
                    onFieldSubmitted: (_) => handleSave(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your API secret';
                      }
                      return null;
                    },
                  ),
                  const Gap(24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: authAsync.isLoading ? null : handleSave,
                      child: authAsync.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                  const Gap(12),
                  Text(
                    'You can generate API keys in the Komodo web interface under your user settings.',
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
    );
  }
}
