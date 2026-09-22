import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

/// Intervalle réellement mis en cache par le moteur de lecture.
///
/// Miroir de `DurationRange` (video_player) pour ne pas exposer le type d'un
/// moteur particulier au lecteur : les deux implémentations produisent des
/// plages comparables.
@immutable
class CinevaVideoBufferRange {
  const CinevaVideoBufferRange(this.start, this.end);

  final Duration start;
  final Duration end;

  @override
  bool operator ==(Object other) =>
      other is CinevaVideoBufferRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'CinevaVideoBufferRange($start → $end)';
}

/// État de lecture normalisé.
///
/// Les noms de champs reprennent volontairement ceux de `VideoPlayerValue`
/// (`isInitialized`, `isPlaying`, `position`, `duration`, `buffered`,
/// `aspectRatio`, `hasError`, `errorDescription`) : le lecteur Cineva s'appuie
/// sur ce contrat et reste strictement identique quel que soit le moteur
/// sous-jacent (`video_player` sur mobile/web, `media_kit` sur desktop).
@immutable
class CinevaVideoValue {
  const CinevaVideoValue({
    this.isInitialized = false,
    this.isPlaying = false,
    this.isBuffering = false,
    this.hasError = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = const <CinevaVideoBufferRange>[],
    this.aspectRatio = 16 / 9,
    this.volume = 1,
    this.errorDescription,
  });

  /// Métadonnées chargées : la surface vidéo peut être affichée.
  final bool isInitialized;

  final bool isPlaying;
  final bool isBuffering;
  final bool hasError;
  final Duration position;
  final Duration duration;
  final List<CinevaVideoBufferRange> buffered;

  /// Rapport largeur/hauteur du flux. Jamais nul ni NaN : `AspectRatio`
  /// l'exige strictement positif.
  final double aspectRatio;

  /// Volume normalisé 0.0 → 1.0 (media_kit travaille en 0 → 100).
  final double volume;

  final String? errorDescription;

  static const CinevaVideoValue uninitialized = CinevaVideoValue();

  CinevaVideoValue copyWith({
    bool? isInitialized,
    bool? isPlaying,
    bool? isBuffering,
    bool? hasError,
    Duration? position,
    Duration? duration,
    List<CinevaVideoBufferRange>? buffered,
    double? aspectRatio,
    double? volume,
    String? errorDescription,
    bool clearError = false,
  }) {
    return CinevaVideoValue(
      isInitialized: isInitialized ?? this.isInitialized,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      hasError: hasError ?? this.hasError,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffered: buffered ?? this.buffered,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      volume: volume ?? this.volume,
      errorDescription: clearError ? null : (errorDescription ?? this.errorDescription),
    );
  }

  @override
  String toString() =>
      'CinevaVideoValue(initialized: $isInitialized, playing: $isPlaying, '
      'position: $position, duration: $duration, error: $errorDescription)';
}

/// Contrat de lecture vidéo de Cineva.
///
/// Le lecteur (`PlayerScreen`) ne connaît que ce contrat : aucune dépendance à
/// un moteur particulier ne remonte dans l'interface. Les applications
/// desktop remplacent la fabrique par défaut via
/// [CinevaVideoControllers.install] — voir le paquet `cineva_desktop_video`.
abstract class CinevaVideoController {
  /// Dernier état connu. Ne lance jamais : avant [initialize], renvoie
  /// [CinevaVideoValue.uninitialized].
  CinevaVideoValue get value;

  /// Notifie à chaque changement d'état (position, lecture, tampon, erreur).
  void addListener(VoidCallback listener);

  void removeListener(VoidCallback listener);

  /// Charge le média et renseigne [CinevaVideoValue.duration] /
  /// [CinevaVideoValue.aspectRatio]. Ne démarre pas la lecture.
  Future<void> initialize();

  Future<void> play();

  Future<void> pause();

  Future<void> seekTo(Duration position);

  /// [volume] est normalisé : 0.0 (muet) → 1.0 (maximum).
  Future<void> setVolume(double volume);

  /// Libère le décodeur. Idempotent.
  Future<void> dispose();

  /// Surface vidéo, à insérer dans l'arbre (derrière les contrôles Cineva et
  /// la couche Vision). Le rendu respecte le rapport d'aspect du flux.
  Widget buildVideo();
}

/// Fabrique de contrôleurs : `({url, isLocal}) → contrôleur`.
typedef CinevaVideoControllerFactory = CinevaVideoController Function({
  required String url,
  required bool isLocal,
});

/// Socle partagé : gestion des écouteurs et garde-fou après disposal.
abstract class CinevaVideoControllerBase implements CinevaVideoController {
  final List<VoidCallback> _listeners = <VoidCallback>[];
  bool _disposed = false;

