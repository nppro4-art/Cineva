part of 'player_screen.dart';

Future<void> _playerTogglePlayPause(_PlayerScreenState state) async {
  final player = state._controller;
  if (player == null || !player.value.isInitialized) return;
  await HapticFeedback.lightImpact();
  if (player.value.isPlaying) {
    await player.pause();
  } else {
    await player.play();
    state._scheduleHide();
  }
  if (state.mounted) state.setState(() {});
}

Future<void> _playerSeekToRatio(_PlayerScreenState state, double value) async {
  final player = state._controller;
  if (player == null || !player.value.isInitialized) return;
  final duration = player.value.duration.inSeconds;
  final detail = state.ref.read(contentDetailProvider(state.widget.contentId)).valueOrNull;
  final target = PlayerRuntimePolicy.resolveSeekTarget(
    targetSeconds: (duration * value).round(),
    durationSeconds: duration,
    segments: detail?.skipSegments ?? const <SkipSegment>[],
  );
  await player.seekTo(Duration(seconds: target));
  state._scheduleHide();
  if (state.mounted) state.setState(() {});
}

Future<void> _playerSeekToSeconds(_PlayerScreenState state, int seconds) async {
  final player = state._controller;
  if (player == null || !player.value.isInitialized) return;
  final duration = player.value.duration.inSeconds;
  final detail = state.ref.read(contentDetailProvider(state.widget.contentId)).valueOrNull;
  // Une cible tombant dans un segment à passer est avancée à la fin du segment.
  final clamped = PlayerRuntimePolicy.resolveSeekTarget(
    targetSeconds: seconds,
    durationSeconds: duration,
    segments: detail?.skipSegments ?? const <SkipSegment>[],
  );
  await player.seekTo(Duration(seconds: clamped));
  await HapticFeedback.selectionClick();
  state._showGesture(PlayerFormatters.formatDuration(clamped));
  state._scheduleHide();
}

Future<void> _playerSeekRelative(_PlayerScreenState state, int deltaSeconds) async {
  final player = state._controller;
  if (player == null || !player.value.isInitialized) return;
  final next = PlayerRuntimePolicy.clampSeekTarget(
    currentSeconds: player.value.position.inSeconds,
    durationSeconds: player.value.duration.inSeconds,
    deltaSeconds: deltaSeconds,
  );
  await state._seekToSeconds(next);
  state._showGesture(deltaSeconds > 0 ? '+${deltaSeconds}s' : '${deltaSeconds}s');
}

void _playerToggleControls(_PlayerScreenState state) {
  state.setState(() => state._showControls = !state._showControls);
  if (state._showControls) {
    state._scheduleHide();
  } else {
    state._hideTimer?.cancel();
  }
}

void _playerScheduleHide(_PlayerScreenState state) {
  state._hideTimer?.cancel();
  state._hideTimer = Timer(const Duration(seconds: 3), () {
    if (state.mounted && !state._controlsLocked) {
      state.setState(() => state._showControls = false);
    }
  });
}

Future<void> _playerPickAudio(_PlayerScreenState state, ContentDetailModel detail) async {
  final selection = await _playerPickOption(
    state,
    title: 'Langue audio',
    options: detail.audioLanguages,
    selected: state._selectedAudio ?? detail.audioLanguages.first,
  );
  if (selection != null && state.mounted) {
    state.setState(() => state._selectedAudio = selection);
    state._scheduleHide();
  }
}

Future<void> _playerPickSubtitles(_PlayerScreenState state, ContentDetailModel detail) async {
  final selection = await _playerPickOption(
    state,
    title: 'Sous-titres',
    options: detail.subtitleLanguages,
    selected: state._selectedSubtitle ?? detail.subtitleLanguages.first,
  );
  if (selection != null && state.mounted) {
    state.setState(() => state._selectedSubtitle = selection);
    state._scheduleHide();
  }
}

