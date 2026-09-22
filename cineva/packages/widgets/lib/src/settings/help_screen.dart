import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'settings_scaffold.dart';

/// Aide & contact (route `/settings/help`).
///
/// Réponses aux questions fréquentes, copie de l'adresse de support dans le
/// presse-papiers (aucun lancement d'application externe n'est disponible dans
/// cette cible) et accès à la confidentialité.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const String supportEmail = 'support@cineva.app';

  @override
  Widget build(BuildContext context) {
    final CinevaMetrics metrics = CinevaMetrics.of(context);

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
              title: 'Aide',
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/profile'),
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
                  Text('Aide & contact',
                      style: CinevaTypography.screenTitle.copyWith(fontSize: 21)),
                  const SizedBox(height: CinevaSpacing.xs),
                  Text(
                    'Les réponses aux questions les plus fréquentes sur Cineva.',
                    style: CinevaTypography.bodyCompact,
                  ),
                  const SizedBox(height: CinevaSpacing.xl),
                  const CinevaSectionHeader(title: 'Questions fréquentes'),
                  ..._faq.entries
                      .map((MapEntry<String, String> entry) => _FaqItem(entry: entry)),
                  const SizedBox(height: CinevaSpacing.lg),
                  const CinevaSectionHeader(title: 'Contact'),
                  SettingsGroup(
                    children: <Widget>[
                      CinevaListTile(
                        icon: Icons.mail_outline_rounded,
                        title: 'Copier l’adresse de support',
                        subtitle: supportEmail,
                        showChevron: false,
                        onTap: () => _copyEmail(context),
                      ),
                      const CinevaHairline(indent: 52),
                      CinevaListTile(
                        icon: Icons.verified_user_outlined,
                        title: 'Confidentialité',
                        subtitle: 'Données, historique et analyses',
                        onTap: () => context.push('/settings/privacy'),
                      ),
                      const CinevaHairline(indent: 52),
                      CinevaListTile(
                        icon: Icons.notifications_active_outlined,
                        title: 'Notifications',
                        subtitle: 'Nouveautés, téléchargements, rappels',
                        onTap: () => context.push('/settings/notifications'),
                      ),
                    ],
                  ),
                  const SizedBox(height: CinevaSpacing.xl),
                  Center(
                    child: Column(
                      children: <Widget>[
                        const CinevaWordmark(style: CinevaTypography.brandSmall),
                        const SizedBox(height: CinevaSpacing.xs),
                        Text('Version 1.0.0', style: CinevaTypography.meta),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: supportEmail));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          duration: Duration(milliseconds: 1800),
          content: Text('Adresse copiée dans le presse-papiers'),
        ),
      );
  }
}

const Map<String, String> _faq = <String, String>{
  'Comment télécharger un film ou un épisode ?':
      'Ouvrez la fiche du contenu puis appuyez sur « Télécharger » sous l’affiche. '
      'Pour une série, chaque épisode dispose de son propre bouton de téléchargement. '
      'Suivez la progression dans l’onglet Téléchargements.',
  'Puis-je regarder hors ligne ?':
      'Oui. Un téléchargement terminé est marqué « Disponible hors ligne » et se lance '
      'sans connexion depuis l’onglet Téléchargements.',
  'Comment choisir la qualité vidéo ?':
      'Dans Profil → Audio & Vidéo, la qualité globale s’applique à toutes les lectures. '
      'Pendant une lecture, le menu Qualité propose les résolutions publiées pour ce titre.',
  'Pourquoi la lecture s’arrête-t-elle sur un nouvel appareil ?':
      'Votre abonnement limite le nombre d’appareils simultanés. Déconnectez un appareil '
      'depuis Profil → Appareils pour libérer une place.',
  'Comment reprendre là où je m’étais arrêté ?':
      'La progression est enregistrée automatiquement. Retrouvez-la dans Bibliothèque → '
      'Reprendre, ou directement sur la fiche du titre.',
  'Cineva Vision et Cineva Audio, à quoi ça sert ?':
      'Cineva Vision adapte l’image aux capacités de votre écran ; Cineva Audio traite le '
      'son en temps réel (dialogues, basses, spatialisation). Les deux se règlent dans '
      'Profil → Audio & Vidéo.',
};

class _FaqItem extends StatefulWidget {
  const _FaqItem({required this.entry});

  final MapEntry<String, String> entry;

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CinevaSpacing.xs),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CinevaColors.surface,
          borderRadius: BorderRadius.circular(CinevaRadii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CinevaPressable(
              pressedScale: 0.995,
              onTap: () => setState(() => _open = !_open),
              semanticLabel: widget.entry.key,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CinevaSpacing.md,
                  vertical: CinevaSpacing.sm + 2,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        widget.entry.key,
                        style: CinevaTypography.cardTitle.copyWith(fontSize: 13.5),
                      ),
                    ),
                    const SizedBox(width: CinevaSpacing.sm),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: CinevaMotion.medium,
                      curve: CinevaCurve.decelerate,
                      child: const Icon(
                        Icons.expand_more_rounded,
                        size: 18,
                        color: CinevaColors.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: CinevaMotion.medium,
              curve: CinevaCurve.decelerate,
              alignment: Alignment.topCenter,
              child: _open
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(
                        CinevaSpacing.md,
                        0,
                        CinevaSpacing.md,
                        CinevaSpacing.md,
                      ),
                      child: Text(widget.entry.value, style: CinevaTypography.bodyCompact),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

