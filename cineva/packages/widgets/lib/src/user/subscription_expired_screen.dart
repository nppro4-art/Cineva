import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

class SubscriptionExpiredScreen extends ConsumerWidget {
  const SubscriptionExpiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final user = session?.user;

    return Scaffold(
      body: CinevaScaffoldContainer(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: CinevaGlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Abonnement expiré', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: CinevaSpacing.md),
                  Text(
                    'Votre abonnement est arrivé à échéance. Vous pouvez toujours ouvrir l’application, mais le contenu reste bloqué tant qu’un administrateur ne prolonge pas votre accès.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: CinevaColors.textMuted),
                  ),
                  if (user != null) ...<Widget>[
                    const SizedBox(height: CinevaSpacing.md),
                    CinevaStatusBanner(
                      title: 'Expiration actuelle',
                      message: user.subscriptionExpiresLabel,
                      tone: CinevaBannerTone.warning,
                    ),
                  ],
                  const SizedBox(height: CinevaSpacing.lg),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      SizedBox(
                        width: 220,
                        child: CinevaPrimaryButton(
                          label: 'Vérifier à nouveau',
                          icon: Icons.refresh_rounded,
                          onPressed: () => ref.read(sessionControllerProvider.notifier).refresh(showLoader: false),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: CinevaPrimaryButton(
                          label: 'Se déconnecter',
                          icon: Icons.logout_rounded,
                          onPressed: () => ref.read(sessionControllerProvider.notifier).signOut(),
                        ),
                      ),
                    ],
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
