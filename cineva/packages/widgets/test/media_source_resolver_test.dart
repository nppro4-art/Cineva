import 'package:flutter_test/flutter_test.dart';
import 'package:cineva_widgets/src/player/media_source_resolver.dart';

void main() {
  group('MediaSourceResolver', () {
    test('detects direct video', () {
      expect(MediaSourceResolver.resolve('https://cdn.example.com/movie.mp4').type, MediaSourceType.directVideo);
    });

    test('detects audio', () {
      expect(MediaSourceResolver.resolve('https://cdn.example.com/song.mp3').type, MediaSourceType.directAudio);
    });

    test('detects HLS and DASH', () {
      expect(MediaSourceResolver.resolve('https://cdn.example.com/master.m3u8').type, MediaSourceType.hls);
      expect(MediaSourceResolver.resolve('https://cdn.example.com/manifest.mpd').type, MediaSourceType.dash);
    });

    test('detects HLS and DASH from MIME metadata', () {
      expect(
        MediaSourceResolver.resolve(
          'https://cdn.example.com/stream',
          mimeType: 'application/vnd.apple.mpegurl',
        ).type,
        MediaSourceType.hls,
      );
      expect(
        MediaSourceResolver.resolve(
          'https://cdn.example.com/manifest',
          mimeType: 'application/dash+xml',
        ).type,
        MediaSourceType.dash,
      );
    });

    test('detects direct media from MIME metadata', () {
      expect(
        MediaSourceResolver.resolve(
          'https://cdn.example.com/resource',
          mimeType: 'video/mp4',
        ).type,
        MediaSourceType.directVideo,
      );
      expect(
        MediaSourceResolver.resolve(
          'https://cdn.example.com/resource',
          mimeType: 'audio/aac',
        ).type,
        MediaSourceType.directAudio,
      );
    });

    test('detects iframe/provider URLs as web embeds', () {
      expect(MediaSourceResolver.resolve('https://sharecloudy.com/iframe/32542978').type, MediaSourceType.webEmbed);
    });

    test('detects local paths', () {
      expect(MediaSourceResolver.resolve(r'C:\\Films\\movie.mp4').type, MediaSourceType.localFile);
      expect(MediaSourceResolver.resolve('file:///storage/emulated/0/Movies/movie.mp4').type, MediaSourceType.localFile);
    });
  });
}