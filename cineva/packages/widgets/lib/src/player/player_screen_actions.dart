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
  final selection = await showCinevaSheet<VideoQualityPreset>(
    context: state.context,
    builder: (BuildContext sheetContext) {
      final resolvedCurrent = _resolveSelectedQualityOption(
        detail.availableQualities,
        state._selectedQuality,
      );
      final List<String> flags = <String>[
        if (resolvedCurrent.hdr) 'HDR',
        if (resolvedCurrent.dolbyVision) 'Dolby Vision',
        if (resolvedCurrent.dolbyAtmos) 'Dolby Atmos',
      ];

      return CinevaSheetContainer(
        title: 'Qualité vidéo',
        subtitle: 'Flux actuel : ${resolvedCurrent.resolutionLabel} · '
            '${_mbps(resolvedCurrent.bitrateMbps)} Mb/s'
            '${flags.isEmpty ? '' : ' · ${flags.join(' · ')}'}',
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: <Widget>[
            ...detail.availableQualities.map(
              (VideoQualityOption option) => CinevaSheetOption<VideoQualityPreset>(
                value: option.preset,
                label: option.preset.label,
                subtitle: '${option.resolutionLabel} · ${_mbps(option.bitrateMbps)} Mb/s'
                    '${option.hdr ? ' · HDR' : ''}'
                    '${option.dolbyVision ? ' · Dolby Vision' : ''}'
                    '${option.dolbyAtmos ? ' · Atmos' : ''}',
                selected: option.preset == state._selectedQuality,
                enabled: option.available,
                trailing: option.available
                    ? null
                    : const Text('Indisponible', style: CinevaTypography.meta),
                onSelected: (VideoQualityPreset preset) =>
                    Navigator.of(sheetContext).pop(preset),
              ),
            ),
            const SizedBox(height: CinevaSpacing.sm),
          ],
        ),
      );
    },
  );

  if (selection != null && state.mounted) {
    await _playerChangeQuality(state, detail, selection);
  }
}

/// Débit formaté à la française (« 8,5 »).
String _mbps(double value) => value.toStringAsFixed(1).replaceAll('.', ',');

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
  return showCinevaSheet<String>(
    context: state.context,
    builder: (BuildContext sheetContext) => CinevaSheetContainer(
      title: title,
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: <Widget>[
          ...options.map(
            (String option) => CinevaSheetOption<String>(
              value: option,
              label: option,
              selected: option == selected,
              onSelected: (String value) => Navigator.of(sheetContext).pop(value),
            ),
          ),
          const SizedBox(height: CinevaSpacing.sm),
        ],
      ),
    ),
  );
}

Future<void> _playerRetry(_PlayerScreenState state, ContentDetailModel detail) async {
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
