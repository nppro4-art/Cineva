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

/// Profils du foyer (route `/account/profiles`).
///
/// Un abonnement couvre [CinevaOffer.maxProfiles] profils : chacun garde sa
/// liste de favoris et sa reprise de lecture. Le profil choisi ici devient le
/// profil actif de **cet appareil** — les autres appareils du foyer gardent le
/// leur.
class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ActiveProfileState state = ref.watch(activeProfileControllerProvider);
    final ActiveProfileController controller = ref.read(activeProfileControllerProvider.notifier);
    final CinevaMetrics metrics = CinevaMetrics.of(context);
    final List<MemberProfileModel> profiles = state.profiles;

    return Scaffold(
      backgroundColor: CinevaColors.ink,
      body: RefreshIndicator(
        onRefresh: controller.load,
        color: CinevaColors.gold,
        backgroundColor: CinevaColors.raised,
        edgeOffset: 96,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
            decelerationRate: ScrollDecelerationRate.fast,
          ),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: CinevaTopBar(
                title: 'Profils',
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
                    Text(
                      '${profiles.length} sur ${CinevaOffer.maxProfiles} profils',
                      style: CinevaTypography.screenTitle.copyWith(fontSize: 21),
                    ),
                    const SizedBox(height: CinevaSpacing.xs),
                    Text(
                      'Un seul abonnement pour tout le foyer. Chaque profil a sa '
                      'liste et sa reprise de lecture ; le profil choisi ici '
                      's’applique à cet appareil.',
                      style: CinevaTypography.bodyCompact,
                    ),
                    if (state.error != null) ...<Widget>[
                      const SizedBox(height: CinevaSpacing.md),
                      CinevaStatusBanner(
                        title: 'Profils indisponibles',
                        message: state.error!,
                        tone: CinevaBannerTone.error,
                      ),
                    ],
                    const SizedBox(height: CinevaSpacing.lg),
                    if (state.isLoading && profiles.isEmpty)
                      ...List<Widget>.generate(
                        2,
                        (int index) => const Padding(
                          padding: EdgeInsets.only(bottom: CinevaSpacing.sm),
                          child: CinevaSkeleton(height: 68),
                        ),
                      )
                    else if (profiles.isEmpty)
                      const _EmptyProfiles()
                    else
                      ...profiles.map<Widget>(
                        (MemberProfileModel profile) => Padding(
                          padding: const EdgeInsets.only(bottom: CinevaSpacing.sm),
                          child: _ProfileRow(
                            profile: profile,
                            isActive: profile.id == state.activeProfileId,
                            onTap: () => _select(context, ref, profile),
                            onMore: () => _showActions(context, ref, profile),
                          ),
                        ),
                      ),
                    const SizedBox(height: CinevaSpacing.lg),
                    CinevaPrimaryButton(
                      label: 'Ajouter un profil',
                      icon: Icons.person_add_alt_1_rounded,
                      isLoading: state.isSaving,
                      onPressed: state.canAddProfile
                          ? () => showProfileFormSheet(context, ref)
                          : null,
                    ),
                    if (!state.canAddProfile) ...<Widget>[
                      const SizedBox(height: CinevaSpacing.sm),
                      const CinevaStatusBanner(
                        title: 'Limite atteinte',
                        message: 'Cet abonnement couvre 5 profils. Supprimez-en un '
                            'pour en créer un autre.',
                        tone: CinevaBannerTone.warning,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
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
    _notify(context, 'Profil « ${profile.name} » actif sur cet appareil');
  }

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    MemberProfileModel profile,
  ) async {
    final bool isActive =
        ref.read(activeProfileControllerProvider).activeProfileId == profile.id;

    await showCinevaSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) => CinevaSheetContainer(
        title: profile.name,
        subtitle: isActive
            ? 'Profil actif sur cet appareil'
            : 'Ce profil n’est pas utilisé sur cet appareil',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (!isActive)
              CinevaSheetAction(
                icon: Icons.check_rounded,
                label: 'Utiliser ce profil',
                tone: CinevaButtonTone.gold,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _select(context, ref, profile);
                },
              ),
            CinevaSheetAction(
              icon: Icons.edit_outlined,
              label: 'Modifier',
              subtitle: 'Nom, avatar, couleur, profil enfant',
              onTap: () {
                Navigator.of(sheetContext).pop();
                showProfileFormSheet(context, ref, existing: profile);
              },
            ),
            CinevaSheetAction(
              icon: Icons.delete_outline_rounded,
              label: 'Supprimer',
              subtitle: 'Sa liste et sa reprise seront effacées',
              tone: CinevaButtonTone.danger,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDelete(context, ref, profile);
              },
            ),
            const SizedBox(height: CinevaSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MemberProfileModel profile,
  ) async {
    await showCinevaSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) => CinevaSheetContainer(
        title: 'Supprimer « ${profile.name} » ?',
        subtitle: 'Les favoris et la reprise de lecture de ce profil seront '
            'définitivement effacés. L’abonnement et les autres profils ne '
            'changent pas.',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CinevaSheetAction(
              icon: Icons.delete_forever_rounded,
              label: 'Supprimer définitivement',
              tone: CinevaButtonTone.danger,
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final bool done = await ref
                    .read(activeProfileControllerProvider.notifier)
                    .deleteProfile(profile.id);
                if (!context.mounted) return;
                _notify(context, done ? 'Profil supprimé' : 'Suppression impossible');
              },
            ),
            CinevaSheetAction(
              icon: Icons.close_rounded,
              label: 'Annuler',
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
            const SizedBox(height: CinevaSpacing.sm),
          ],
        ),
      ),
    );
  }

  void _notify(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Ligne de profil : avatar coloré, nom, état, accès aux actions.
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.profile,
    required this.isActive,
    required this.onTap,
    required this.onMore,
  });

  final MemberProfileModel profile;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return CinevaPressable(
      onTap: onTap,
      semanticLabel: isActive
          ? 'Profil ${profile.name}, actif'
          : 'Utiliser le profil ${profile.name}',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: CinevaSpacing.md,
          vertical: CinevaSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: CinevaColors.raised,
          borderRadius: BorderRadius.circular(CinevaRadii.card),
        ),
        child: Row(
          children: <Widget>[
            ProfileAvatar(profile: profile),
            const SizedBox(width: CinevaSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    profile.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CinevaTypography.cardTitle.copyWith(fontSize: 14.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isActive
                        ? 'Profil actif sur cet appareil'
                        : (profile.isKid ? 'Profil enfant' : 'Toucher pour l’utiliser'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CinevaTypography.bodyCompact.copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ),
            if (profile.isKid && isActive)
              const Padding(
                padding: EdgeInsets.only(right: CinevaSpacing.xxs),
                child: Icon(Icons.child_care_rounded, size: 18, color: CinevaColors.textFaint),
              ),
            // Le profil actif reste modifiable et supprimable : la coche et le
            // menu d'actions cohabitent.
            if (isActive)
              const Padding(
                padding: EdgeInsets.only(right: CinevaSpacing.xxs),
                child: Icon(Icons.check_circle_rounded, size: 20, color: CinevaColors.gold),
              ),
            CinevaPressable(
              onTap: onMore,
              pressedScale: 0.9,
              semanticLabel: 'Actions du profil ${profile.name}',
              child: const Padding(
                padding: EdgeInsets.all(CinevaSpacing.xs),
                child: Icon(
                  Icons.more_horiz_rounded,
                  size: 20,
                  color: CinevaColors.textFaint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aucun profil : explication courte, sans culpabiliser.
class _EmptyProfiles extends StatelessWidget {
  const _EmptyProfiles();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CinevaSpacing.lg),
      decoration: BoxDecoration(
        color: CinevaColors.raised,
        borderRadius: BorderRadius.circular(CinevaRadii.card),
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.group_outlined, size: 30, color: CinevaColors.textFaint),
          const SizedBox(height: CinevaSpacing.sm),
          Text(
            'Aucun profil pour le moment',
            style: CinevaTypography.cardTitle.copyWith(fontSize: 14.5),
          ),
          const SizedBox(height: CinevaSpacing.xxs),
          Text(
            'Créez le premier profil : un « Profil principal » suffit pour '
            'commencer, les autres membres du foyer pourront avoir le leur.',
            textAlign: TextAlign.center,
            style: CinevaTypography.bodyCompact,
          ),
        ],
      ),
    );
  }
}
