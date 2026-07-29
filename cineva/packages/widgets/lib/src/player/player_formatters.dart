abstract final class PlayerFormatters {
  static String formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$secs';
    return '$minutes:$secs';
  }

  static String formatEta(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remain = seconds % 60;
    return '${minutes}m ${remain.toString().padLeft(2, '0')}s';
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = <String>['B', 'KB', 'MB', 'GB'];
    double value = bytes.toDouble();
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index += 1;
    }
    return '${value.toStringAsFixed(index == 0 ? 0 : 1)} ${units[index]}';
  }
}
