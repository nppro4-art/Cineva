import 'dart:async';

import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../app/providers.dart';
import '../vision/cineva_vision_layer.dart';
import 'player_formatters.dart';
import 'player_overlays.dart';
import 'player_runtime_policy.dart';

part 'player_screen_playback.dart';
part 'player_screen_actions.dart';
part 'player_screen_gestures.dart';

VideoQualityOption _resolveSelectedQualityOption(
  List<VideoQualityOption> options,
  VideoQualityPreset selected,
) {
  for (final option in options) {
    if (option.preset == selected) {
      return option;
    }
  }
  if (options.isNotEmpty) {
    return options.first;
  }
  return const VideoQualityOption(
    preset: VideoQualityPreset.auto,
    bitrateMbps: 0,
    resolutionLabel: 'Adaptatif',
    hdr: false,
    dolbyVision: false,
    dolbyAtmos: false,
  );
}

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.contentId});

  final String contentId;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Timer? _hideTimer;
  Timer? _saveTimer;
  Timer? _gestureTimer;
  Timer? _nextEpisodeTimer;

  bool _showControls = true;
  bool _controlsLocked = false;
  bool _immersive = false;
  bool _nextEpisodeDismissed = false;
  bool _isSwitchingQuality = false;

  String? _playbackError;
  String? _selectedAudio;
  String? _selectedSubtitle;
  VideoQualityPreset _selectedQuality = VideoQualityPreset.auto;
  double _volume = 1;
  double _brightnessOverlay = 0;
  String? _gestureMessage;
  Offset? _doubleTapPosition;
  String? _nextEpisodeId;
  int _nextEpisodeCountdown = 0;
  String? _activeContentId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    _gestureTimer?.cancel();
    _nextEpisodeTimer?.cancel();
    _persistProgress();
    _controller?.dispose();
    try {
      ref.read(audioEngineControllerProvider.notifier).detach();
    } catch (_) {
      // le provider peut déjà être disposé
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _persistProgress();
      _controller?.pause();
      return;
    }

    if (state == AppLifecycleState.resumed && (_controller?.value.isInitialized ?? false)) {
      _controller?.play();
      _scheduleHide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(contentDetailProvider(widget.contentId));
    final library = ref.watch(libraryControllerProvider);
    final visionState = ref.watch(visionControllerProvider);
    final audioEngine = ref.watch(audioEngineControllerProvider);
    final connected = ref.watch(networkConnectedProvider).valueOrNull ?? true;

    return detailAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CinevaLoadingView(label: 'Préparation du lecteur...')),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: CinevaStatusBanner(
              title: 'Lecteur indisponible',
              message: error.toString(),
              tone: CinevaBannerTone.error,
            ),
          ),
        ),
      ),
      data: (detail) {
        if (detail == null) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CinevaStatusBanner(
                title: 'Vidéo introuvable',
                message: 'Le contenu demandé ne peut pas être lu pour le moment.',
                tone: CinevaBannerTone.warning,
              ),
            ),
          );
        }

        if (detail.isSeries && detail.defaultPlaybackId != null && detail.defaultPlaybackId != detail.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/player/${Uri.encodeComponent(detail.defaultPlaybackId!)}');
            }
          });
        }

        final currentDownload = library.downloadFor(detail.id);
        _ensureController(
          detail,
          library.progressFor(detail.id, detail.contentType),
          currentDownload,
        );

        final player = _controller;
        final activePlayer = player != null && player.value.isInitialized ? player : null;
        final hasError = _playbackError != null || (player?.value.hasError ?? false);
        final effectiveError = _playbackError ?? player?.value.errorDescription;
        final capabilities = visionState.capabilities;
        final settings = visionState.settings;
        final renderProfile = capabilities != null && settings != null
            ? ref.read(cinevaVisionServiceProvider).buildRenderProfile(
                  settings: settings,
                  capabilities: capabilities,
                )
            : null;

        final position = activePlayer?.value.position.inSeconds ?? 0;
        final duration = activePlayer?.value.duration.inSeconds ?? 0;
        final showSkipIntro = PlayerRuntimePolicy.shouldShowSkipIntro(
          positionSeconds: position,
          introEndSeconds: detail.introEndSeconds,
        );
        final showSkipCredits = PlayerRuntimePolicy.shouldShowSkipCredits(
          positionSeconds: position,
          creditsStartSeconds: detail.creditsStartSeconds,
        );
        final resolvedCurrentQuality = _resolveSelectedQualityOption(
          detail.availableQualities,
          _selectedQuality,
        );

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (!didPop && mounted) {
              context.go('/content/${Uri.encodeComponent(detail.seriesId ?? detail.id)}');
            }
          },
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Shortcuts(
              shortcuts: <LogicalKeySet, Intent>{
                LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
                LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
                LogicalKeySet(LogicalKeyboardKey.space): const ActivateIntent(),
                LogicalKeySet(LogicalKeyboardKey.arrowLeft): const DirectionalFocusIntent(TraversalDirection.left),
                LogicalKeySet(LogicalKeyboardKey.arrowRight): const DirectionalFocusIntent(TraversalDirection.right),
                LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (_) => _togglePlayPause(),
                  ),
                  DismissIntent: CallbackAction<DismissIntent>(
                    onInvoke: (_) {
                      context.go('/content/${Uri.encodeComponent(detail.seriesId ?? detail.id)}');
                      return null;
                    },
                  ),
                  DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(
                    onInvoke: (intent) {
                      if (intent.direction == TraversalDirection.left) {
                        _seekRelative(-10);
                      } else if (intent.direction == TraversalDirection.right) {
                        _seekRelative(10);
                      }
                      return null;
                    },
                  ),
                },
                child: Focus(
                  autofocus: true,
                  child: Scaffold(
                    backgroundColor: Colors.black,
                    body: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _controlsLocked ? null : _toggleControls,
                      onDoubleTapDown: (details) => _doubleTapPosition = details.localPosition,
                      onDoubleTap: () => _handleDoubleTap(context),
                      onVerticalDragUpdate: (details) => _handleVerticalGesture(context, details),
                      onHorizontalDragUpdate: _handleHorizontalGesture,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeOutCubic,
                            color: Colors.black,
                            child: Center(
                              child: activePlayer != null
                                  ? AnimatedScale(
                                      duration: const Duration(milliseconds: 260),
                                      curve: Curves.easeOutCubic,
                                      scale: _immersive ? 1.02 : 1,
                                      child: AspectRatio(
                                        aspectRatio: _immersive ? MediaQuery.of(context).size.aspectRatio : activePlayer.value.aspectRatio,
                                        child: renderProfile == null
                                            ? VideoPlayer(activePlayer)
                                            : CinevaVisionLayer(
                                                renderProfile: renderProfile,
                                                child: VideoPlayer(activePlayer),
                                              ),
                                      ),
                                    )
                                  : CinevaLoadingView(
                                      label: _isSwitchingQuality ? 'Changement de qualité en cours...' : 'Initialisation vidéo...',
                                    ),
                            ),
                          ),
                          if (_brightnessOverlay > 0)
                            IgnorePointer(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 180),
                                opacity: _brightnessOverlay.clamp(0, 0.35),
                                child: Container(
                                  color: Colors.white.withOpacity(_brightnessOverlay.clamp(0, 0.35)),
                                ),
                              ),
                            ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Colors.black.withOpacity(_showControls ? 0.5 : 0.06),
                                  Colors.transparent,
                                  Colors.black.withOpacity(_showControls ? 0.62 : 0.12),
                                ],
                              ),
                            ),
                          ),
                          if (!connected && !(currentDownload?.canPlayOffline ?? false))
                            Positioned(
                              top: MediaQuery.of(context).padding.top + 16,
                              left: 72,
                              right: 16,
                              child: const CinevaStatusBanner(
                                title: 'Connexion instable',
                                message: 'Le réseau semble indisponible et aucun fichier hors ligne n’est actuellement disponible pour ce contenu.',
                                tone: CinevaBannerTone.warning,
                              ),
                            ),
                          if (showSkipIntro)
                            Positioned(
                              right: CinevaSpacing.lg,
                              bottom: 168,
                              child: ActionPill(
                                icon: Icons.fast_forward_rounded,
                                label: 'Ignorer l’intro',
                                onTap: () => _seekToSeconds(detail.introEndSeconds!),
                              ),
                            ),
                          if (showSkipCredits)
                            Positioned(
                              right: CinevaSpacing.lg,
                              bottom: 116,
                              child: ActionPill(
                                icon: Icons.skip_next_rounded,
                                label: 'Ignorer le générique',
                                onTap: () => _seekToSeconds(duration - 1),
                              ),
                            ),
                          if (_nextEpisodeId != null && _nextEpisodeCountdown > 0)
                            Positioned(
                              right: CinevaSpacing.lg,
                              bottom: 220,
                              child: NextEpisodeCard(
                                countdown: _nextEpisodeCountdown,
                                onPlayNow: _playNextEpisode,
                                onDismiss: () {
                                  setState(() {
                                    _nextEpisodeDismissed = true;
                                    _nextEpisodeCountdown = 0;
                                    _nextEpisodeId = null;
                                  });
                                  _nextEpisodeTimer?.cancel();
                                },
                              ),
                            ),
                          if (hasError)
                            Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 560),
                                child: CinevaGlassCard(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text('Erreur de lecture', style: Theme.of(context).textTheme.titleLarge),
                                      const SizedBox(height: CinevaSpacing.sm),
                                      Text(
                                        effectiveError ?? 'Le flux est indisponible ou le réseau a été interrompu.',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted),
                                      ),
                                      const SizedBox(height: CinevaSpacing.lg),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: <Widget>[
                                          CinevaPrimaryButton(
                                            label: 'Réessayer',
                                            icon: Icons.refresh_rounded,
                                            onPressed: () => _retry(detail),
                                          ),
                                          CinevaPrimaryButton(
                                            label: 'Retour au contenu',
                                            icon: Icons.arrow_back_rounded,
                                            onPressed: () => context.go('/content/${Uri.encodeComponent(detail.seriesId ?? detail.id)}'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (_gestureMessage != null)
                            Center(
                              child: IgnorePointer(
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 160),
                                  opacity: 1,
                                  child: GestureToast(message: _gestureMessage!),
                                ),
                              ),
                            ),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 180),
                            opacity: _showControls && !_controlsLocked ? 1 : 0,
                            child: PlayerControls(
                              detail: detail,
                              controller: player,
                              volume: _volume,
                              selectedAudio: _selectedAudio ?? detail.audioLanguages.first,
                              selectedSubtitle: _selectedSubtitle ?? detail.subtitleLanguages.first,
                              selectedQuality: resolvedCurrentQuality,
                              isImmersive: _immersive,
                              audioEngineLabel: audioEngine.backendAvailable
                                  ? audioEngine.settings.profile.label
                                  : null,
                              audioProcessing: audioEngine.processingActive,
                              audioAbCompare: audioEngine.settings.abCompare,
                              onOpenAudioSettings: audioEngine.backendAvailable
                                  ? () => context.push('/settings/audio')
                                  : null,
                              onToggleAudioAb: audioEngine.backendAvailable
                                  ? () => ref
                                      .read(audioEngineControllerProvider.notifier)
                                      .toggleAbCompare()
                                  : null,
                              onBack: () => context.go('/content/${Uri.encodeComponent(detail.seriesId ?? detail.id)}'),
                              onPlayPause: _togglePlayPause,
                              onSeek: _seekToRatio,
                              onToggleImmersive: () => setState(() => _immersive = !_immersive),
                              onOpenAudio: () => _pickAudio(detail),
                              onOpenSubtitles: () => _pickSubtitles(detail),
                              onOpenQuality: () => _openQualitySheet(detail),
                              onVolumeChanged: (value) async {
                                setState(() => _volume = value);
                                await _controller?.setVolume(value);
                              },
                            ),
                          ),
                          Positioned(
                            left: CinevaSpacing.lg,
                            top: MediaQuery.of(context).padding.top + CinevaSpacing.lg,
                            child: Tooltip(
                              message: _controlsLocked ? 'Déverrouiller les commandes' : 'Verrouiller les commandes',
                              child: IconButton.filledTonal(
                                onPressed: () => setState(() => _controlsLocked = !_controlsLocked),
                                icon: Icon(_controlsLocked ? Icons.lock_rounded : Icons.lock_open_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _ensureController(
    ContentDetailModel detail,
    PlaybackProgressModel? progress,
    DownloadItemModel? download,
  ) => _playerEnsureController(
        this,
        detail: detail,
        progress: progress,
        download: download,
      );

  void _videoListener() => _playerVideoListener(this);

  void _playNextEpisode() => _playerPlayNextEpisode(this);

  Future<void> _togglePlayPause() => _playerTogglePlayPause(this);

  Future<void> _seekToRatio(double value) => _playerSeekToRatio(this, value);

  Future<void> _seekToSeconds(int seconds) => _playerSeekToSeconds(this, seconds);

  Future<void> _seekRelative(int deltaSeconds) => _playerSeekRelative(this, deltaSeconds);

  void _toggleControls() => _playerToggleControls(this);

  void _scheduleHide() => _playerScheduleHide(this);

  Future<void> _pickAudio(ContentDetailModel detail) => _playerPickAudio(this, detail);

  Future<void> _pickSubtitles(ContentDetailModel detail) => _playerPickSubtitles(this, detail);

  Future<void> _openQualitySheet(ContentDetailModel detail) => _playerOpenQualitySheet(this, detail);

  void _handleDoubleTap(BuildContext context) => _playerHandleDoubleTap(this, context);

  void _handleVerticalGesture(BuildContext context, DragUpdateDetails details) =>
      _playerHandleVerticalGesture(this, context, details);

  void _handleHorizontalGesture(DragUpdateDetails details) => _playerHandleHorizontalGesture(this, details);

  void _showGesture(String message) => _playerShowGesture(this, message);

  Future<void> _retry(ContentDetailModel detail) => _playerRetry(this, detail);

  Future<void> _persistProgress({bool forceComplete = false}) => _playerPersistProgress(this, forceComplete: forceComplete);
}
