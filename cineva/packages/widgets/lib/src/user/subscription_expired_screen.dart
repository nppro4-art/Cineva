import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

/// Abonnement expiré : échéance réelle, nouvelle vérification, déconnexion.
class SubscriptionExpiredScreen extends ConsumerWidget {
  const SubscriptionExpiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionSnapshot? session = ref.watch(sessionControllerProvider).valueOrNull;
    final AppUser? user = session?.user;
    final CinevaMetrics metrics = CinevaMetrics.of(context);

    return Scaffold(
      backgroundColor: CinevaColors.ink,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(metrics.gutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: CinevaColors.surface,
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      size: 24,
                      color: CinevaColors.gold,
                    ),
                  ),
                  const SizedBox(height: CinevaSpacing.lg),
                  Text(
                    'Abonnement expiré',
                    style: CinevaTypography.screenTitle.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: CinevaSpacing.xs),
                  Text(
                    'Votre abonnement est arrivé à échéance. L’application reste '
                    'ouverte, mais le catalogue est verrouillé tant que votre accès '
                    'n’est pas prolongé.',
                    style: CinevaTypography.bodyCompact,
                  ),
                  if (user != null) ...<Widget>[
                    const SizedBox(height: CinevaSpacing.lg),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: CinevaColors.surface,
                        borderRadius: BorderRadius.circular(CinevaRadii.card),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(CinevaSpacing.md),
                        child: Row(
                          children: <Widget>[
                            const Icon(
                              Icons.calendar_month_rounded,
                              size: 17,
                              color: CinevaColors.gold,
                            ),
                            const SizedBox(width: CinevaSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    'Échéance enregistrée',
                                    style: CinevaTypography.meta.copyWith(fontSize: 11),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    user.subscriptionExpiresLabel,
                                    style: CinevaTypography.numeric.copyWith(
                                      fontSize: 14,
                                      color: CinevaColors.textHigh,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: CinevaSpacing.xl),
                  CinevaPlayButton(
                    label: 'Vérifier à nouveau',
                    icon: Icons.refresh_rounded,
                    height: 48,
                    onPressed: () => ref
                        .read(sessionControllerProvider.notifier)
                        .refresh(showLoader: false),
                  ),
                  const SizedBox(height: CinevaSpacing.sm),
                  CinevaSecondaryButton(
                    label: 'Se déconnecter',
                    icon: Icons.logout_rounded,
                    height: 48,
                    onPressed: () =>
                        ref.read(sessionControllerProvider.notifier).signOut(),
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
