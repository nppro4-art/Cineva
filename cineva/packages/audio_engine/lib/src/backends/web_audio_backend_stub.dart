/// Stub non-web du backend Web Audio.
///
/// Sur les plateformes natives, le Web Audio API n'existe pas : ce backend
/// déclare honnêtement `available == false` (aucun traitement audio réel).
/// La version web (dart:js_interop) est sélectionnée par l'export
/// conditionnel de `web_audio_backend.dart`.
library;

import 'audio_backend.dart';

/// Backend Web Audio — stub pour plateformes non web.
///
/// Même surface API que l'implémentation web (les méthodes étendues sont
/// des no-op honnêtes) pour un usage identique côté contrôleur.
class WebAudioBackend extends UnavailableAudioBackend {
  WebAudioBackend()
      : super(
          label: 'Web Audio indisponible',
          detail: 'Le moteur audio web requiert un navigateur.',
        );

  /// No-op : sans nœud worklet, aucune métrique n'existe.
  void requestMetrics() {}

  List<double> getMetrics() => const <double>[];

  Map<String, Object?> getStatus() => const <String, Object>{};
}
