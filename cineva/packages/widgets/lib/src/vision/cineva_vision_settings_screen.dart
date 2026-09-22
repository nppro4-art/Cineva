import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_services/cineva_services.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../settings/settings_scaffold.dart';
import 'vision_controller.dart';

/// Qualité d'image — Cineva Vision.
///
/// Analyse réelle de l'appareil ([DeviceCapabilities]) appliquée au rendu :
/// profils, options matériellement supportées, aperçu avant/après construit
/// par [CinevaVisionService.buildRenderProfile] et persistance des réglages.
class CinevaVisionSettingsScreen extends ConsumerWidget {
  const CinevaVisionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VisionState state = ref.watch(visionControllerProvider);
    final VisionController controller = ref.read(visionControllerProvider.notifier);
    final CinevaVisionService visionService = ref.read(cinevaVisionServiceProvider);

    final DeviceCapabilities? capabilities = state.capabilities;
    final CinevaVisionSettings? settings = state.settings;

    return SettingsScreenScaffold(
      title: 'Cineva Vision',
      subtitle: 'Profils d’image, analyse automatique de l’appareil et aperçu du rendu.',
      actions: <Widget>[
        if (state.isSaving)
          const Padding(
            padding: EdgeInsets.only(right: CinevaSpacing.md),
            child: CinevaSpinner(size: 18),
          ),
      ],
      children: state.isLoading || !state.ready || capabilities == null || settings == null
          ? const <Widget>[
              CinevaSkeleton(height: 132),
              SizedBox(height: CinevaSpacing.md),
              CinevaSkeleton(height: 220),
              SizedBox(height: CinevaSpacing.md),
              CinevaSkeleton(height: 96),
              SizedBox(height: CinevaSpacing.md),
              CinevaSkeleton(height: 96),
            ]
          : <Widget>[
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: CinevaSpacing.md),
                  child: CinevaStatusBanner(
                    title: 'Synchronisation partielle',
                    message: state.errorMessage!,
                    tone: CinevaBannerTone.warning,
                  ),
                ),
              _RecommendationCard(
                capabilities: capabilities,
                settings: settings,
                onApplyRecommended: controller.applyRecommended,
                onAutoChanged: controller.setAutoRecommended,
              ),
              const SizedBox(height: CinevaSpacing.md),
              _VisionPreviewCard(
                capabilities: capabilities,
                settings: settings,
                visionService: visionService,
              ),
              const SizedBox(height: CinevaSpacing.lg),
              const SettingsGroupHeader(title: 'Profils Cineva Vision'),
              SettingsGroup(
                children: CinevaVisionProfile.values
                    .where((CinevaVisionProfile profile) =>
                        profile != CinevaVisionProfile.custom)
                    .map(
                      (CinevaVisionProfile profile) => SettingsOption<CinevaVisionProfile>(
                        value: profile,
                        label: profile.label,
                        subtitle: profile.description,
                        selected: settings.profile == profile,
                        onSelected: controller.setProfile,
                      ),
                    )
                    .toList(),
              ),
              const SettingsGroupHeader(title: 'Options avancées'),
              SettingsGroup(
                children: <Widget>[
                  _option(
                    context,
                    label: 'Netteté intelligente',
                    subtitle: 'Renforce légèrement la lisibilité des textures.',
                    value: settings.options.smartSharpness,
                    supported: capabilities.smartSharpnessSupported,
                    onChanged: (bool value) => controller.updateOptions(
                      settings.options.copyWith(smartSharpness: value),
                    ),
                  ),
                  _divider(),
                  _option(
                    context,
                    label: 'Couleurs renforcées',
                    subtitle: 'Accentue légèrement la saturation pour un rendu plus riche.',
                    value: settings.options.enhancedColors,
                    supported: capabilities.enhancedColorsSupported,
                    onChanged: (bool value) => controller.updateOptions(
                      settings.options.copyWith(enhancedColors: value),
                    ),
                  ),
                  _divider(),
                  _option(
                    context,
                    label: 'Contraste dynamique',
                    subtitle: 'Ajuste le contraste global pour renforcer la profondeur.',
                    value: settings.options.dynamicContrast,
                    supported: capabilities.dynamicContrastSupported,
                    onChanged: (bool value) => controller.updateOptions(
                      settings.options.copyWith(dynamicContrast: value),
                    ),
                  ),
                  _divider(),
                  _option(
                    context,
                    label: 'Réduction du bruit',
                    subtitle: 'Prépare la chaîne de rendu à lisser les artefacts visibles.',
                    value: settings.options.noiseReduction,
                    supported: capabilities.noiseReductionSupported,
                    onChanged: (bool value) => controller.updateOptions(
                      settings.options.copyWith(noiseReduction: value),
                    ),
                  ),
                  _divider(),
                  _option(
                    context,
                    label: 'Fluidité avancée',
                    subtitle: 'Activable seulement si l’écran et l’appareil le permettent.',
                    value: settings.options.advancedSmoothness,
                    supported: capabilities.advancedSmoothnessSupported,
                    onChanged: (bool value) => controller.updateOptions(
                      settings.options.copyWith(advancedSmoothness: value),
                    ),
                  ),
                  _divider(),
                  _option(
                    context,
                    label: 'HDR optimisé',
                    subtitle: 'Optimise les hautes lumières quand le matériel le permet.',
                    value: settings.options.optimizedHdr,
                    supported: capabilities.optimizedHdrSupported,
                    onChanged: (bool value) => controller.updateOptions(
                      settings.options.copyWith(optimizedHdr: value),
                    ),
                  ),
                  _divider(),
                  _option(
                    context,
                    label: 'Amélioration IA',
                    subtitle: 'Architecture bêta prête pour des traitements intelligents.',
                    value: settings.options.aiEnhancement,
                    supported: capabilities.aiEnhancementSupported,
                    onChanged: (bool value) => controller.updateOptions(
                      settings.options.copyWith(aiEnhancement: value),
                    ),
                  ),
                ],
              ),
              const SettingsGroupHeader(title: 'Réglages appliqués'),
              _AppliedSettingsCard(capabilities: capabilities, settings: settings),
              const SizedBox(height: CinevaSpacing.md),
              const SettingsGroupHeader(title: 'Analyse de l’appareil'),
              _DeviceCapabilitiesCard(capabilities: capabilities),
            ],
    );
  }

  static Widget _divider() => const CinevaHairline(indent: 52);

  /// Option matérielle : grisée et non modifiable si l'appareil ne la supporte
  /// pas (jamais de réglage qui ne fait rien en silence).
  static Widget _option(
    BuildContext context, {
    required String label,
    required String subtitle,
    required bool value,
    required bool supported,
    required ValueChanged<bool> onChanged,
  }) {
    return CinevaSwitchTile(
      title: label,
      subtitle: supported ? subtitle : '$subtitle — non pris en charge ici.',
      value: supported ? value : false,
      enabled: supported,
      onChanged: supported ? onChanged : null,
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.capabilities,
    required this.settings,
    required this.onApplyRecommended,
    required this.onAutoChanged,
  });

  final DeviceCapabilities capabilities;
  final CinevaVisionSettings settings;
  final VoidCallback onApplyRecommended;
  final ValueChanged<bool> onAutoChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CinevaColors.card,
        gradient: CinevaScrims.profileHeader,
        borderRadius: BorderRadius.circular(CinevaRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CinevaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.auto_awesome_rounded, size: 17, color: CinevaColors.gold),
                const SizedBox(width: CinevaSpacing.xs),
                Expanded(
                  child: Text(
                    'Mode ${capabilities.recommendedModeLabel} recommandé',
                    style: CinevaTypography.cardTitle.copyWith(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: CinevaSpacing.xs),
            Text(
              '${settings.profile.label} · ${capabilities.performanceTier.label} · '
              '${capabilities.displayTechnology.label}',
              style: CinevaTypography.meta.copyWith(fontSize: 11.5),
            ),
            const SizedBox(height: CinevaSpacing.sm),
            CinevaSwitchTile(
              title: 'Recommandation automatique',
              subtitle: 'Cineva ajuste le profil selon les capacités détectées.',
              value: settings.autoRecommended,
              onChanged: onAutoChanged,
            ),
            const SizedBox(height: CinevaSpacing.xs),
            CinevaSecondaryButton(
              label: 'Appliquer le mode recommandé',
              icon: Icons.bolt_rounded,
              height: 44,
              onPressed: onApplyRecommended,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppliedSettingsCard extends StatelessWidget {
  const _AppliedSettingsCard({required this.capabilities, required this.settings});

  final DeviceCapabilities capabilities;
  final CinevaVisionSettings settings;

  @override
  Widget build(BuildContext context) {
    final List<String> applied = <String>[
      settings.profile.label,
      if (settings.options.smartSharpness) 'Netteté intelligente',
      if (settings.options.enhancedColors) 'Couleurs renforcées',
      if (settings.options.dynamicContrast) 'Contraste dynamique',
      if (settings.options.noiseReduction) 'Réduction du bruit',
      if (settings.options.advancedSmoothness && capabilities.advancedSmoothnessSupported)
        'Fluidité avancée',
      if (settings.options.optimizedHdr && capabilities.optimizedHdrSupported) 'HDR optimisé',
      if (settings.options.aiEnhancement && capabilities.aiEnhancementSupported)
        'Amélioration IA',
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: CinevaColors.surface,
        borderRadius: BorderRadius.circular(CinevaRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CinevaSpacing.md),
        child: Wrap(
          spacing: CinevaSpacing.xs,
          runSpacing: CinevaSpacing.xs,
          children: applied
              .map((String label) => CinevaChip(label: label, dense: true))
              .toList(),
        ),
      ),
    );
  }
}

class _DeviceCapabilitiesCard extends StatelessWidget {
  const _DeviceCapabilitiesCard({required this.capabilities});

  final DeviceCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, String>> entries = <MapEntry<String, String>>[
      MapEntry<String, String>('Plateforme', capabilities.platform.toUpperCase()),
      MapEntry<String, String>('Système', capabilities.operatingSystemVersion),
      MapEntry<String, String>(
        'Écran',
        '${capabilities.screenWidth.round()} × ${capabilities.screenHeight.round()}',
      ),
      MapEntry<String, String>('Résolution', capabilities.resolutionLabel),
      MapEntry<String, String>(
        'Fréquence',
        '${capabilities.refreshRate.toStringAsFixed(0)} Hz',
      ),
      MapEntry<String, String>('Technologie', capabilities.displayTechnology.label),
      MapEntry<String, String>('Niveau', capabilities.performanceTier.label),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: CinevaColors.surface,
        borderRadius: BorderRadius.circular(CinevaRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CinevaSpacing.md,
          vertical: CinevaSpacing.sm,
        ),
        child: Column(
          children: entries
              .map(
                (MapEntry<String, String> entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: CinevaSpacing.xs + 1),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          entry.key,
                          style: CinevaTypography.meta.copyWith(fontSize: 12),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          entry.value,
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CinevaTypography.numeric.copyWith(
                            fontSize: 12,
                            color: CinevaColors.textHigh,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

/// Aperçu avant/après : le rendu réel produit par le service Vision, comparé
/// au rendu par défaut, avec un séparateur draggable.
class _VisionPreviewCard extends StatefulWidget {
  const _VisionPreviewCard({
    required this.capabilities,
    required this.settings,
    required this.visionService,
  });

  final DeviceCapabilities capabilities;
  final CinevaVisionSettings settings;
  final CinevaVisionService visionService;

  @override
  State<_VisionPreviewCard> createState() => _VisionPreviewCardState();
}

class _VisionPreviewCardState extends State<_VisionPreviewCard> {
  double _divider = 0.55;

  @override
  Widget build(BuildContext context) {
    final CinevaVisionRenderProfile base = widget.visionService.buildRenderProfile(
      settings: CinevaVisionSettings.defaults(),
      capabilities: widget.capabilities,
    );
    final CinevaVisionRenderProfile current = widget.visionService.buildRenderProfile(
      settings: widget.settings,
      capabilities: widget.capabilities,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: CinevaColors.surface,
        borderRadius: BorderRadius.circular(CinevaRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CinevaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Aperçu', style: CinevaTypography.overline.copyWith(color: CinevaColors.gold)),
            const SizedBox(height: CinevaSpacing.xs),
            Text(
              'Comparez l’image standard au rendu ${widget.settings.profile.label}.',
              style: CinevaTypography.bodyCompact.copyWith(fontSize: 12),
            ),
            const SizedBox(height: CinevaSpacing.sm),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double split = constraints.maxWidth * _divider;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(CinevaRadii.small),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        _PreviewPanel(profile: base, label: 'Avant'),
                        ClipRect(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            widthFactor: _divider,
                            child: _PreviewPanel(profile: current, label: 'Après'),
                          ),
                        ),
                        Positioned(
                          left: split - 1,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 2,
                            color: CinevaColors.gold.withOpacity(0.85),
                          ),
                        ),
                        Positioned(
                          left: split - 17,
                          top: constraints.maxHeight / 2 - 17,
                          child: GestureDetector(
                            onHorizontalDragUpdate: (DragUpdateDetails details) {
                              setState(() {
                                _divider =
                                    (_divider + (details.delta.dx / constraints.maxWidth))
                                        .clamp(0.1, 0.9)
                                        .toDouble();
                              });
                            },
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: CinevaColors.gold,
                                shape: BoxShape.circle,
                                boxShadow: CinevaShadows.card,
                              ),
                              child: const Icon(
                                Icons.drag_indicator_rounded,
                                size: 18,
                                color: CinevaColors.textOnLight,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: CinevaSpacing.sm),
            Text(
              'Rendu ${widget.settings.profile.label} · recommandé : '
              '${widget.capabilities.recommendedModeLabel}',
              style: CinevaTypography.meta.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.profile, required this.label});

  final CinevaVisionRenderProfile profile;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color accent = CinevaColors.gold
        .withOpacity((0.10 + profile.overlayOpacity).clamp(0.08, 0.34).toDouble());

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.lerp(
              const Color(0xFF1A2230),
              const Color(0xFF3B2E1C),
              ((profile.saturation - 1).clamp(0, 0.2) / 0.2).toDouble(),
            )!,
            Color.lerp(
              const Color(0xFF0B0D12),
              const Color(0xFF171B22),
              ((profile.contrast - 1).clamp(0, 0.25) / 0.25).toDouble(),
            )!,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.white.withOpacity(
                    (profile.brightness + 0.03).clamp(0.0, 0.08).toDouble(),
                  ),
                  Colors.transparent,
                  Colors.black.withOpacity(profile.shadowBoost.clamp(0.0, 0.18).toDouble()),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[accent, Colors.transparent],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(CinevaSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x99000000),
                    borderRadius: BorderRadius.circular(CinevaRadii.hair),
                  ),
                  child: Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 8.5,
                      height: 1.2,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: CinevaColors.textHigh,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Radiant City',
                  style: CinevaTypography.sectionTitle.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Aperçu du rendu Cineva Vision',
                  style: CinevaTypography.meta.copyWith(
                    fontSize: 10.5,
                    color: CinevaColors.textSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
