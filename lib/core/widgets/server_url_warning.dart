import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

class ServerUrlWarning extends StatelessWidget {
  const ServerUrlWarning({
    required this.value,
    super.key,
  });

  final String value;

  @override
  Widget build(BuildContext context) {
    final normalized = value.trim();
    if (normalized.isEmpty || _hasExplicitScheme(normalized)) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              AppIcons.warning,
              size: 18,
              color: colorScheme.primary,
            ),
          ),
          const Gap(10),
          Expanded(
            child: Text(
              'Include http:// or https:// explicitly. The app will use this address exactly as entered and will not auto-upgrade it to HTTPS.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.82),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasExplicitScheme(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) {
      return false;
    }
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }
}
