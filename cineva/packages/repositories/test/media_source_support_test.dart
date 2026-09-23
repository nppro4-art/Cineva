import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Une adresse qui renvoie une page web (iframe d'un lecteur tiers, lien de
/// visionnage) ne contient aucun flux décodable : le lecteur doit le dire tout
/// de suite au lieu d'échouer après un long chargement. Ces tests couvrent la
/// qualification locale (sans réseau) et la classification d'une réponse HTTP.
void main() {
  group('assessMediaSource — sources lisibles', () {
    test('fichier vidéo direct', () {
      final assessment = assessMediaSource('https://cdn.mon-site.fr/films/inception.2010.1080p.mp4');
      expect(assessment.kind, MediaSourceKind.directVideo);
      expect(assessment.isPlayable, isTrue);
      expect(assessment.explanation, isEmpty);
    });

    test('extension reconnue malgré les paramètres de requête', () {
      expect(
        assessMediaSource('https://cdn.example.com/film.MKV?token=abc&t=12').kind,
        MediaSourceKind.directVideo,
      );
      expect(
        assessMediaSource('https://cdn.example.com/film.webm#t=10').kind,
        MediaSourceKind.directVideo,
      );
    });

    test('flux HLS et DASH', () {
      expect(assessMediaSource('https://cdn.example.com/live/index.m3u8').kind, MediaSourceKind.hlsStream);
      expect(assessMediaSource('https://cdn.example.com/vod/master.mpd').kind, MediaSourceKind.dashStream);
      expect(
        assessMediaSource('https://cdn.example.com/playlist?profile=hls&file=.m3u8').kind,
        MediaSourceKind.hlsStream,
      );
    });

    test('fichier local : chemin POSIX, Windows et file://', () {
      expect(assessMediaSource('/storage/emulated/0/Cineva/film.mp4').kind, MediaSourceKind.localFile);
      expect(assessMediaSource(r'C:\Cineva\film.mp4').kind, MediaSourceKind.localFile);
      expect(assessMediaSource('file:///sdcard/film.mp4').kind, MediaSourceKind.localFile);
    });

    test('adresse non reconnue : on tente la lecture plutôt que de bloquer', () {
      final assessment = assessMediaSource(
        'https://xyz.supabase.co/storage/v1/object/public/media/film-1234',
      );
      expect(assessment.kind, MediaSourceKind.unknown);
      expect(assessment.isPlayable, isTrue);
    });
  });

  group('assessMediaSource — sources illisibles', () {
    test('iframe d’un hébergeur tiers', () {
      final assessment = assessMediaSource('https://sharecloudy.com/iframe/32542978');
      expect(assessment.kind, MediaSourceKind.webPage);
      expect(assessment.isPlayable, isFalse);
      expect(assessment.explanation, contains('page web'));
      expect(assessment.explanation, contains('HLS'));
    });

    test('liens de visionnage et lecteurs embarqués', () {
      expect(
        assessMediaSource('https://www.youtube.com/watch?v=gC4H01R').kind,
        MediaSourceKind.webPage,
      );
      expect(assessMediaSource('https://youtu.be/gC4H01R').kind, MediaSourceKind.webPage);
      expect(assessMediaSource('https://player.vimeo.com/video/12345').kind, MediaSourceKind.webPage);
      expect(assessMediaSource('https://site.example/embed/12345').kind, MediaSourceKind.webPage);
      expect(assessMediaSource('https://site.example/film.html').kind, MediaSourceKind.webPage);
    });

    test('fichier audio seul', () {
      final assessment = assessMediaSource('https://cdn.example.com/piste.mp3');
      expect(assessment.kind, MediaSourceKind.audioOnly);
      expect(assessment.isPlayable, isFalse);
      expect(assessment.explanation, contains('audio'));
    });

    test('adresse vide', () {
      expect(assessMediaSource(null).kind, MediaSourceKind.empty);
      expect(assessMediaSource('   ').kind, MediaSourceKind.empty);
      expect(assessMediaSource('').explanation, mediaSourceEmptyReason);
    });
  });

  group('mediaSourceBlockingReason', () {
    test('null pour une source lisible', () {
      expect(mediaSourceBlockingReason('https://cdn.example.com/film.mp4'), isNull);
      expect(mediaSourceBlockingReason('/sdcard/film.mp4'), isNull);
      expect(mediaSourceBlockingReason('https://cdn.example.com/master.m3u8'), isNull);
    });

    test('explication pour une page web', () {
      expect(mediaSourceBlockingReason('https://sharecloudy.com/iframe/1'), mediaSourceWebPageReason);
    });
  });

  group('classifyMediaStream', () {
    test('MP4 annoncé → lisible', () {
      final result = classifyMediaStream(statusCode: 200, contentType: 'video/mp4');
      expect(result.playable, isTrue);
      expect(result.kind, MediaSourceKind.directVideo);
      expect(result.message, contains('vidéo direct'));
    });

    test('HLS annoncé → lisible', () {
      final result = classifyMediaStream(
        statusCode: 200,
        contentType: 'application/vnd.apple.mpegurl',
      );
      expect(result.playable, isTrue);
      expect(result.kind, MediaSourceKind.hlsStream);
    });

    test('page HTML → illisible, même avec un statut 200', () {
      final result = classifyMediaStream(statusCode: 200, contentType: 'text/html; charset=utf-8');
      expect(result.playable, isFalse);
      expect(result.kind, MediaSourceKind.webPage);
      expect(result.message, mediaSourceWebPageReason);
    });

    test('audio → illisible', () {
      final result = classifyMediaStream(statusCode: 200, contentType: 'audio/mpeg');
      expect(result.playable, isFalse);
      expect(result.kind, MediaSourceKind.audioOnly);
    });

    test('accès refusé et introuvable', () {
      final forbidden = classifyMediaStream(statusCode: 403, contentType: 'text/html');
      expect(forbidden.playable, isFalse);
      expect(forbidden.message, contains('Accès refusé'));

      final missing = classifyMediaStream(statusCode: 404, contentType: null);
      expect(missing.playable, isFalse);
      expect(missing.message, contains('introuvable'));

      final server = classifyMediaStream(statusCode: 503, contentType: null);
      expect(server.message, contains('503'));
    });

    test('type générique : on ne bloque pas, on prévient', () {
      final result = classifyMediaStream(statusCode: 206, contentType: 'application/octet-stream');
      expect(result.playable, isTrue);
      expect(result.kind, MediaSourceKind.unknown);
      expect(result.message, contains('sans annoncer un format vidéo clair'));
    });

    test('réponse partielle 206 acceptée', () {
      expect(classifyMediaStream(statusCode: 206, contentType: 'video/mp4').playable, isTrue);
    });
  });

  group('probeFailureMessage', () {
    test('délai dépassé et domaine injoignable', () {
      final timeout = probeFailureMessage(
        DioException(
          requestOptions: RequestOptions(path: 'https://cdn.example.com/film.mp4'),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      expect(timeout, contains('délai'));

      final connection = probeFailureMessage(
        DioException(
          requestOptions: RequestOptions(path: 'https://cdn.example.com/film.mp4'),
          type: DioExceptionType.connectionError,
          message: 'nom inconnu',
        ),
      );
      expect(connection, contains('injoignable'));
    });
  });
}