  /// Vrai une fois [dispose] appelé : plus aucune notification n'est émise.
  bool get isDisposed => _disposed;

  @override
  void addListener(VoidCallback listener) {
    if (_disposed) return;
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  @protected
  void notifyListeners() {
    if (_disposed || _listeners.isEmpty) return;
    // Copie : un écouteur peut se désinscrire pendant la notification.
    for (final VoidCallback listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }

  @protected
  void markDisposed() {
    _disposed = true;
    _listeners.clear();
  }
}

/// Registre le moteur de lecture utilisé par l'application.
///
/// Par défaut : `video_player` (Android, iOS, web) — comportement historique
/// inchangé. Les cibles desktop installent `media_kit` au démarrage, sans quoi
/// la lecture échouerait (`video_player` n'a aucune implémentation Windows ni
/// Linux). L'injection se fait côté application, jamais côté `cineva_widgets` :
/// les APK mobiles n'embarquent donc aucune dépendance desktop.
abstract final class CinevaVideoControllers {
  static CinevaVideoControllerFactory _factory = videoPlayerControllerFactory;

  /// Fabrique active.
  static CinevaVideoControllerFactory get factory => _factory;

  /// Vrai si une fabrique autre que celle par défaut est installée.
  static bool get isOverridden => !identical(_factory, videoPlayerControllerFactory);

  /// Installe un moteur (typiquement `media_kit` sur desktop).
  static void install(CinevaVideoControllerFactory factory) {
    _factory = factory;
  }

  /// Revient à `video_player` (tests, cible mobile).
  static void reset() {
    _factory = videoPlayerControllerFactory;
  }

  /// Ouvre [url] avec le moteur actif.
  ///
  /// [isLocal] distingue un fichier téléchargé d'un flux réseau : les moteurs
  /// n'ont pas la même résolution d'URI selon l'origine.
  static CinevaVideoController open({required String url, bool isLocal = false}) {
    return _factory(url: url, isLocal: isLocal);
  }
}

/// Fabrique par défaut : adapteur `video_player`.
CinevaVideoController videoPlayerControllerFactory({
  required String url,
  required bool isLocal,
}) {
  return VideoPlayerBackedController(url: url, isLocal: isLocal);
}

/// Adapteur `video_player` — moteur historique des cibles Android, iOS et web.
///
/// Aucune logique de lecture n'est modifiée : cet adapteur se contente de
/// projeter `VideoPlayerValue` dans [CinevaVideoValue] et de relayer les
/// notifications.
class VideoPlayerBackedController extends CinevaVideoControllerBase {
  VideoPlayerBackedController({required String url, required bool isLocal})
      : _inner = isLocal
            ? VideoPlayerController.contentUri(Uri.file(url))
            : VideoPlayerController.networkUrl(Uri.parse(url));

  final VideoPlayerController _inner;
  bool _observing = false;

  /// Contrôleur sous-jacent, pour les rares besoins de diagnostic.
  VideoPlayerController get inner => _inner;

  @override
  CinevaVideoValue get value {
    final VideoPlayerValue state = _inner.value;
    return CinevaVideoValue(
      isInitialized: state.isInitialized,
      isPlaying: state.isPlaying,
      isBuffering: state.isBuffering,
      hasError: state.hasError,
      position: state.position,
      duration: state.duration,
      buffered: state.buffered
          .map((DurationRange range) => CinevaVideoBufferRange(range.start, range.end))
          .toList(),
      aspectRatio: _safeAspectRatio(state),
      volume: state.volume,
      errorDescription: state.errorDescription,
    );
  }

  /// `AspectRatio` exige une valeur strictement positive : avant initialisation
  /// (ou sur un flux sans piste vidéo) on retombe sur le 16:9.
  static double _safeAspectRatio(VideoPlayerValue state) {
    if (!state.isInitialized) return 16 / 9;
    final double ratio = state.aspectRatio;
    if (ratio.isNaN || ratio <= 0) return 16 / 9;
    return ratio;
  }

  void _observe() {
    if (_observing) return;
    _observing = true;
    _inner.addListener(notifyListeners);
  }

  @override
  Future<void> initialize() async {
    _observe();
    await _inner.initialize();
    notifyListeners();
  }

  @override
  Future<void> play() => _inner.play();

  @override
  Future<void> pause() => _inner.pause();

  @override
  Future<void> seekTo(Duration position) => _inner.seekTo(position);

  @override
  Future<void> setVolume(double volume) =>
      _inner.setVolume(volume.clamp(0.0, 1.0).toDouble());

  @override
  Future<void> dispose() async {
    if (isDisposed) return;
    markDisposed();
    if (_observing) {
      _inner.removeListener(notifyListeners);
    }
    await _inner.dispose();
  }

  @override
  Widget buildVideo() => VideoPlayer(_inner);
}
