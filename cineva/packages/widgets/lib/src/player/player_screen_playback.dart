part of 'player_screen.dart';

void _playerEnsureController(
  _PlayerScreenState state, {
  required ContentDetailModel detail,
  required PlaybackProgressModel? progress,
  required DownloadItemModel? download,
}) {
  if (state._activeContentId == detail.id && state._controller != null) return;

  state._activeContentId = detail.id;
  state._selectedAudio = detail.audioLanguages.isNotEmpty ? detail.audioLanguages.first : 'Français';
  state._selectedSubtitle = detail.subtitleLanguages.isNotEmpty ? detail.subtitleLanguages.first : 'Aucun';
  state._selectedQuality = detail.availableQualities.isNotEmpty
      ? detail.availableQualities.first.preset
      : VideoQualityPreset.auto;

  final url = detail.resolvePlaybackUrl(state._selectedQuality);
  final localPath = download?.canPlayOffline == true ? download!.localFilePath : null;

  if ((url == null || url.isEmpty) && (localPath == null || localPath.isEmpty)) {
    state._playbackError = 'Aucun flux vidéo disponible pour ce contenu.';
    return;
  }

  unawaited(
    _playerInitializeController(
      state,
      url: url,
      localFilePath: localPath,
      seekToSeconds: progress?.positionSeconds ?? 0,
      autoPlay: true,
    ),
  );
}

Future<void> _playerInitializeController(
  _PlayerScreenState state, {
  required String? url,
  required String? localFilePath,
  required int seekToSeconds,
  required bool autoPlay,
}) async {
  final oldController = state._controller;
  oldController?.removeListener(state._videoListener);
  state._controller = null;
  state._saveTimer?.cancel();
  if (state.mounted) {
    state.setState(() => state._playbackError = null);
  }

  final controller = (localFilePath != null && localFilePath.isNotEmpty)
      ? VideoPlayerController.contentUri(Uri.file(localFilePath))
      : VideoPlayerController.networkUrl(Uri.parse(url!));
  state._controller = controller;

  try {
    await controller.initialize();
    if (seekToSeconds > 0) {
      await controller.seekTo(Duration(seconds: seekToSeconds));
    }
    await controller.setVolume(state._volume);
    if (autoPlay) {
      await controller.play();
    }
    controller.addListener(state._videoListener);
    state._saveTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => state._persistProgress(),
    );
    await oldController?.dispose();
    if (state.mounted) {
      state.setState(() {
        state._playbackError = null;
        state._isSwitchingQuality = false;
      });
      state._scheduleHide();
    }
  } catch (error) {
    await controller.dispose();
    if (localFilePath != null && localFilePath.isNotEmpty && url != null && url.isNotEmpty) {
      try {
        final fallbackController = VideoPlayerController.networkUrl(Uri.parse(url));
        state._controller = fallbackController;
        await fallbackController.initialize();
        if (seekToSeconds > 0) {
          await fallbackController.seekTo(Duration(seconds: seekToSeconds));
        }
        await fallbackController.setVolume(state._volume);
        if (autoPlay) {
          await fallbackController.play();
        }
        fallbackController.addListener(state._videoListener);
        state._saveTimer = Timer.periodic(
          const Duration(seconds: 5),
          (_) => state._persistProgress(),
        );
        await oldController?.dispose();
        if (state.mounted) {
          state.setState(() {
            state._playbackError = null;
            state._isSwitchingQuality = false;
          });
          state._scheduleHide();
        }
        return;
      } catch (_) {}
    }

    state._controller = oldController;
    if (state.mounted) {
      state.setState(() {
        state._isSwitchingQuality = false;
        state._playbackError = 'Le flux est indisponible, l’URL a expiré ou le réseau est momentanément inaccessible. ($error)';
      });
    }
  }
}

void _playerVideoListener(_PlayerScreenState state) {
  final player = state._controller;
  final detail = state.ref.read(contentDetailProvider(state.widget.contentId)).valueOrNull;
  if (!state.mounted || player == null || detail == null) return;

  if (player.value.hasError) {
    state.setState(() {
      state._playbackError = player.value.errorDescription ?? 'Erreur de lecture inattendue.';
    });
    return;
  }
  if (!player.value.isInitialized) return;

  final remaining = player.value.duration.inSeconds - player.value.position.inSeconds;
  if (PlayerRuntimePolicy.shouldQueueNextEpisode(
    remainingSeconds: remaining,
    nextContentId: detail.nextContentId,
    dismissed: state._nextEpisodeDismissed,
  )) {
    _playerStartNextEpisodeCountdown(state, detail.nextContentId!);
  }
  if (remaining > 12 && state._nextEpisodeId != null) {
    state._nextEpisodeTimer?.cancel();
    if (state.mounted) {
      state.setState(() {
        state._nextEpisodeId = null;
        state._nextEpisodeCountdown = 0;
      });
    }
  }
  if (player.value.position >= player.value.duration && player.value.duration > Duration.zero) {
    _playerPersistProgress(state, forceComplete: true);
  }
}

void _playerStartNextEpisodeCountdown(_PlayerScreenState state, String nextId) {
  if (state._nextEpisodeId == nextId && state._nextEpisodeCountdown > 0) return;
  state._nextEpisodeTimer?.cancel();
  if (state.mounted) {
    state.setState(() {
      state._nextEpisodeId = nextId;
      state._nextEpisodeCountdown = 10;
    });
  }
  state._nextEpisodeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (!state.mounted) {
      timer.cancel();
      return;
    }
    if (state._nextEpisodeCountdown <= 1) {
      timer.cancel();
      _playerPlayNextEpisode(state);
    } else {
      state.setState(() => state._nextEpisodeCountdown -= 1);
    }
  });
}

void _playerPlayNextEpisode(_PlayerScreenState state) {
  final nextId = state._nextEpisodeId;
  if (nextId == null) return;
  state._nextEpisodeTimer?.cancel();
  state._nextEpisodeDismissed = false;
  state.context.go('/player/${Uri.encodeComponent(nextId)}');
}

Future<void> _playerPersistProgress(_PlayerScreenState state, {bool forceComplete = false}) async {
  final player = state._controller;
  final detail = state.ref.read(contentDetailProvider(state.widget.contentId)).valueOrNull;
  if (player == null || detail == null || !player.value.isInitialized) return;
  final duration = player.value.duration.inSeconds;
  if (duration <= 0) return;
  final position = forceComplete ? duration : player.value.position.inSeconds;
  await state.ref.read(libraryControllerProvider.notifier).saveProgress(
        content: detail.toTile(),
        positionSeconds: position,
        durationSeconds: duration,
      );
}
