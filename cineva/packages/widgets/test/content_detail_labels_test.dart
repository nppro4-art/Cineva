import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_widgets/src/user/content_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';

const ContentTileModel tile = ContentTileModel(
  id: 'movie_1',
  title: 'Interstellar',
  subtitle: 'Christopher Nolan',
  badge: '4K HDR',
  contentType: 'movie',
  year: 2014,
  durationMinutes: 169,
);

ContentDetailModel detail({double downloadSizeMb = 0, int? durationMinutes = 169}) {
  return ContentDetailModel(
    id: 'movie_1',
    contentType: 'movie',
    title: 'Interstellar',
    subtitle: 'Christopher Nolan',
    synopsis: 'Un voyage interstellaire.',
    badge: '4K HDR',
    genres: const <String>['Science-fiction'],
    castNames: const <String>['Matthew McConaughey'],
    audioLanguages: const <String>['Français', 'Anglais'],
    subtitleLanguages: const <String>['Français'],
    directorName: 'Christopher Nolan',
    downloadSizeMb: downloadSizeMb,
    availableQualities: const <VideoQualityOption>[],
    durationMinutes: durationMinutes,
  );
}

DownloadItemModel download(DownloadStatus status, {double progress = 0}) {
  return DownloadItemModel(
    contentId: 'movie_1',
    contentType: 'movie',
    progressPercent: progress,
    sizeMb: 2355,
    status: status,
    content: tile,
  );
}

void main() {
  group('detailDownloadStateLabel', () {
    test('aucun téléchargement : invitation à télécharger', () {
      expect(detailDownloadStateLabel(null), 'Télécharger');
    });

    test('libellés courts par statut', () {
      expect(detailDownloadStateLabel(download(DownloadStatus.queued)), 'En file');
      expect(
        detailDownloadStateLabel(download(DownloadStatus.downloading, progress: 0.42)),
        '42 %',
      );
      expect(detailDownloadStateLabel(download(DownloadStatus.paused)), 'En pause');
      expect(detailDownloadStateLabel(download(DownloadStatus.completed, progress: 1)), 'Hors ligne');
      expect(detailDownloadStateLabel(download(DownloadStatus.failed)), 'Échec');
      expect(detailDownloadStateLabel(download(DownloadStatus.deleted)), 'Télécharger');
    });
  });

  group('detailDownloadSizeLabel', () {
    test('taille publiée uniquement quand elle existe', () {
      expect(detailDownloadSizeLabel(detail(downloadSizeMb: 2355)), '2,3 Go');
      expect(detailDownloadSizeLabel(detail(downloadSizeMb: 850)), '850 Mo');
      expect(detailDownloadSizeLabel(detail()), '');
    });
  });

  group('detailDurationLabel', () {
    test('délègue au formatage commun des durées', () {
      expect(detailDurationLabel(detail()), '2 h 49');
      expect(detailDurationLabel(detail(durationMinutes: null)), '');
    });
  });

  group('detailProgressLabel', () {
    test('position et durée au format horloge', () {
      final PlaybackProgressModel progress = PlaybackProgressModel(
        contentId: 'movie_1',
        contentType: 'movie',
        positionSeconds: 75,
        durationSeconds: 600,
        updatedAt: DateTime(2026, 1, 1),
        content: tile,
      );
      expect(detailProgressLabel(progress), '01:15 / 10:00');
      expect(progress.progressPercent, closeTo(0.125, 0.0001));
    });
  });
}
