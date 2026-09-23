import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../library/active_profile_controller.dart';

/// Ouvre la feuille de création / modification d'un profil membre.
///
/// Partagée par le sas « Qui regarde ? » et l'écran « Profils du foyer » : un
/// seul formulaire, un seul comportement, quel que soit le point d'entrée.
Future<void> showProfileFormSheet(
  BuildContext context,
  WidgetRef ref, {
  MemberProfileModel? existing,
}) {
  return showCinevaSheet<void>(
    context: context,
    isDismissible: !ref.read(activeProfileControllerProvider).isSaving,
    builder: (BuildContext sheetContext) => _ProfileFormSheet(existing: existing),
  );
}

/// Pastille d'un profil : icône choisie par l'utilisateur, couleur du foyer.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, this.size = 42});

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

/// Formulaire : nom, avatar, couleur, profil enfant.
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

  bool get _isEditing => widget.existing != null && !widget.existing!.isDraft;

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
              child: ProfileAvatar(
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
