import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_services/cineva_services.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

class CinevaVisionSettingsScreen extends ConsumerWidget {
  const CinevaVisionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(visionControllerProvider);
    final controller = ref.read(visionControllerProvider.notifier);

    final visionService = ref.read(cinevaVisionServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Qualité d’image — Cineva Vision')),
      body: CinevaScaffoldContainer(
        child: state.isLoading || !state.ready
            ? const CinevaLoadingView(label: 'Analyse de l’appareil et chargement des préférences...')
            : ListView(
                children: <Widget>[
                  CinevaPageHeader(
                    title: 'Cineva Vision',
                    subtitle:
                        'Profils d’image premium, analyse automatique de l’appareil et options avancées évolutives.',
                    trailing: state.isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),
                  const SizedBox(height: CinevaSpacing.xl),
                  if (state.errorMessage != null) ...<Widget>[
                    CinevaStatusBanner(
                      title: 'Synchronisation partielle',
                      message: state.errorMessage!,
                      tone: CinevaBannerTone.warning,
                    ),
                    const SizedBox(height: CinevaSpacing.lg),
                  ],
                  _RecommendationCard(
                    capabilities: state.capabilities!,
                    settings: state.settings!,
                    onApplyRecommended: controller.applyRecommended,
                    onAutoChanged: controller.setAutoRecommended,
                  ),
                  const SizedBox(height: CinevaSpacing.xl),
                  _VisionPreviewCard(
                    capabilities: state.capabilities!,
                    settings: state.settings!,
                    visionService: visionService,
                  ),
                  const SizedBox(height: CinevaSpacing.xl),
                  _AppliedSettingsCard(
                    capabilities: state.capabilities!,
                    settings: state.settings!,
                  ),
                  const SizedBox(height: CinevaSpacing.xl),
                  const CinevaSectionTitle(title: 'Profils Cineva Vision'),
                  const SizedBox(height: CinevaSpacing.md),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: CinevaVisionProfile.values
                        .where((profile) => profile != CinevaVisionProfile.custom)
                        .map(
                          (profile) => _ProfileCard(
                            profile: profile,
                            selected: state.settings!.profile == profile,
                            onTap: () => controller.setProfile(profile),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: CinevaSpacing.xxl),
                  const CinevaSectionTitle(title: 'Options avancées'),
                  const SizedBox(height: CinevaSpacing.md),
                  _OptionTile(
                    label: 'Netteté intelligente',
                    subtitle: 'Renforce légèrement la lisibilité des textures sans surpromesse.',
                    value: state.settings!.options.smartSharpness,
                    supported: state.capabilities!.smartSharpnessSupported,
                    onChanged: (value) => controller.updateOptions(
                      state.settings!.options.copyWith(smartSharpness: value),
                    ),
                  ),
                  _OptionTile(
                    label: 'Couleurs renforcées',
                    subtitle: 'Accentue légèrement la saturation pour un rendu plus riche.',
                    value: state.settings!.options.enhancedColors,
                    supported: state.capabilities!.enhancedColorsSupported,
                    onChanged: (value) => controller.updateOptions(
                      state.settings!.options.copyWith(enhancedColors: value),
                    ),
                  ),
                  _OptionTile(
                    label: 'Contraste dynamique',
                    subtitle: 'Ajuste le contraste global pour renforcer la profondeur visuelle.',
                    value: state.settings!.options.dynamicContrast,
                    supported: state.capabilities!.dynamicContrastSupported,
                    onChanged: (value) => controller.updateOptions(
                      state.settings!.options.copyWith(dynamicContrast: value),
                    ),
                  ),
                  _OptionTile(
                    label: 'Réduction du bruit',
                    subtitle: 'Prépare la chaîne de rendu à lisser les artefacts visibles.',
                    value: state.settings!.options.noiseReduction,
                    supported: state.capabilities!.noiseReductionSupported,
                    onChanged: (value) => controller.updateOptions(
                      state.settings!.options.copyWith(noiseReduction: value),
                    ),
                  ),
                  _OptionTile(
                    label: 'Fluidité avancée',
                    subtitle: 'Activable seulement si l’écran et l’appareil le permettent.',
                    value: state.settings!.options.advancedSmoothness,
                    supported: state.capabilities!.advancedSmoothnessSupported,
                    onChanged: (value) => controller.updateOptions(
                      state.settings!.options.copyWith(advancedSmoothness: value),
                    ),
                  ),
                  _OptionTile(
                    label: 'HDR optimisé',
                    subtitle: 'Optimise l’apparence des hautes lumières quand le matériel le supporte.',
                    value: state.settings!.options.optimizedHdr,
                    supported: state.capabilities!.optimizedHdrSupported,
                    onChanged: (value) => controller.updateOptions(
                      state.settings!.options.copyWith(optimizedHdr: value),
                    ),
                  ),
                  _OptionTile(
                    label: 'Amélioration IA',
                    subtitle: 'Architecture bêta prête pour des traitements intelligents ultérieurs.',
                    value: state.settings!.options.aiEnhancement,
                    supported: state.capabilities!.aiEnhancementSupported,
                    onChanged: (value) => controller.updateOptions(
                      state.settings!.options.copyWith(aiEnhancement: value),
                    ),
                  ),
                  const SizedBox(height: CinevaSpacing.xxl),
                  _DeviceCapabilitiesCard(capabilities: state.capabilities!),
                ],
              ),
      ),
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
    return CinevaGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Mode ${capabilities.recommendedModeLabel} recommandé pour votre appareil.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: CinevaSpacing.sm),
          Text(
            'Profil actuel : ${settings.profile.label} • ${capabilities.performanceTier.label} • ${capabilities.displayTechnology.label}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted),
          ),
          const SizedBox(height: CinevaSpacing.lg),
          SwitchListTile.adaptive(
            value: settings.autoRecommended,
            onChanged: onAutoChanged,
            contentPadding: EdgeInsets.zero,
            title: const Text('Utiliser la recommandation automatique'),
            subtitle: const Text('Cineva ajuste automatiquement le profil selon les capacités détectées.'),
          ),
          const SizedBox(height: CinevaSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: CinevaPrimaryButton(
              label: 'Appliquer le mode recommandé',
              icon: Icons.auto_awesome_rounded,
              onPressed: onApplyRecommended,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final CinevaVisionProfile profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: InkWell(
        borderRadius: BorderRadius.circular(CinevaRadii.medium),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(CinevaSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CinevaRadii.medium),
            border: Border.all(
              color: selected ? CinevaColors.accentSoft : CinevaColors.border,
              width: selected ? 1.4 : 1,
            ),
            gradient: LinearGradient(
              colors: <Color>[
                (selected ? CinevaColors.accentSoft : Colors.white).withOpacity(selected ? 0.13 : 0.03),
                Colors.white.withOpacity(0.01),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(profile.label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: CinevaSpacing.sm),
              Text(
                profile.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.supported,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final bool value;
  final bool supported;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CinevaSpacing.md),
      child: CinevaGlassCard(
        child: SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: Text(
            supported ? subtitle : '$subtitle\nNon disponible sur cet appareil.',
          ),
          value: supported ? value : false,
          onChanged: supported ? onChanged : null,
        ),
      ),
    );
  }
}


class _AppliedSettingsCard extends StatelessWidget {
  const _AppliedSettingsCard({
    required this.capabilities,
    required this.settings,
  });

  final DeviceCapabilities capabilities;
  final CinevaVisionSettings settings;

  @override
  Widget build(BuildContext context) {
    final applied = <String>[
      'Profil : ${settings.profile.label}',
      if (settings.options.smartSharpness) 'Netteté intelligente',
      if (settings.options.enhancedColors) 'Couleurs renforcées',
      if (settings.options.dynamicContrast) 'Contraste dynamique',
      if (settings.options.noiseReduction) 'Réduction du bruit',
      if (settings.options.advancedSmoothness && capabilities.advancedSmoothnessSupported) 'Fluidité avancée',
      if (settings.options.optimizedHdr && capabilities.optimizedHdrSupported) 'HDR optimisé',
      if (settings.options.aiEnhancement && capabilities.aiEnhancementSupported) 'Amélioration IA',
    ];

    return CinevaGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const CinevaSectionTitle(title: 'Réglages appliqués'),
          const SizedBox(height: CinevaSpacing.md),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: applied.map((label) => Chip(label: Text(label))).toList(),
          ),
        ],
      ),
    );
  }
}

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
    final base = widget.visionService.buildRenderProfile(
      settings: CinevaVisionSettings.defaults(),
      capabilities: widget.capabilities,
    );
    final current = widget.visionService.buildRenderProfile(
      settings: widget.settings,
      capabilities: widget.capabilities,
    );

    return CinevaGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const CinevaSectionTitle(title: 'Aperçu Cineva Vision'),
          const SizedBox(height: CinevaSpacing.sm),
          Text(
            'Comparez l’image standard avec le rendu ${widget.settings.profile.label} avant de poursuivre.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted),
          ),
          const SizedBox(height: CinevaSpacing.lg),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final split = constraints.maxWidth * _divider;
                return Stack(
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
                      child: Container(width: 2, color: Colors.white.withOpacity(0.85)),
                    ),
                    Positioned(
                      left: split - 18,
                      top: constraints.maxHeight / 2 - 18,
                      child: GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            _divider = (_divider + (details.delta.dx / constraints.maxWidth)).clamp(0.1, 0.9).toDouble();
                          });
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withOpacity(0.22),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.drag_indicator_rounded, color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: CinevaSpacing.md),
          Text(
            'Mode ${widget.settings.profile.label} recommandé pour votre appareil : ${widget.capabilities.recommendedModeLabel}.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
          ),
        ],
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
    final accent = CinevaColors.accentSoft.withOpacity((0.15 + profile.overlayOpacity).clamp(0.12, 0.4));
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CinevaRadii.medium),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.lerp(const Color(0xFF4338CA), const Color(0xFF9333EA), (profile.saturation - 1).clamp(0, 0.2) / 0.2)!,
            Color.lerp(const Color(0xFF0F172A), const Color(0xFF1F2937), (profile.contrast - 1).clamp(0, 0.25) / 0.25)!,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Colors.white.withOpacity((profile.brightness + 0.03).clamp(0.0, 0.08)),
                  Colors.transparent,
                  Colors.black.withOpacity(profile.shadowBoost.clamp(0.0, 0.18)),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
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
            padding: const EdgeInsets.all(CinevaSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Chip(label: Text(label)),
                const Spacer(),
                Text('Radiant City', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  'Aperçu visuel du rendu Cineva Vision.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textPrimary.withOpacity(0.9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceCapabilitiesCard extends StatelessWidget {
  const _DeviceCapabilitiesCard({required this.capabilities});

  final DeviceCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final entries = <MapEntry<String, String>>[
      MapEntry('Plateforme', capabilities.platform.toUpperCase()),
      MapEntry('Système', capabilities.operatingSystemVersion),
      MapEntry('Écran', '${capabilities.screenWidth.round()} × ${capabilities.screenHeight.round()}'),
      MapEntry('Résolution', capabilities.resolutionLabel),
      MapEntry('Fréquence', '${capabilities.refreshRate.toStringAsFixed(0)} Hz'),
      MapEntry('Technologie', capabilities.displayTechnology.label),
      MapEntry('Niveau', capabilities.performanceTier.label),
    ];

    return CinevaGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const CinevaSectionTitle(title: 'Analyse automatique de l’appareil'),
          const SizedBox(height: CinevaSpacing.md),
          Wrap(
            spacing: CinevaSpacing.md,
            runSpacing: CinevaSpacing.md,
            children: entries
                .map(
                  (entry) => SizedBox(
                    width: 260,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: CinevaColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(CinevaRadii.small),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(CinevaSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(entry.key, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: CinevaColors.textMuted)),
                            const SizedBox(height: 6),
                            Text(entry.value, style: Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
