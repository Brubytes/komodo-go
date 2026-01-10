import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({required this.title, this.onSeeAll, super.key});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (onSeeAll != null)
          TextButton(onPressed: onSeeAll, child: const Text('See all')),
      ],
    );
  }
}

class HomeLoadingTile extends StatelessWidget {
  const HomeLoadingTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class HomeErrorTile extends StatelessWidget {
  const HomeErrorTile({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(AppIcons.formError, color: Colors.red),
            const Gap(8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class HomeEmptyListTile extends StatelessWidget {
  const HomeEmptyListTile({required this.icon, required this.message, super.key});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const Gap(8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
