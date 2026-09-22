import 'dart:async';

import 'package:cineva_widgets/cineva_widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;

/// Volume normalisé Cineva (0.0 → 1.0) vers l'échelle media_kit (0 → 100).
///
/// `PlayerScreen` manipule un volume normalisé (gestes, curseur, sauvegarde) ;
/// libmpv attend un pourcentage. La conversion est isolée ici et testée.
double mediaKitVolumeFromNormalized(double normalized) {
  return (normalized.clamp(0.0, 1.0).toDouble() * 100).clamp(0.0, 100.0).toDouble();
}

/// Conversion inverse : échelle media_kit (0 → 100) vers 0.0 → 1.0.
double normalizedVolumeFromMediaKit(double volume) {
  return (volume.clamp(0.0, 100.0).toDouble() / 100).clamp(0.0, 1.0).toDouble();
}

/// Rapport d'aspect de repli tant que les dimensions du flux sont inconnues.
/// `AspectRatio` exige une valeur strictement positive : jamais 0 ni NaN.
const double kDesktopVideoFallbackAspectRatio = 16 / 9;

/// Adapteur media_kit (libmpv) du contrat [CinevaVideoController].
///
/// Rend exactement les mêmes services que l'adapteur `video_player` : état
/// normalisé, notifications à chaque changement, surface vidéo sans contrôles
/// (le lecteur Cineva dessine les siens). Utilisé par les cibles Windows,
/// Linux et macOS, où `video_player` n'a aucune implémentation.
class MediaKitBackedController extends CinevaVideoControllerBase {
  MediaKitBackedController({required String url, required bool isLocal})
      : _media = mk.Media(isLocal ? Uri.file(url).toString() : url);

  final mk.Media _media;

  /// Lecteur libmpv, créé au plus tard possible : un contrôleur construit mais
  /// jamais initialisé (ouverture annulée, erreur de réseau) ne doit charger
  /// aucune ressource native — il est alors jetable sans effet de bord.
  mk.Player? _playerRef;

  mk.Player get _player => _playerRef ??= mk.Player();

  // La sortie vidéo est négociée à la construction du VideoController : elle
  // doit exister AVANT l'ouverture du média (voir [_ensureSurface]).
  late final mkv.VideoController _videoController = mkv.VideoController(_player);

  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  CinevaVideoValue _value = CinevaVideoValue.uninitialized;
  Completer<void>? _durationReady;
  Widget? _surface;
  bool _opened = false;
  bool _bound = false;
  int? _width;
  int? _height;
  Duration _buffer = Duration.zero;

  @override
  CinevaVideoValue get value => _value;

