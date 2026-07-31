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
    if (normalized.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_scheme(normalized) == 'http') {
      return const _WarningBox(
        message:
            'Unencrypted connection: your API key and secret will be sent '
            'in plain text. Only use http:// on networks you fully trust '
            '(e.g. a local or VPN network).',
        emphasize: true,
      );
    }

    if (!_hasExplicitScheme(normalized)) {
      return const _WarningBox(
        message:
            'Include http:// or https:// explicitly. If you omit a scheme, the app will default to https://. To use http://, you must include it explicitly.',
      );
    }

    return const SizedBox.shrink();
  }

  String? _scheme(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) {
      return null;
    }
    return uri.scheme.toLowerCase();
  }

  bool _hasExplicitScheme(String value) {
    final scheme = _scheme(value);
    return scheme == 'http' || scheme == 'https';
  }
}

class _WarningBox extends StatelessWidget {
  const _WarningBox({
    required this.message,
    this.emphasize = false,
  });

  final String message;

  /// When true, uses the warning (tertiary) tone instead of the neutral
  /// informational styling.
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = emphasize ? colorScheme.tertiary : colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: emphasize
            ? colorScheme.tertiaryContainer.withValues(alpha: 0.35)
            : colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: emphasize
              ? colorScheme.tertiary.withValues(alpha: 0.45)
              : colorScheme.outlineVariant,
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
              color: accent,
            ),
          ),
          const Gap(10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.82),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
