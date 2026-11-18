enum MediaSourceType {
  localFile,
  directVideo,
  directAudio,
  hls,
  dash,
  webEmbed,
}

class MediaSource {
  const MediaSource({required this.type, required this.value});

  final MediaSourceType type;
  final String value;

  bool get isWebEmbed => type == MediaSourceType.webEmbed;
  bool get isNativeMedia => !isWebEmbed;
}

class MediaSourceResolver {
  static MediaSource resolve(String value, {String? mimeType}) {
    final source = value.trim();
    if (source.isEmpty) {
      throw const FormatException('La source média est vide.');
    }

    final lower = source.toLowerCase();
    if (lower.startsWith('file://') || lower.startsWith('/') || RegExp(r'^[a-z]:[\\/]').hasMatch(source)) {
      return MediaSource(type: MediaSourceType.localFile, value: source);
    }

    final uri = Uri.tryParse(source);
    if (uri == null || !uri.hasScheme) {
      return MediaSource(type: MediaSourceType.localFile, value: source);
    }

    final path = uri.path.toLowerCase();
    final mime = mimeType?.split(';').first.trim().toLowerCase() ?? '';
    if (path.endsWith('.m3u8') ||
        lower.contains('.m3u8?') ||
        mime == 'application/vnd.apple.mpegurl' ||
        mime == 'application/x-mpegurl' ||
        mime == 'audio/mpegurl') {
      return MediaSource(type: MediaSourceType.hls, value: source);
    }
    if (path.endsWith('.mpd') ||
        lower.contains('.mpd?') ||
        mime == 'application/dash+xml') {
      return MediaSource(type: MediaSourceType.dash, value: source);
    }
    if (_hasExtension(path, <String>{'.mp3', '.m4a', '.aac', '.wav', '.flac', '.ogg', '.opus'}) ||
        mime.startsWith('audio/')) {
      return MediaSource(type: MediaSourceType.directAudio, value: source);
    }
    if (_hasExtension(path, <String>{'.mp4', '.webm', '.mov', '.mkv', '.avi', '.m4v', '.ts'}) ||
        mime.startsWith('video/')) {
      return MediaSource(type: MediaSourceType.directVideo, value: source);
    }

    // A URL without a known media extension is deliberately treated as a web
    // resource. This includes /iframe/... providers and embedded players.
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return MediaSource(type: MediaSourceType.webEmbed, value: source);
    }

    return MediaSource(type: MediaSourceType.localFile, value: source);
  }

  static bool _hasExtension(String path, Set<String> extensions) {
    return extensions.any(path.endsWith);
  }
}
