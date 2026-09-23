import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../library/active_profile_controller.dart';
import '../library/library_controller.dart';

/// Profil Cineva (route `/profile`).
///
/// Remplace l'ancien écran « Compte » : identité, abonnement, raccourcis vers
/// la bibliothèque et les téléchargements, lecture (Audio & Vidéo, Cineva
/// Vision), compte (appareils, confidentialité, aide) et déconnexion.
/// Toutes les données viennent de la session et des contrôleurs existants.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CinevaMetrics metrics = CinevaMetrics.of(context);
    final AsyncValue<SessionSnapshot> sessionAsync =
        ref.watch(sessionControllerProvider);
    final SessionSnapshot? session = sessionAsync.valueOrNull;
    final AppUser? user = session?.user;

    if (sessionAsync.isLoading && user == null) {
      return const _ProfileSkeleton();
    }
    if (user == null) {
      return _NoSession(
        message: session?.message ?? 'Aucune session active.',
      );
    }

    final AppSettingsModel settings =
        ref.watch(settingsControllerProvider).valueOrNull ?? user.settings;
    final LibraryState library = ref.watch(libraryControllerProvider);
    final ActiveProfileState memberProfiles = ref.watch(activeProfileControllerProvider);
    final String visionLabel = ref.watch(visionControllerProvider).settings?.profile.label ??
        settings.visionSettings.profile.label;

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
              title: 'Profil',
              onBack: () => _back(context),
              actions: <Widget>[
                CinevaIconButton(
                  icon: Icons.refresh_rounded,
                  filled: false,
                  tooltip: 'Actualiser la session',
                  onPressed: () async {
                    await ref
                        .read(sessionControllerProvider.notifier)
                        .refresh(showLoader: false);
                    await ref.read(settingsControllerProvider.notifier).load();
                  },
                ),
              ],
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
                  _IdentityCard(
                    user: user,
                    onEditName: () => _showDisplayNameSheet(context, ref, user),
                  ),
                  const SizedBox(height: CinevaSpacing.md),
                  _StatsCard(
                    user: user,
                    visionLabel: visionLabel,
                    deviceCount: session?.devices.length ?? 0,
                  ),
                  const SizedBox(height: CinevaSpacing.xl),
                  CinevaTileGroup(
                    title: 'Bibliothèque',
                    children: <Widget>[
                      CinevaListTile(
                        icon: Icons.playlist_add_check_rounded,
                        title: 'Ma liste',
                        subtitle: library.favoriteIds.isEmpty
                            ? 'Aucun titre enregistré'
                            : '${library.favoriteIds.length} titre(s)',
                        onTap: () => context.go('/library'),
                      ),
                      CinevaListTile(
                        icon: Icons.play_circle_outline_rounded,
                        title: 'Reprendre',
                        subtitle: library.continueWatching.isEmpty
                            ? 'Aucune lecture en cours'
                            : '${library.continueWatching.length} lecture(s)',
                        onTap: () => context.go('/library?tab=resume'),
                      ),
                      CinevaListTile(
                        icon: Icons.download_for_offline_outlined,
                        title: 'Téléchargements',
                        subtitle: library.downloads.isEmpty
                            ? 'Rien sur cet appareil'
                            : '${library.downloads.length} élément(s)',
                        onTap: () => context.go('/downloads'),
                      ),
                    ],
                  ),
                  CinevaTileGroup(
                    title: 'Lecture',
                    children: <Widget>[
                      CinevaListTile(
                        icon: Icons.tune_rounded,
                        title: 'Audio & Vidéo',
                        subtitle:
                            '${settings.videoQuality.toUpperCase()} · sous-titres '
                            '${settings.subtitlesEnabled ? 'activés' : 'désactivés'} · '
                            '${settings.audioSettings.profile.label}',
                        onTap: () => context.push('/settings/audio-video'),
                      ),
                      CinevaListTile(
                        icon: Icons.auto_awesome_rounded,
                        title: 'Cineva Vision',
                        subtitle: visionLabel,
                        onTap: () => context.push('/settings/cineva-vision'),
                      ),
                      CinevaListTile(
                        icon: Icons.translate_rounded,
                        title: 'Langue',
                        subtitle: settings.language.toUpperCase(),
                        onTap: () => context.push('/settings/language'),
                      ),
                      CinevaListTile(
                        icon: Icons.palette_outlined,
                        title: 'Apparence',
                        subtitle: settings.themeMode.label,
                        onTap: () => context.push('/settings/theme'),
                      ),
                      CinevaListTile(
                        icon: Icons.notifications_active_outlined,
                        title: 'Notifications',
                        subtitle: settings.notificationPreferences.enabled
                            ? 'Activées'
                            : 'Désactivées',
                        onTap: () => context.push('/settings/notifications'),
                      ),
                    ],
                  ),
                  CinevaTileGroup(
                    title: 'Compte',
                    children: <Widget>[
                      // Offre réelle : 15 €/mois, 5 appareils, 5 profils, et les
                      // coordonnées pour régler (Revolut ou en main propre).
                      CinevaListTile(
                        icon: Icons.payments_outlined,
                        title: 'Abonnement & paiement',
                        subtitle: '${CinevaOffer.priceLabel} · ${CinevaOffer.maxDevices} appareils '
                            '· ${CinevaOffer.maxProfiles} profils',
                        onTap: () => context.push('/account/subscription'),
                      ),
                      CinevaListTile(
                        icon: Icons.group_outlined,
                        title: 'Profils du foyer',
                        subtitle: memberProfiles.hasProfiles
                            ? '${memberProfiles.activeProfileName} · '
                                '${memberProfiles.profiles.length}/${CinevaOffer.maxProfiles} profils'
                            : 'Créer un profil pour chaque membre',
                        onTap: () => context.push('/account/profiles'),
                      ),
                      CinevaListTile(
                        icon: Icons.devices_other_outlined,
                        title: 'Appareils',
                        subtitle: (session?.devices.length ?? 0) == 1
                            ? '1 appareil connecté'
                            : '${session?.devices.length ?? 0} appareils connectés',
                        trailing: session?.deviceLimitReached ?? false
                            ? const _LimitBadge()
                            : null,
                        onTap: () => context.push('/account/devices'),
                      ),
                      CinevaListTile(
                        icon: Icons.verified_user_outlined,
                        title: 'Confidentialité',
                        subtitle: settings.privacyPreferences.analyticsEnabled
                            ? 'Analyses activées'
                            : 'Analyses désactivées',
                        onTap: () => context.push('/settings/privacy'),
                      ),
                      CinevaListTile(
                        icon: Icons.help_outline_rounded,
                        title: 'Aide & contact',
                        onTap: () => context.push('/settings/help'),
                      ),
                      CinevaListTile(
                        icon: Icons.settings_outlined,
                        title: 'Tous les paramètres',
                        onTap: () => context.push('/settings'),
                      ),
                    ],
                  ),
                  const SizedBox(height: CinevaSpacing.sm),
                  CinevaSecondaryButton(
                    label: 'Se déconnecter',
                    icon: Icons.logout_rounded,
                    tone: CinevaButtonTone.danger,
                    onPressed: () => _signOut(context, ref),
                  ),
                  const SizedBox(height: CinevaSpacing.md),
                  const Center(
                    child: Text('Cineva · version 1.0', style: CinevaTypography.meta),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/home');
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final bool confirmed = await CinevaDialog.show(
      context,
      title: 'Se déconnecter',
      message: 'Vous devrez saisir à nouveau vos identifiants sur cet appareil.',
      confirmLabel: 'Se déconnecter',
      cancelLabel: 'Annuler',
      icon: Icons.logout_rounded,
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(sessionControllerProvider.notifier).signOut();
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.user, required this.onEditName});

  final AppUser user;

  /// Ouvre la feuille « Nom affiché » : le nom visible dans l'app est un
  /// pseudonyme modifiable, pas l'état civil de l'abonné.
  final VoidCallback onEditName;

  @override
  Widget build(BuildContext context) {
    final bool active = user.hasActiveSubscription;

    return CinevaPressable(
      onTap: onEditName,
      semanticLabel: 'Modifier le nom affiché (${user.fullName})',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CinevaColors.card,
          gradient: CinevaScrims.profileHeader,
          borderRadius: BorderRadius.circular(CinevaRadii.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(CinevaSpacing.lg),
          child: Row(
            children: <Widget>[
              CinevaAvatar(
                imagePath: user.avatarPath,
                initials: CinevaContentLabels.initials(user.fullName),
                size: 60,
                ring: true,
              ),
              const SizedBox(width: CinevaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CinevaTypography.sectionTitle.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      CinevaIdentifier.displayName(user.email),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CinevaTypography.meta.copyWith(fontSize: 11.5),
                    ),
                    const SizedBox(height: CinevaSpacing.sm),
                    _SubscriptionPill(
                      active: active,
                      label: user.subscriptionExpiresAt == null
                          ? ''
                          : user.subscriptionExpiresLabel,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CinevaSpacing.sm),
              const Icon(
                Icons.edit_rounded,
                size: 18,
                color: CinevaColors.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriptionPill extends StatelessWidget {
  const _SubscriptionPill({required this.active, required this.label});

  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color color = active ? CinevaColors.success : CinevaColors.warning;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            active
                ? (label.isEmpty ? 'Abonnement actif' : 'Actif · $label')
                : 'Abonnement expiré',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CinevaTypography.meta.copyWith(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.user,
    required this.visionLabel,
    required this.deviceCount,
  });

  final AppUser user;
  final String visionLabel;
  final int deviceCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CinevaColors.surface,
        borderRadius: BorderRadius.circular(CinevaRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CinevaSpacing.md),
        child: Row(
          children: <Widget>[
            _Stat(
              icon: Icons.calendar_month_rounded,
              value: user.subscriptionExpiresAt == null
                  ? '—'
                  : user.subscriptionExpiresLabel,
              label: 'Expiration',
            ),
            _Stat(
              icon: Icons.timelapse_rounded,
              value: user.subscriptionExpiresAt == null
                  ? '—'
                  : '${user.daysRemaining} j',
              label: 'Restants',
            ),
            _Stat(
              icon: Icons.devices_other_outlined,
              value: '$deviceCount',
              label: 'Appareils',
            ),
            _Stat(
              icon: Icons.auto_awesome_rounded,
              value: visionLabel,
              label: 'Vision',
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Icon(icon, size: 15, color: CinevaColors.gold),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                value,
                maxLines: 1,
                style: CinevaTypography.numeric.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: CinevaColors.textHigh,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CinevaTypography.meta.copyWith(fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}

class _LimitBadge extends StatelessWidget {
  const _LimitBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: CinevaColors.warning.withOpacity(0.14),
        borderRadius: BorderRadius.circular(CinevaRadii.hair),
      ),
      child: const Text(
        'LIMITE',
        style: TextStyle(
          fontSize: 8.5,
          height: 1.2,
          letterSpacing: 0.7,
          fontWeight: FontWeight.w700,
          color: CinevaColors.warning,
        ),
      ),
    );
  }
}

class _NoSession extends StatelessWidget {
  const _NoSession({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CinevaColors.ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CinevaSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CinevaIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                filled: false,
                tooltip: 'Retour',
                onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
              ),
              const SizedBox(height: CinevaSpacing.xxl),
              const Icon(Icons.person_outline_rounded,
                  size: 28, color: CinevaColors.textFaint),
              const SizedBox(height: CinevaSpacing.md),
              Text('Aucune session', style: CinevaTypography.screenTitle),
              const SizedBox(height: CinevaSpacing.xs),
              Text(message, style: CinevaTypography.body),
              const SizedBox(height: CinevaSpacing.xl),
              CinevaPlayButton(
                label: 'Se connecter',
                icon: Icons.login_rounded,
                expanded: false,
                onPressed: () => context.go('/login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    final double gutter = CinevaMetrics.of(context).gutter;

    return Scaffold(
      backgroundColor: CinevaColors.ink,
      body: SafeArea(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.all(gutter),
          children: <Widget>[
            const CinevaSkeleton(height: 52),
            const SizedBox(height: CinevaSpacing.lg),
            const CinevaSkeleton(height: 96),
            const SizedBox(height: CinevaSpacing.md),
            const CinevaSkeleton(height: 78),
            const SizedBox(height: CinevaSpacing.xl),
            ...List<Widget>.generate(
              7,
              (int index) => const Padding(
                padding: EdgeInsets.only(bottom: CinevaSpacing.sm),
                child: CinevaSkeleton(height: 52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Feuille « Nom affiché » : le pseudonyme visible dans l'app.
///
/// Le nom affiché est décoratif (en-tête du Profil, initiales de l'avatar sur
/// l'accueil) : l'abonné peut y mettre « Dupont » ou n'importe quel pseudo, et
/// le changer quand il veut. Son identifiant de connexion ne bouge pas.
Future<void> _showDisplayNameSheet(
  BuildContext context,
  WidgetRef ref,
  AppUser user,
) {
  return showCinevaSheet<void>(
    context: context,
    builder: (BuildContext sheetContext) => _DisplayNameSheet(user: user),
  );
}

class _DisplayNameSheet extends ConsumerStatefulWidget {
  const _DisplayNameSheet({required this.user});

  final AppUser user;

  @override
  ConsumerState<_DisplayNameSheet> createState() => _DisplayNameSheetState();
}

class _DisplayNameSheetState extends ConsumerState<_DisplayNameSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.user.fullName);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _controller.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) {
      setState(() => _error = 'Choisissez un nom à afficher.');
      return;
    }
    if (name.length > 60) {
      setState(() => _error = 'Le nom affiché doit contenir au plus 60 caractères.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).updateFullName(fullName: name);
      // La session est la source du nom affiché : on la rafraîchit pour que
      // l'en-tête et les initiales de l'accueil suivent immédiatement.
      await ref.read(sessionControllerProvider.notifier).refresh(showLoader: false);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Nom affiché mis à jour.')));
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = failure.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Enregistrement impossible : $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CinevaSheetContainer(
      title: 'Nom affiché',
      subtitle: 'Visible uniquement dans l’app (en-tête du profil, initiales de '
          'l’avatar). Votre identifiant de connexion ne change pas.',
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
            CinevaTextField(
              controller: _controller,
              label: 'Pseudonyme',
              hint: 'Ex. Dupont',
              prefixIcon: Icons.badge_outlined,
              textInputAction: TextInputAction.done,
              onChanged: (String value) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: CinevaSpacing.md),
              CinevaStatusBanner(
                message: _error!,
                tone: CinevaBannerTone.error,
              ),
            ],
            const SizedBox(height: CinevaSpacing.lg),
            CinevaPrimaryButton(
              label: 'Enregistrer',
              icon: Icons.check_rounded,
              isLoading: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: CinevaSpacing.sm),
            CinevaSecondaryButton(
              label: 'Utiliser mon identifiant',
              icon: Icons.alternate_email_rounded,
              onPressed: _saving
                  ? null
                  : () => setState(() {
                        _controller.text =
                            CinevaIdentifier.displayName(widget.user.email);
                        _error = null;
                      }),
            ),
          ],
        ),
      ),
    );
  }
}
