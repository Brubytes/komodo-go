import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/connections/connection_profile.dart';
import 'package:komodo_go/core/providers/connections_provider.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/always_paste_context_menu.dart';

class EditConnectionSheet extends HookConsumerWidget {
  const EditConnectionSheet({
    required this.connection,
    super.key,
  });

  final ConnectionProfile connection;

  static Future<void> show(
    BuildContext context, {
    required ConnectionProfile connection,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => EditConnectionSheet(connection: connection),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(GlobalKey<FormState>.new);

    final nameController = useTextEditingController(text: connection.name);
    final baseUrlController = useTextEditingController(text: connection.baseUrl);
    final apiKeyController = useTextEditingController();
    final apiSecretController = useTextEditingController();

    final obscureSecret = useState(true);
    final isSaving = useState(false);
    final hasExistingCredentials = useState<bool?>(null);

    useEffect(() {
      Future<void> load() async {
        final store = await ref.read(connectionsStoreProvider.future);
        final creds = await store.getCredentials(connection.id);
        hasExistingCredentials.value = creds != null;
        if (creds == null) {
          return;
        }
        if (apiKeyController.text.isEmpty) {
          apiKeyController.text = creds.apiKey;
        }
        if (apiSecretController.text.isEmpty) {
          apiSecretController.text = creds.apiSecret;
        }
        if (baseUrlController.text.isEmpty ||
            baseUrlController.text == connection.baseUrl) {
          baseUrlController.text = creds.baseUrl;
        }
      }

      load();
      return null;
    }, [connection.id]);

    Future<void> save() async {
      if (!(formKey.currentState?.validate() ?? false)) {
        return;
      }

      isSaving.value = true;
      try {
        await ref.read(connectionsProvider.notifier).updateConnectionDetails(
              connectionId: connection.id,
              name: nameController.text,
              baseUrl: baseUrlController.text,
              apiKey: apiKeyController.text,
              apiSecret: apiSecretController.text,
            );

        if (!context.mounted) return;
        Navigator.of(context).pop();
      } finally {
        isSaving.value = false;
      }
    }

    final canKeepCredentials = hasExistingCredentials.value ?? false;

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
                    'Edit connection',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const Gap(8),
                  Text(
                    'Update the connection details. You can leave API key/secret empty to keep the existing credentials.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const Gap(24),

                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name (optional)',
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
                      if (canKeepCredentials) {
                        return null;
                      }
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
                          obscureSecret.value ? AppIcons.eye : AppIcons.eyeOff,
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
                    onFieldSubmitted: (_) => save(),
                    validator: (value) {
                      if (canKeepCredentials) {
                        return null;
                      }
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
                      onPressed: isSaving.value ? null : save,
                      child: isSaving.value
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save changes'),
                    ),
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