Future<void> _playerOpenQualitySheet(_PlayerScreenState state, ContentDetailModel detail) async {
  final selection = await showModalBottomSheet<VideoQualityPreset>(
    context: state.context,
    backgroundColor: CinevaColors.surface,
    showDragHandle: true,
    builder: (context) {
      final resolvedCurrent = _resolveSelectedQualityOption(
        detail.availableQualities,
        state._selectedQuality,
      );
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(CinevaSpacing.lg),
          children: <Widget>[
            Text('Qualité vidéo', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: CinevaSpacing.sm),
            CinevaStatusBanner(
              title: 'Flux actuel',
              message:
                  'Qualité : ${resolvedCurrent.preset.label} • Débit : ${resolvedCurrent.bitrateMbps.toStringAsFixed(1)} Mb/s • Résolution : ${resolvedCurrent.resolutionLabel} • HDR : ${resolvedCurrent.hdr ? 'Oui' : 'Non'} • Dolby Vision : ${resolvedCurrent.dolbyVision ? 'Oui' : 'Non'} • Dolby Atmos : ${resolvedCurrent.dolbyAtmos ? 'Oui' : 'Non'}',
            ),
            const SizedBox(height: CinevaSpacing.lg),
            ...detail.availableQualities.map(
              (option) => ListTile(
                title: Text(option.preset.label),
                subtitle: Text('${option.resolutionLabel} • ${option.bitrateMbps.toStringAsFixed(1)} Mb/s • HDR ${option.hdr ? 'Oui' : 'Non'}'),
                trailing: option.preset == state._selectedQuality ? const Icon(Icons.check_rounded) : null,
                onTap: option.available ? () => Navigator.of(context).pop(option.preset) : null,
              ),
            ),
          ],
        ),
      );
    },
  );

  if (selection != null && state.mounted) {
    await _playerChangeQuality(state, detail, selection);
  }
}

Future<void> _playerChangeQuality(
  _PlayerScreenState state,
  ContentDetailModel detail,
  VideoQualityPreset preset,
) async {
  if (state._selectedQuality == preset) return;
  final player = state._controller;
  final position = player?.value.isInitialized ?? false ? player!.value.position.inSeconds : 0;
  final wasPlaying = player?.value.isPlaying ?? true;
  final url = detail.resolvePlaybackUrl(preset);
  if (url == null || url.isEmpty) {
    state._showGesture('Qualité indisponible');
    return;
  }
  state.setState(() {
    state._isSwitchingQuality = true;
    state._selectedQuality = preset;
    state._playbackError = null;
  });
  await _playerInitializeController(
    state,
    url: url,
    localFilePath: null,
    seekToSeconds: position,
    autoPlay: wasPlaying,
    skipSegments: detail.skipSegments,
  );
  if (state.mounted && state._playbackError == null) {
    state._showGesture('Qualité ${preset.label}');
  }
}

Future<String?> _playerPickOption(
  _PlayerScreenState state, {
  required String title,
  required List<String> options,
  required String selected,
}) {
  return showModalBottomSheet<String>(
    context: state.context,
    backgroundColor: CinevaColors.surface,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(CinevaSpacing.lg),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            ...options.map(
              (option) => ListTile(
                title: Text(option),
                trailing: option == selected ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.of(context).pop(option),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _playerRetry(_PlayerScreenState state, ContentDetailModel detail) async {
  if (state._mediaSource?.isWebEmbed == true) {
    state.setState(() {
      state._playbackError = null;
      state._activeContentId = null;
    });
    return;
  }
  final currentPosition = state._controller?.value.isInitialized ?? false ? state._controller!.value.position.inSeconds : 0;
  final url = detail.resolvePlaybackUrl(state._selectedQuality) ?? detail.videoUrl;
  if (url == null) return;
  state.setState(() => state._playbackError = null);
  await _playerInitializeController(
    state,
    url: url,
    localFilePath: null,
    seekToSeconds: currentPosition,
    autoPlay: true,
    skipSegments: detail.skipSegments,
  );
}
