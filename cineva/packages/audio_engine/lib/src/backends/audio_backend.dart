/// Abstraction des backends audio du Cineva Audio Engine.
///
/// Un backend est responsable du branchement RÉEL du moteur dans le chemin
/// audio de la plateforme (après décodage PCM, avant la sortie). Un backend
/// qui ne peut pas réellement traiter l'audio doit déclarer
/// `canProcess = false` : l'UI ne prétend jamais le contraire.
library;

import 'package:equatable/equatable.dart';

/// Capacités d'un backend sur la plateforme courante.
class AudioBackendCapabilities extends Equatable {
  const AudioBackendCapabilities({
    required this.available,
    required this.label,
    this.detail,
    this.supportsMultichannel = false,
    this.supportsAbCompare = true,
  });

  /// Le backend peut réellement acheminer l'audio dans le moteur.
  final bool available;
  final String label;
  final String? detail;

  /// Le backend voit les canaux sources (5.1/7.1) avant downmix plateforme.
  final bool supportsMultichannel;

  /// Bascule A/B instantanée possible.
  final bool supportsAbCompare;

  @override
  List<Object?> get props => <Object?>[available, label, supportsMultichannel, supportsAbCompare];
}

/// Backend audio : attache le moteur au chemin audio de la plateforme.
abstract interface class CinevaAudioBackend {
  AudioBackendCapabilities get capabilities;

  /// Attache le moteur au média actif (idempotent).
  Future<bool> attach();

  /// Détache proprement (l'audio reprend son chemin d'origine).
  Future<void> detach();

  /// Pousse la configuration complète (tableau versionné de 128 doubles).
  void setParams(List<double> params);

  /// État de traitement réellement actif.
  bool get isAttached;
}

/// Backend indisponible — utilisé quand aucune insertion n'est possible sur
/// la plateforme. NE TRAITE PAS l'audio : `capabilities.available == false`.
class UnavailableAudioBackend implements CinevaAudioBackend {
  UnavailableAudioBackend({required this.label, this.detail});

  final String label;
  final String? detail;

  @override
  AudioBackendCapabilities get capabilities => AudioBackendCapabilities(
        available: false,
        label: label,
        detail: detail,
      );

  @override
  Future<bool> attach() async => false;

  @override
  Future<void> detach() async {}

  @override
  void setParams(List<double> params) {}

  @override
  bool get isAttached => false;
}
