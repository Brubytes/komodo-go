import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:url_launcher/url_launcher.dart';

class CreditsView extends StatelessWidget {
  const CreditsView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const MainAppBar(
        title: 'Credits',
        icon: AppIcons.heart,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          // Indie Dev Section
          const _CreditsSectionHeader(title: 'Made with love'),
          const Gap(8),
          AppCardSurface(
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/komodo-go-logo_rounded.png',
                    width: 44,
                    height: 44,
                  ),
                ),
                const Gap(14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Komodo Go',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        'Built by an indie developer as a companion app for Komodo.',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap(20),

          // Komodo Project Section
          const _CreditsSectionHeader(title: 'Powered by'),
          const Gap(8),
          const _KomodoCard(),
          const Gap(20),

          // Open Source Libraries Section
          const _CreditsSectionHeader(title: 'Open source'),
          const Gap(8),
          const AppCardSurface(
            child: Column(
              children: [
                _CompactCreditRow(
                  icon: AppIcons.theme,
                  iconColor: Colors.amber,
                  title: 'Lucide Icons',
                  subtitle: 'Icon library',
                  url: 'https://lucide.dev',
                ),
                _CreditDivider(),
                _CompactCreditRow(
                  icon: AppIcons.code,
                  iconColor: Colors.blue,
                  title: 'Flutter & Dart',
                  subtitle: 'UI framework',
                  url: 'https://flutter.dev',
                ),
                _CreditDivider(),
                _CompactCreditRow(
                  icon: AppIcons.refresh,
                  iconColor: Colors.teal,
                  title: 'Riverpod',
                  subtitle: 'State management',
                  url: 'https://riverpod.dev',
                ),
                _CreditDivider(),
                _CompactCreditRow(
                  icon: AppIcons.procedures,
                  iconColor: Colors.purple,
                  title: 'go_router',
                  subtitle: 'Navigation',
                  url: 'https://pub.dev/packages/go_router',
                ),
                _CreditDivider(),
                _CompactCreditRow(
                  icon: AppIcons.actions,
                  iconColor: Colors.orange,
                  title: 'fpdart',
                  subtitle: 'Functional programming',
                  url: 'https://pub.dev/packages/fpdart',
                ),
                _CreditDivider(),
                _CompactCreditRow(
                  icon: AppIcons.package,
                  iconColor: Colors.indigo,
                  title: 'Freezed',
                  subtitle: 'Code generation',
                  url: 'https://pub.dev/packages/freezed',
                ),
                _CreditDivider(),
                _CompactCreditRow(
                  icon: AppIcons.network,
                  iconColor: Colors.green,
                  title: 'Dio',
                  subtitle: 'HTTP client',
                  url: 'https://pub.dev/packages/dio',
                ),
                _CreditDivider(),
                _CompactCreditRow(
                  icon: AppIcons.lock,
                  iconColor: Colors.red,
                  title: 'flutter_secure_storage',
                  subtitle: 'Secure storage',
                  url: 'https://pub.dev/packages/flutter_secure_storage',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditsSectionHeader extends StatelessWidget {
  const _CreditsSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(
            title,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.1,
            ),
          ),
          const Spacer(),
          Container(
            width: 34,
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}

class _CreditLink {
  const _CreditLink({
    required this.label,
    required this.url,
    this.icon = AppIcons.externalLink,
  });

  final String label;
  final String url;
  final IconData icon;
}

class _KomodoCard extends StatelessWidget {
  const _KomodoCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTokens.brandSecondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text('\u{1F98E}', style: TextStyle(fontSize: 20)),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Komodo',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      'Self-hosted deployment & infrastructure platform',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _CreditLink(
                label: 'Website',
                url: 'https://komo.do',
                icon: AppIcons.globe,
              ),
              _CreditLink(
                label: 'GitHub',
                url: 'https://github.com/moghtech/komodo',
                icon: AppIcons.github,
              ),
            ].map((link) => _LinkChip(link: link)).toList(),
          ),
        ],
      ),
    );
  }
}

class _CompactCreditRow extends StatelessWidget {
  const _CompactCreditRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.url,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => _launchUrl(context, url),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              AppIcons.externalLink,
              size: 16,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    }
  }
}

class _CreditDivider extends StatelessWidget {
  const _CreditDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.3),
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.link});

  final _CreditLink link;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        onTap: () => _launchUrl(context, link.url),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                link.icon,
                size: 14,
                color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
              const Gap(6),
              Text(
                link.label,
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    }
  }
}
