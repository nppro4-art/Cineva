import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../app/session_controller.dart';
import '../library/active_profile_controller.dart';

/// Abonnement et paiement (route `/account/subscription`).
///
/// Un seul abonnement pour tout le foyer : [CinevaOffer.monthlyPriceEur] € par
/// mois, [CinevaOffer.maxDevices] appareils, [CinevaOffer.maxProfiles] profils.
/// Le règlement se fait directement auprès de l'exploitant — par carte via
/// Revolut ou en main propre — et les coordonnées sont copiables d'un geste.
///
/// Aucun paiement en ligne n'est simulé ici : l'app affiche l'offre réelle,
/// l'usage réel (appareils et profils du compte) et la marche à suivre.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionSnapshot? session = ref.watch(sessionControllerProvider).valueOrNull;
    final ActiveProfileState profileState = ref.watch(activeProfileControllerProvider);
    final CinevaMetrics metrics = CinevaMetrics.of(context);

    final int deviceCount = session?.devices.length ?? 0;
    final int profileCount = profileState.profiles.length;

    return Scaffold(
      backgroundColor: CinevaColors.ink,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
          decelerationRate: ScrollDecelerationRate.fast,
        ),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: CinevaTopBar(
              title: 'Abonnement & paiement',
              onBack: () => context.canPop() ? context.pop() : context.go('/profile'),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              metrics.gutter,
              CinevaSpacing.sm,
              metrics.gutter,
              CinevaSpacing.xxl,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                <Widget>[
                  const _PriceHeader(),
                  const SizedBox(height: CinevaSpacing.lg),
                  const _IncludedCard(),
                  const SizedBox(height: CinevaSpacing.lg),
                  _UsageCard(
                    deviceCount: deviceCount,
                    profileCount: profileCount,
                    expiresLabel: session?.user?.subscriptionExpiresLabel ?? 'Aucune date',
                    subscriptionActive: session?.user?.hasActiveSubscription ?? false,
                    onDevices: () => context.push('/account/devices'),
                    onProfiles: () => context.push('/account/profiles'),
                  ),
                  const SizedBox(height: CinevaSpacing.xl),
                  Text('Payer', style: CinevaTypography.sectionTitle),
                  const SizedBox(height: CinevaSpacing.xs),
                  const _PaymentSteps(),
                  const SizedBox(height: CinevaSpacing.xl),
                  Text('Coordonnées', style: CinevaTypography.sectionTitle),
                  const SizedBox(height: CinevaSpacing.xs),
                  _ContactTile(
                    icon: Icons.phone_outlined,
                    title: 'Téléphone',
                    value: CinevaOffer.supportPhoneDisplay,
                    semanticLabel: 'Copier le numéro de téléphone',
                  ),
                  _ContactTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Revolut',
                    value: CinevaOffer.revolutTag,
                    semanticLabel: 'Copier l’identifiant Revolut',
                  ),
                  const SizedBox(height: CinevaSpacing.md),
                  const CinevaStatusBanner(
                    title: 'Une question ?',
                    message: CinevaOffer.supportHint,
                    tone: CinevaBannerTone.info,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Prix et promesse, en tête d'écran.
class _PriceHeader extends StatelessWidget {
  const _PriceHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              '${CinevaOffer.monthlyPriceEur} €',
              style: CinevaTypography.heroTitle.copyWith(color: CinevaColors.gold),
            ),
            const SizedBox(width: CinevaSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('par mois', style: CinevaTypography.bodyCompact),
            ),
          ],
        ),
        const SizedBox(height: CinevaSpacing.xs),
        Text(CinevaOffer.headline, style: CinevaTypography.sectionTitle),
        const SizedBox(height: CinevaSpacing.xxs),
        Text(CinevaOffer.summary, style: CinevaTypography.bodyCompact),
      ],
    );
  }
}

/// Ce que l'abonnement comprend.
class _IncludedCard extends StatelessWidget {
  const _IncludedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CinevaSpacing.md),
      decoration: BoxDecoration(
        color: CinevaColors.raised,
        borderRadius: BorderRadius.circular(CinevaRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final String line in CinevaOffer.included)
            Padding(
              padding: const EdgeInsets.only(bottom: CinevaSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: CinevaColors.gold,
                  ),
                  const SizedBox(width: CinevaSpacing.sm),
                  Expanded(child: Text(line, style: CinevaTypography.bodyCompact)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Usage réel du compte : appareils, profils, date d'expiration.
class _UsageCard extends StatelessWidget {
  const _UsageCard({
    required this.deviceCount,
    required this.profileCount,
    required this.expiresLabel,
    required this.subscriptionActive,
    required this.onDevices,
    required this.onProfiles,
  });

  final int deviceCount;
  final int profileCount;
  final String expiresLabel;
  final bool subscriptionActive;
  final VoidCallback onDevices;
  final VoidCallback onProfiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!subscriptionActive)
          const Padding(
            padding: EdgeInsets.only(bottom: CinevaSpacing.sm),
            child: CinevaStatusBanner(
              title: 'Abonnement à renouveler',
              message: 'Réglez 15 € pour prolonger d’un mois : la nouvelle date '
                  's’affiche ici dès l’activation.',
              tone: CinevaBannerTone.warning,
            ),
          ),
        CinevaTileGroup(
          children: <Widget>[
            CinevaListTile(
              icon: Icons.devices_other_outlined,
              title: 'Appareils connectés',
              subtitle: '$deviceCount sur ${CinevaOffer.maxDevices} — téléphone, PC, TV',
              onTap: onDevices,
            ),
            CinevaListTile(
              icon: Icons.group_outlined,
              title: 'Profils du foyer',
              subtitle: '$profileCount sur ${CinevaOffer.maxProfiles} — chacun sa liste et sa reprise',
              onTap: onProfiles,
            ),
            CinevaListTile(
              icon: Icons.event_available_outlined,
              title: 'Valable jusqu’au',
              subtitle: expiresLabel,
              showChevron: false,
              onTap: null,
            ),
          ],
        ),
      ],
    );
  }
}

/// Marche à suivre pour régler l'abonnement.
class _PaymentSteps extends StatelessWidget {
  const _PaymentSteps();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var index = 0; index < CinevaOffer.paymentSteps.length; index += 1)
          Padding(
            padding: const EdgeInsets.only(bottom: CinevaSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: CinevaColors.veilStrong,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: CinevaTypography.meta.copyWith(
                      color: CinevaColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: CinevaSpacing.sm),
                Expanded(
                  child: Text(
                    CinevaOffer.paymentSteps[index],
                    style: CinevaTypography.bodyCompact,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Coordonnée copiable d'un geste (téléphone, Revolut).
class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.semanticLabel,
  });

  final IconData icon;
  final String title;
  final String value;
  final String semanticLabel;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title copié : $value')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CinevaListTile(
      icon: icon,
      title: title,
      subtitle: value,
      semanticLabel: semanticLabel,
      trailing: const Icon(Icons.copy_rounded, size: 18, color: CinevaColors.textFaint),
      onTap: () => _copy(context),
    );
  }
}
