import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

const List<String> _eqBandLabels = <String>[
  'Sub-bass (45 Hz)',
  'Bass (90 Hz)',
  'Bas-médium (300 Hz)',
  'Médium (1,2 kHz)',
  'Haut-médium (3,5 kHz)',
  'Aigu (10 kHz)',
];

/// Réglages DSP avancés : égaliseur 6 bandes, crossover, shelf sub-bass,
/// réverbération et plafond du limiteur.
class AdvancedAudioScreen extends ConsumerWidget {
  const AdvancedAudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioEngineControllerProvider);
    final settings = audio.settings;
    final controller = ref.read(audioEngineControllerProvider.notifier);
    final CinevaAudioAdvancedSettings advanced =
        settings.advanced ?? CinevaAudioAdvancedSettings.defaults();

    Future<void> apply(CinevaAudioAdvancedSettings next) async {
      await controller.updateAdvanced(next);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Audio avancé')),
      body: CinevaScaffoldContainer(
        child: ListView(
          children: <Widget>[
            const CinevaPageHeader(
              title: 'Réglages avancés',
              subtitle: 'Égaliseur, crossover, shelf sub-bass, réverbération et limiteur true-peak.',
            ),
            const SizedBox(height: CinevaSpacing.xl),
            CinevaGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(child: CinevaSectionTitle(title: 'Égaliseur 6 bandes')),
                      Text(
                        '${advanced.eqBandGains.fold<double>(0, (m, g) => g.abs() > m ? g.abs() : m).toStringAsFixed(1)} dB max',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: CinevaColors.textMuted),
                      ),
                    ],
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Égaliseur actif'),
                    value: advanced.eqEnabled,
                    onChanged: (enabled) => apply(advanced.copyWith(eqEnabled: enabled)),
                  ),
                  for (int i = 0; i < _eqBandLabels.length; i++)
                    _DbSlider(
                      label: _eqBandLabels[i],
                      value: i < advanced.eqBandGains.length ? advanced.eqBandGains[i] : 0,
                      min: -15,
                      max: 15,
                      onChanged: (gain) {
                        final List<double> gains = List<double>.from(advanced.eqBandGains);
                        while (gains.length < 6) {
                          gains.add(0);
                        }
                        gains[i] = gain;
                        apply(advanced.copyWith(eqBandGains: gains));
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: CinevaSpacing.lg),
            CinevaGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const CinevaSectionTitle(title: 'Bass management'),
                  const SizedBox(height: CinevaSpacing.md),
                  _UnitSlider(
                    label: 'Fréquence de crossover',
                    suffix: ' Hz',
                    value: advanced.crossoverHz,
                    min: 50,
                    max: 160,
                    divisions: 22,
                    display: advanced.crossoverHz.round().toString(),
                    onChanged: (v) => apply(advanced.copyWith(crossoverHz: v)),
                  ),
                  _UnitSlider(
                    label: 'Shelf sub-bass',
                    suffix: ' dB',
                    value: advanced.subShelfGainDb,
                    min: -6,
                    max: 9,
                    display: '${advanced.subShelfGainDb.toStringAsFixed(1)}',
                    onChanged: (v) => apply(advanced.copyWith(subShelfGainDb: v)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CinevaSpacing.lg),
            CinevaGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const CinevaSectionTitle(title: 'Ambiance & protection'),
                  const SizedBox(height: CinevaSpacing.md),
                  _UnitSlider(
                    label: 'Réverbération (room)',
                    suffix: ' %',
                    value: advanced.roomWetPercent,
                    min: 0,
                    max: 15,
                    display: advanced.roomWetPercent.toStringAsFixed(1),
                    onChanged: (v) => apply(advanced.copyWith(roomWetPercent: v)),
                  ),
                  _UnitSlider(
                    label: 'Plafond du limiteur',
                    suffix: ' dBFS',
                    value: advanced.limiterCeilingDb,
                    min: -6,
                    max: 0,
                    display: advanced.limiterCeilingDb.toStringAsFixed(1),
                    onChanged: (v) => apply(advanced.copyWith(limiterCeilingDb: v)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CinevaSpacing.lg),
            if (settings.advanced != null)
              Padding(
                padding: const EdgeInsets.only(bottom: CinevaSpacing.xl),
                child: OutlinedButton.icon(
                  onPressed: controller.updateAdvancedReset,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Revenir aux valeurs du profil'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DbSlider extends StatelessWidget {
  const _DbSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CinevaSpacing.lg),
          child: Row(
            children: <Widget>[
              Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
              Text(
                '${value > 0 ? '+' : ''}${value.toStringAsFixed(1)} dB',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: CinevaColors.accentSoft),
              ),
            ],
          ),
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: 30,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _UnitSlider extends StatelessWidget {
  const _UnitSlider({
    required this.label,
    required this.suffix,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
    this.divisions,
  });

  final String label;
  final String suffix;
  final double value;
  final double min;
  final double max;
  final String display;
  final int? divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CinevaSpacing.lg),
          child: Row(
            children: <Widget>[
              Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
              Text(
                '$display$suffix',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: CinevaColors.accentSoft),
              ),
            ],
          ),
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
