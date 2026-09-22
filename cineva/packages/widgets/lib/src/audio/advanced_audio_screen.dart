import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../settings/settings_scaffold.dart';
import 'audio_engine_controller.dart';

const List<String> _eqBandLabels = <String>[
  'Sub-bass · 45 Hz',
  'Bass · 90 Hz',
  'Bas-médium · 300 Hz',
  'Médium · 1,2 kHz',
  'Haut-médium · 3,5 kHz',
  'Aigu · 10 kHz',
];

/// Réglages DSP avancés : égaliseur 6 bandes, crossover, shelf sub-bass,
/// réverbération et plafond du limiteur true-peak.
///
/// Chaque curseur écrit réellement dans [CinevaAudioAdvancedSettings] via
/// l'[AudioEngineController] (persistance + push des paramètres au backend).
class AdvancedAudioScreen extends ConsumerWidget {
  const AdvancedAudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AudioEngineUiState audio = ref.watch(audioEngineControllerProvider);
    final CinevaAudioSettings settings = audio.settings;
    final AudioEngineController controller =
        ref.read(audioEngineControllerProvider.notifier);
    final CinevaAudioAdvancedSettings advanced =
        settings.advanced ?? CinevaAudioAdvancedSettings.defaults();
    Future<void> apply(CinevaAudioAdvancedSettings next) =>
        controller.updateAdvanced(next);

    final double maxGain = advanced.eqBandGains.fold<double>(
      0,
      (double max, double gain) => gain.abs() > max ? gain.abs() : max,
    );

    return SettingsScreenScaffold(
      title: 'Audio avancé',
      subtitle: 'Égaliseur, bass management, ambiance et protection true-peak.',
      children: <Widget>[
        if (!audio.backendAvailable)
          const Padding(
            padding: EdgeInsets.only(bottom: CinevaSpacing.md),
            child: CinevaStatusBanner(
              title: 'Moteur indisponible',
              message:
                  'Cet appareil n’expose pas de traitement audio : les réglages sont enregistrés mais n’ont pas d’effet ici.',
              tone: CinevaBannerTone.warning,
            ),
          ),
        SettingsGroupHeader(
          title: 'Égaliseur 6 bandes',
          value: '${_db(maxGain)} max',
        ),
        SettingsGroup(
          children: <Widget>[
            CinevaSwitchTile(
              icon: Icons.equalizer_rounded,
              title: 'Égaliseur actif',
              value: advanced.eqEnabled,
              onChanged: (bool value) => apply(advanced.copyWith(eqEnabled: value)),
            ),
            const CinevaHairline(indent: 52),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CinevaSpacing.md,
                CinevaSpacing.xs,
                CinevaSpacing.md,
                CinevaSpacing.sm,
              ),
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < _eqBandLabels.length; i++)
                    CinevaSliderTile(
                      label: _eqBandLabels[i],
                      value: i < advanced.eqBandGains.length ? advanced.eqBandGains[i] : 0,
                      min: -15,
                      max: 15,
                      enabled: advanced.eqEnabled,
                      valueLabel: _db(
                        i < advanced.eqBandGains.length ? advanced.eqBandGains[i] : 0,
                      ),
                      onChanged: (double gain) {
                        final List<double> gains =
                            List<double>.from(advanced.eqBandGains);
                        while (gains.length < _eqBandLabels.length) {
                          gains.add(0);
                        }
                        gains[i] = gain;
                        apply(advanced.copyWith(eqBandGains: gains));
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
        const SettingsGroupHeader(title: 'Bass management'),
        SettingsGroup(
          padding: const EdgeInsets.symmetric(
            horizontal: CinevaSpacing.md,
            vertical: CinevaSpacing.sm,
          ),
          children: <Widget>[
            CinevaSliderTile(
              icon: Icons.speaker_rounded,
              label: 'Fréquence de crossover',
              value: advanced.crossoverHz,
              min: 50,
              max: 160,
              valueLabel: '${advanced.crossoverHz.round()} Hz',
              // Pas de 5 Hz : identique aux 22 divisions d'origine.
              onChanged: (double value) =>
                  apply(advanced.copyWith(crossoverHz: (value / 5).round() * 5.0)),
            ),
            CinevaSliderTile(
              icon: Icons.trending_down_rounded,
              label: 'Shelf sub-bass',
              value: advanced.subShelfGainDb,
              min: -6,
              max: 9,
              valueLabel: _db(advanced.subShelfGainDb),
              onChanged: (double value) =>
                  apply(advanced.copyWith(subShelfGainDb: value)),
            ),
          ],
        ),
        const SettingsGroupHeader(title: 'Ambiance & protection'),
        SettingsGroup(
          padding: const EdgeInsets.symmetric(
            horizontal: CinevaSpacing.md,
            vertical: CinevaSpacing.sm,
          ),
          children: <Widget>[
            CinevaSliderTile(
              icon: Icons.meeting_room_rounded,
              label: 'Réverbération (room)',
              value: advanced.roomWetPercent,
              min: 0,
              max: 15,
              valueLabel: '${_decimals(advanced.roomWetPercent)} %',
              onChanged: (double value) =>
                  apply(advanced.copyWith(roomWetPercent: value)),
            ),
            CinevaSliderTile(
              icon: Icons.speed_rounded,
              label: 'Plafond du limiteur',
              value: advanced.limiterCeilingDb,
              min: -6,
              max: 0,
              valueLabel: '${_decimals(advanced.limiterCeilingDb)} dBFS',
              onChanged: (double value) =>
                  apply(advanced.copyWith(limiterCeilingDb: value)),
            ),
          ],
        ),
        if (settings.advanced != null)
          Padding(
            padding: const EdgeInsets.only(top: CinevaSpacing.sm),
            child: CinevaSecondaryButton(
              label: 'Revenir aux valeurs du profil',
              icon: Icons.restart_alt_rounded,
              height: 46,
              onPressed: controller.updateAdvancedReset,
            ),
          ),
      ],
    );
  }

  /// « +3,0 dB » / « −1,5 dB » — signe explicite, virgule décimale.
  static String _db(double value) {
    final String sign = value > 0 ? '+' : (value < 0 ? '−' : '');
    return '$sign${_decimals(value.abs())} dB';
  }

  static String _decimals(double value) =>
      value.toStringAsFixed(1).replaceAll('.', ',');
}
