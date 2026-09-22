import 'package:cineva_widgets/cineva_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' as mk;

import 'media_kit_video_controller.dart';

/// Cibles où media_kit est le moteur de lecture : Windows, Linux et macOS.
///
/// Les cibles mobiles continuent d'utiliser `video_player` (ExoPlayer / AVPlayer),
/// plus léger et déjà validé sur les APK livrés.
bool get isDesktopVideoTarget {
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

/// Fabrique desktop : chaque ouverture de flux crée un contrôleur media_kit.
CinevaVideoController desktopVideoControllerFactory({
  required String url,
  required bool isLocal,
}) {
  return MediaKitBackedController(url: url, isLocal: isLocal);
}

/// Installe la lecture vidéo desktop (media_kit / libmpv).
///
/// À appeler une fois dans `main()`, avant `runApp` : charge les bibliothèques
/// natives puis remplace la fabrique par défaut de [CinevaVideoControllers],
/// qui s'appuie sur `video_player` — un paquet sans aucune implémentation
/// Windows ni Linux. Sans cet appel, l'exécutable Windows démarre mais ne
/// peut afficher aucune image.
///
/// Sans effet sur une cible non desktop : libmpv n'y est jamais chargé.
void installDesktopVideoPlayback() {
  if (!isDesktopVideoTarget) return;
  mk.MediaKit.ensureInitialized();
  CinevaVideoControllers.install(desktopVideoControllerFactory);
}
