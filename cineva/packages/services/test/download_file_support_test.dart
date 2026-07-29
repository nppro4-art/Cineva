import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_services/src/downloads/download_file_support.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds stable download file names and partial paths', () {
    final fileName = DownloadFileSupport.buildFileName(
      contentId: 'movie_1',
      quality: VideoQualityPreset.p1080,
      url: 'https://cdn.example.com/video.mp4?token=123',
    );

    expect(fileName, 'movie_1_p1080.mp4');
    expect(DownloadFileSupport.partialPath('/tmp/movie.mp4'), '/tmp/movie.mp4.part');
  });

  test('detects manifest extensions for offline filtering', () {
    expect(DownloadFileSupport.guessExtension('https://a/b/master.m3u8'), '.m3u8');
    expect(DownloadFileSupport.guessExtension('https://a/b/manifest.mpd'), '.mpd');
    expect(DownloadFileSupport.guessExtension('https://a/b/asset.bin'), '.bin');
  });
}
