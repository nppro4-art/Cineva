/// Lecture vidéo desktop de Cineva, propulsée par media_kit (libmpv).
///
/// `video_player` n'a aucune implémentation Windows ni Linux : sans moteur
/// adapté, l'exécutable Windows démarrait mais ne pouvait afficher aucune
/// image. Ce paquet fournit l'implémentation desktop du contrat
/// `CinevaVideoController` défini par `cineva_widgets`.
///
/// Il n'est référencé que par les applications desktop (`cineva_windows`,
/// `cineva_macos`) : les APK mobiles continuent d'utiliser `video_player`
/// (ExoPlayer / AVPlayer) et n'embarquent aucune bibliothèque supplémentaire.
///
/// Usage — une seule ligne dans `main()`, avant `runApp` :
///
/// ```dart
/// void main() {
///   WidgetsFlutterBinding.ensureInitialized();
///   installDesktopVideoPlayback();
///   runApp(...);
/// }
/// ```
library;

export 'src/desktop_video_playback.dart';
export 'src/media_kit_video_controller.dart';
