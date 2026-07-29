part of 'player_screen.dart';

enum _SeekDirection { backward, forward }

void _playerHandleDoubleTap(_PlayerScreenState state, BuildContext context) {
  final position = state._doubleTapPosition;
  final player = state._controller;
  if (position == null || player == null || !player.value.isInitialized) return;
  final width = MediaQuery.of(context).size.width;
  final direction = position.dx < width / 2 ? _SeekDirection.backward : _SeekDirection.forward;
  state._seekRelative(direction == _SeekDirection.forward ? 10 : -10);
}

void _playerHandleVerticalGesture(
  _PlayerScreenState state,
  BuildContext context,
  DragUpdateDetails details,
) {
  final player = state._controller;
  if (player == null || !player.value.isInitialized) return;
  final width = MediaQuery.of(context).size.width;
  final delta = -(details.delta.dy / 240);
  if (details.localPosition.dx > width / 2) {
    final nextVolume = (state._volume + delta).clamp(0.0, 1.0).toDouble();
    state._controller?.setVolume(nextVolume);
    state.setState(() => state._volume = nextVolume);
    state._showGesture('Volume ${(nextVolume * 100).round()}%');
  } else {
    final nextBrightness = (state._brightnessOverlay - delta * 0.2).clamp(0.0, 0.35).toDouble();
    state.setState(() => state._brightnessOverlay = nextBrightness);
    state._showGesture('Luminosité ${((1 - nextBrightness) * 100).round()}%');
  }
}

void _playerHandleHorizontalGesture(_PlayerScreenState state, DragUpdateDetails details) {
  final player = state._controller;
  if (player == null || !player.value.isInitialized) return;
  final duration = player.value.duration.inSeconds;
  final current = player.value.position.inSeconds;
  final step = (details.delta.dx / 8).round();
  final target = (current + step).clamp(0, duration).toInt();
  player.seekTo(Duration(seconds: target));
  state._showGesture('Navigation ${PlayerFormatters.formatDuration(target)}');
}

void _playerShowGesture(_PlayerScreenState state, String message) {
  state._gestureTimer?.cancel();
  if (state.mounted) state.setState(() => state._gestureMessage = message);
  state._gestureTimer = Timer(const Duration(milliseconds: 900), () {
    if (state.mounted) state.setState(() => state._gestureMessage = null);
  });
}
