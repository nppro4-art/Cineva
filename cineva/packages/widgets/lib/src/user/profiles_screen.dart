import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../library/active_profile_controller.dart';

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
                          ? () => _showForm(context, ref)
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
                _showForm(context, ref, existing: profile);
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

  Future<void> _showForm(
    BuildContext context,
    WidgetRef ref, {
    MemberProfileModel? existing,
  }) async {
    await showCinevaSheet<void>(
      context: context,
      isDismissible: !ref.read(activeProfileControllerProvider).isSaving,
      builder: (BuildContext sheetContext) => _ProfileFormSheet(existing: existing),
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
            _ProfileAvatar(profile: profile),
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
                padding: EdgeInsets.only(right: CinevaSpacing.xs),
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

/// Pastille du profil : icône choisie par l'utilisateur, couleur du foyer.
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profile, this.size = 42});

  final MemberProfileModel profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color color = profileColorOf(profile.colorKey);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.16),
      ),
      child: Icon(
        profileAvatarIconOf(profile.avatarKey),
        size: size * 0.52,
        color: color,
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

/// Formulaire de création / modification d'un profil.
class _ProfileFormSheet extends ConsumerStatefulWidget {
  const _ProfileFormSheet({this.existing});

  final MemberProfileModel? existing;

  @override
  ConsumerState<_ProfileFormSheet> createState() => _ProfileFormSheetState();
}

class _ProfileFormSheetState extends ConsumerState<_ProfileFormSheet> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.existing?.name ?? '');
  late String _avatarKey = widget.existing?.avatarKey ?? MemberProfileModel.defaultAvatarKey;
  late String _colorKey = widget.existing?.colorKey ?? MemberProfileModel.defaultColorKey;
  late bool _isKid = widget.existing?.isKid ?? false;

  bool get _isEditing => widget.existing != null && !(widget.existing!.isDraft);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ActiveProfileController controller =
        ref.read(activeProfileControllerProvider.notifier);
    final String name = MemberProfileModel.normalizeName(_nameController.text);
    if (name.isEmpty) {
      _notify('Donnez un nom au profil.');
      return;
    }

    final bool done = _isEditing
        ? await controller.updateProfile(
            widget.existing!.copyWith(
              name: name,
              avatarKey: _avatarKey,
              colorKey: _colorKey,
              isKid: _isKid,
            ),
          )
        : await controller.createProfile(
            name: name,
            avatarKey: _avatarKey,
            colorKey: _colorKey,
            isKid: _isKid,
          );

    if (!mounted) return;
    if (done) {
      Navigator.of(context).pop();
      return;
    }
    _notify(ref.read(activeProfileControllerProvider).error ?? 'Enregistrement impossible.');
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bool isSaving = ref.watch(
      activeProfileControllerProvider.select((ActiveProfileState state) => state.isSaving),
    );

    return CinevaSheetContainer(
      title: _isEditing ? 'Modifier le profil' : 'Nouveau profil',
      subtitle: _isEditing
          ? 'Nom, avatar et couleur de ${widget.existing!.name}'
          : '${CinevaOffer.maxProfiles} profils maximum sur cet abonnement',
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: CinevaSpacing.md,
          right: CinevaSpacing.md,
          bottom: CinevaSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Center(
              child: _ProfileAvatar(
                profile: MemberProfileModel(
                  id: widget.existing?.id ?? '',
                  accountId: widget.existing?.accountId ?? '',
                  name: _nameController.text.isEmpty ? 'Nouveau' : _nameController.text,
                  avatarKey: _avatarKey,
                  colorKey: _colorKey,
                ),
                size: 62,
              ),
            ),
            const SizedBox(height: CinevaSpacing.md),
            CinevaTextField(
              controller: _nameController,
              label: 'Nom du profil',
              hint: 'Noah',
              textInputAction: TextInputAction.done,
              onChanged: (String value) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: CinevaSpacing.lg),
            Text('Avatar', style: CinevaTypography.sectionTitle),
            const SizedBox(height: CinevaSpacing.xs),
            Wrap(
              spacing: CinevaSpacing.sm,
              runSpacing: CinevaSpacing.sm,
              children: <Widget>[
                for (final String key in MemberProfileModel.avatarChoices)
                  _ChoiceDot(
                    selected: key == _avatarKey,
                    color: profileColorOf(_colorKey),
                    onTap: () => setState(() => _avatarKey = key),
                    semanticLabel: 'Avatar $key',
                    child: Icon(profileAvatarIconOf(key), size: 20),
                  ),
              ],
            ),
            const SizedBox(height: CinevaSpacing.lg),
            Text('Couleur', style: CinevaTypography.sectionTitle),
            const SizedBox(height: CinevaSpacing.xs),
            Wrap(
              spacing: CinevaSpacing.sm,
              runSpacing: CinevaSpacing.sm,
              children: <Widget>[
                for (final String key in MemberProfileModel.colorChoices)
                  _ChoiceDot(
                    selected: key == _colorKey,
                    color: profileColorOf(key),
                    onTap: () => setState(() => _colorKey = key),
                    semanticLabel: 'Couleur $key',
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: profileColorOf(key),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: CinevaSpacing.lg),
            Row(
              children: <Widget>[
                const Icon(Icons.child_care_rounded, size: 20, color: CinevaColors.textSoft),
                const SizedBox(width: CinevaSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Profil enfant', style: CinevaTypography.cardTitle.copyWith(fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        'Repère visuel pour un usage partagé avec un enfant.',
                        style: CinevaTypography.bodyCompact.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                CinevaSwitch(
                  value: _isKid,
                  onChanged: (bool value) => setState(() => _isKid = value),
                ),
              ],
            ),
            const SizedBox(height: CinevaSpacing.xl),
            CinevaPrimaryButton(
              label: _isEditing ? 'Enregistrer' : 'Créer le profil',
              icon: _isEditing ? Icons.check_rounded : Icons.person_add_alt_1_rounded,
              isLoading: isSaving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pastille de choix (avatar ou couleur) dans le formulaire.
class _ChoiceDot extends StatelessWidget {
  const _ChoiceDot({
    required this.selected,
    required this.color,
    required this.onTap,
    required this.child,
    required this.semanticLabel,
  });

  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final Widget child;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return CinevaPressable(
      onTap: onTap,
      pressedScale: 0.92,
      semanticLabel: semanticLabel,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? color.withOpacity(0.22) : CinevaColors.veilStrong,
          border: selected ? Border.all(color: color, width: 1.6) : null,
        ),
        child: DefaultTextStyle(
          style: TextStyle(color: selected ? color : CinevaColors.textSoft),
          child: IconTheme(
            data: IconThemeData(color: selected ? color : CinevaColors.textSoft, size: 20),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Icône d'un avatar de profil (clés stables stockées en base).
IconData profileAvatarIconOf(String key) {
  return switch (key) {
    'star' => Icons.star_rounded,
    'clap' => Icons.movie_creation_outlined,
    'rocket' => Icons.rocket_launch_rounded,
    'mask' => Icons.theater_comedy_rounded,
    'reel' => Icons.video_library_rounded,
    _ => Icons.local_movies_rounded,
  };
}

/// Couleur d'un profil (clés stables stockées en base).
Color profileColorOf(String key) {
  return switch (key) {
    'violet' => CinevaColors.accentSoft,
    'emerald' => CinevaColors.success,
    'sky' => CinevaColors.info,
    'rose' => CinevaColors.danger,
    'amber' => CinevaColors.warning,
    _ => CinevaColors.gold,
  };
}
