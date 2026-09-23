import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../library/active_profile_controller.dart';
import 'profile_form_sheet.dart';

/// Sas « Qui regarde ? » (route `/profiles/select`).
///
/// Affiché après la connexion tant qu'aucun profil membre n'est choisi sur cet
/// appareil : l'abonné touche son profil — ou en crée un — puis arrive sur
/// l'accueil **de son profil** (sa liste, sa reprise de lecture).
///
/// Le sas ne s'affiche jamais quand la base n'a pas de profils (migration non
/// jouée, compte sans profil) : l'app reste utilisable telle quelle.
class ProfileGateScreen extends ConsumerWidget {
  const ProfileGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ActiveProfileState state = ref.watch(activeProfileControllerProvider);
    final CinevaMetrics metrics = CinevaMetrics.of(context);
    final List<MemberProfileModel> profiles = state.profiles;

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
                  Text('Qui regarde ?', style: CinevaTypography.heroTitle),
                  const SizedBox(height: CinevaSpacing.xs),
                  Text(
                    'Choisissez votre profil. Chacun garde sa propre liste et sa '
                    'reprise de lecture, sur le même abonnement.',
                    style: CinevaTypography.bodyCompact,
                  ),
                  if (state.error != null) ...<Widget>[
                    const SizedBox(height: CinevaSpacing.md),
                    CinevaStatusBanner(
                      title: 'Profils indisponibles',
                      message: state.error!,
                      tone: CinevaBannerTone.error,
                    ),
                    const SizedBox(height: CinevaSpacing.md),
                    CinevaSecondaryButton(
                      label: 'Continuer sans profil',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () => context.go(SessionRouteResolver.userHome),
                    ),
                  ],
                  const SizedBox(height: CinevaSpacing.xl),
                  if (state.isLoading && profiles.isEmpty)
                    Wrap(
                      spacing: CinevaSpacing.md,
                      runSpacing: CinevaSpacing.md,
                      children: List<Widget>.generate(
                        3,
                        (int index) => const CinevaSkeleton(width: 92, height: 116),
                      ),
                    )
                  else
                    Wrap(
                      spacing: CinevaSpacing.md,
                      runSpacing: CinevaSpacing.md,
                      children: <Widget>[
                        for (final MemberProfileModel profile in profiles)
                          _GateProfileCard(
                            profile: profile,
                            onTap: () => _select(context, ref, profile),
                          ),
                        if (state.canAddProfile)
                          _GateAddCard(
                            enabled: !state.isSaving,
                            onTap: () => showProfileFormSheet(context, ref),
                          ),
                      ],
                    ),
                  const SizedBox(height: CinevaSpacing.xl),
                  Text(
                    '${profiles.length} profil(s) sur ${CinevaOffer.maxProfiles} · '
                    '${CinevaOffer.maxDevices} appareils · ${CinevaOffer.priceLabel}',
                    style: CinevaTypography.meta,
                  ),
                  const SizedBox(height: CinevaSpacing.sm),
                  CinevaListTile(
                    icon: Icons.tune_rounded,
                    title: 'Gérer les profils',
                    subtitle: 'Noms, avatars, suppression',
                    dense: true,
                    onTap: () => context.push(SessionRouteResolver.profileManage),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    MemberProfileModel profile,
  ) async {
    await ref.read(activeProfileControllerProvider.notifier).selectProfile(profile.id);
    if (!context.mounted) return;
    // Le redirect du routeur sort du sas dès qu'un profil est actif ; ce
    // `go` explicite couvre le cas où le routeur n'aurait pas été rafraîchi.
    if (ref.read(activeProfileControllerProvider).activeProfileId == profile.id) {
      context.go(SessionRouteResolver.userHome);
    }
  }
}

/// Carte d'un profil dans le sas : avatar, nom, repère enfant.
class _GateProfileCard extends StatelessWidget {
  const _GateProfileCard({required this.profile, required this.onTap});

  final MemberProfileModel profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CinevaPressable(
      onTap: onTap,
      semanticLabel: 'Regarder avec le profil ${profile.name}',
      child: SizedBox(
        width: 92,
        child: Column(
          children: <Widget>[
            ProfileAvatar(profile: profile, size: 74),
            const SizedBox(height: CinevaSpacing.xs),
            Text(
              profile.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: CinevaTypography.cardTitle.copyWith(fontSize: 13.5),
            ),
            if (profile.isKid)
              Text(
                'Enfant',
                textAlign: TextAlign.center,
                style: CinevaTypography.meta.copyWith(fontSize: 10.5),
              ),
          ],
        ),
      ),
    );
  }
}

/// Carte « Ajouter un profil » dans le sas.
class _GateAddCard extends StatelessWidget {
  const _GateAddCard({required this.onTap, this.enabled = true});

  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return CinevaPressable(
      onTap: enabled ? onTap : null,
      semanticLabel: 'Ajouter un profil',
      child: SizedBox(
        width: 92,
        child: Column(
          children: <Widget>[
            Container(
              width: 74,
              height: 74,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: CinevaColors.veilStrong,
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                size: 28,
                color: CinevaColors.textSoft,
              ),
            ),
            const SizedBox(height: CinevaSpacing.xs),
            Text(
              'Ajouter',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: CinevaTypography.cardTitle.copyWith(fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}