  @override
  Future<void> initialize() async {
    if (_opened) return;
    _opened = true;
    _durationReady = Completer<void>();

    // 1) sortie vidéo, 2) écoute des flux, 3) ouverture du média : dans cet
    //    ordre, aucun événement (durée, dimensions) n'est perdu.
    _ensureSurface();
    _bind();
    await _player.open(_media, play: false);
    _syncFromState();

    // media_kit renseigne la durée de façon asynchrone. Sans elle, la position
    // de reprise et les segments à sauter seraient calculés sur une durée nulle.
    final Completer<void>? ready = _durationReady;
    if (_value.duration == Duration.zero && ready != null && !ready.isCompleted) {
      await ready.future.timeout(const Duration(seconds: 8), onTimeout: () {});
      _syncFromState();
    }

    _update(_value.copyWith(isInitialized: true));
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seekTo(Duration position) {
    final Duration duration = _value.duration;
    Duration target = position;
    if (target < Duration.zero) target = Duration.zero;
    if (duration > Duration.zero && target > duration) target = duration;
    return _player.seek(target);
  }

  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume(mediaKitVolumeFromNormalized(volume));

  @override
  Future<void> dispose() async {
    if (isDisposed) return;
    markDisposed();
    for (final StreamSubscription<dynamic> subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    final mk.Player? player = _playerRef;
    if (player == null) return;
    _playerRef = null;
    try {
      await player.dispose();
    } catch (_) {
      // Lecteur déjà libéré (fermeture de fenêtre en cours de lecture).
    }
  }

  @override
  Widget buildVideo() => _ensureSurface();

  // ------------------------------------------------------------------ interne

  /// Surface vidéo sans aucun contrôle superposé : `PlayerScreen` affiche ses
  /// propres commandes (barre dorée, gestes, feuilles qualité/audio/sous-titres)
  /// et la couche Cineva Vision reste appliquée au-dessus.
  Widget _ensureSurface() {
    final mkv.VideoController controller = _videoController;
    return _surface ??= mkv.Video(
      controller: controller,
      controls: mkv.NoVideoControls,
      fit: BoxFit.contain,
      fill: const Color(0xFF000000),
      // filterQuality laissé à sa valeur par défaut (`low` = bilinéaire) : le
      // rendu d'une texture vidéo n'a pas besoin d'un filtrage plus coûteux.
      // Gestion déjà assurée par PlayerScreen (cycle de vie, mise en pause en
      // arrière-plan) : on évite un double traitement.
      wakelock: false,
      pauseUponEnteringBackgroundMode: false,
      resumeUponEnteringForegroundMode: false,
    );
  }

  void _bind() {
    if (_bound) return;
    _bound = true;

    final mk.PlayerStream stream = _player.stream;
    _subscriptions
      ..add(
        stream.position.listen((Duration position) {
          _update(_value.copyWith(position: position, buffered: _rangesFor(position)));
        }),
      )
      ..add(
        stream.duration.listen((Duration duration) {
          _update(_value.copyWith(duration: duration));
          final Completer<void>? ready = _durationReady;
          if (duration > Duration.zero && ready != null && !ready.isCompleted) {
            ready.complete();
          }
        }),
      )
      ..add(
        stream.playing.listen((bool playing) {
          _update(_value.copyWith(isPlaying: playing));
        }),
      )
      ..add(
        stream.buffering.listen((bool buffering) {
          _update(_value.copyWith(isBuffering: buffering));
        }),
      )
      ..add(
        stream.buffer.listen((Duration buffer) {
          _buffer = buffer;
          _update(_value.copyWith(buffered: _rangesFor(_value.position)));
        }),
      )
      ..add(
        stream.volume.listen((double volume) {
          _update(_value.copyWith(volume: normalizedVolumeFromMediaKit(volume)));
        }),
      )
      ..add(
        stream.width.listen((int? width) {
          _width = width;
          _update(_value.copyWith(aspectRatio: _aspectRatio()));
        }),
      )
      ..add(
        stream.height.listen((int? height) {
          _height = height;
          _update(_value.copyWith(aspectRatio: _aspectRatio()));
        }),
      )
      ..add(
        stream.completed.listen((bool completed) {
          if (!completed) return;
          // Fin de flux : position calée sur la durée, lecture arrêtée. C'est ce
          // signal qui déclenche côté lecteur la sauvegarde « terminé » et le
          // compte à rebours de l'épisode suivant.
          final Duration duration = _value.duration;
          _update(
            _value.copyWith(
              isPlaying: false,
              position: duration > Duration.zero ? duration : _value.position,
            ),
          );
        }),
      )
      ..add(
        stream.error.listen((String message) {
          if (message.trim().isEmpty) return;
          _update(_value.copyWith(hasError: true, errorDescription: message));
        }),
      );
  }

  /// Relit l'état instantané du lecteur (utile juste après [mk.Player.open]).
  void _syncFromState() {
    final mk.PlayerState state = _player.state;
    _width = state.width ?? _width;
    _height = state.height ?? _height;
    _buffer = state.buffer;
    _update(
      CinevaVideoValue(
        isInitialized: _value.isInitialized,
        isPlaying: state.playing,
        isBuffering: state.buffering,
        hasError: _value.hasError,
        position: state.position,
        duration: state.duration,
        buffered: _rangesFor(state.position),
        aspectRatio: _aspectRatio(),
        volume: normalizedVolumeFromMediaKit(state.volume),
        errorDescription: _value.errorDescription,
      ),
    );
  }

  void _update(CinevaVideoValue next) {
    if (isDisposed) return;
    _value = next;
    notifyListeners();
  }

  /// media_kit expose une position de tampon (durée décodée d'avance), pas des
  /// plages : la plage affichée est donc [position, position + tampon], dérivée
  /// de valeurs réellement rapportées — jamais inventée.
  List<CinevaVideoBufferRange> _rangesFor(Duration position) {
    if (_buffer <= Duration.zero) return const <CinevaVideoBufferRange>[];
    return <CinevaVideoBufferRange>[
      CinevaVideoBufferRange(position, position + _buffer),
    ];
  }

  double _aspectRatio() {
    final int? width = _width;
    final int? height = _height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return kDesktopVideoFallbackAspectRatio;
    }
    final double ratio = width / height;
    if (ratio.isNaN || ratio <= 0) return kDesktopVideoFallbackAspectRatio;
    return ratio;
  }
}
