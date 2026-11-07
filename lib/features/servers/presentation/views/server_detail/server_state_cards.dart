import 'package:flutter/material.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/empty_state_view.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';

class ServerMessageCard extends StatelessWidget {
  const ServerMessageCard({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCardSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: EmptyStateView.inline(icon: AppIcons.info, title: message),
      ),
    );
  }
}
