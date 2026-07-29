import 'package:cineva_models/cineva_models.dart';

abstract final class DownloadFileSupport {
  static String buildFileName({
    required String contentId,
    required VideoQualityPreset quality,
    required String url,
  }) {
    return '${contentId}_${quality.name}${guessExtension(url)}';
  }

  static String partialPath(String? localPath) {
    if (localPath == null || localPath.isEmpty) return '';
    return '$localPath.part';
  }

  static String guessExtension(String url) {
    final uri = Uri.tryParse(url);
    final path = uri?.path.toLowerCase() ?? url.toLowerCase();
    if (path.endsWith('.m3u8')) return '.m3u8';
    if (path.endsWith('.mpd')) return '.mpd';
    if (path.endsWith('.mp4')) return '.mp4';
    if (path.endsWith('.mov')) return '.mov';
    return '.bin';
  }
}
