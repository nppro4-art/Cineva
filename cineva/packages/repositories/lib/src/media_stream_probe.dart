import 'dart:async';

import 'package:dio/dio.dart';

import 'media_source_support.dart';

/// Sonde de flux vidéo à destination de l'administrateur.
///
/// Objectif : dire **avant** la mise en ligne d'une fiche si l'adresse saisie
/// renvoie réellement un flux lisible, un fichier audio, une page web, ou une
/// erreur d'accès. Un administrateur qui colle une page (iframe d'un lecteur
/// tiers, lien de visionnage) obtient sinon un film publié qui échoue à la
/// lecture chez l'abonné, sans aucune explication.
///
/// La sonde se limite à une requête d'en-têtes sur l'adresse fournie par
/// l'administrateur : aucune exploration de site, aucun téléchargement du
/// contenu (le corps de la réponse est fermé dès les en-têtes reçues).
class MediaStreamProbe {
  MediaStreamProbe({Dio? dio, Duration timeout = const Duration(seconds: 12)})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: timeout,
                receiveTimeout: timeout,
                sendTimeout: timeout,
                followRedirects: true,
                maxRedirects: 5,
                // Les statuts 4xx/5xx sont des résultats utiles, pas des
                // exceptions : c'est la classification qui parle à l'écran.
                validateStatus: (int? status) => true,
                headers: <String, dynamic>{
                  'User-Agent': 'Cineva/1.0 (verification de flux administrateur)',
                  'Accept': 'video/*, application/vnd.apple.mpegurl, application/dash+xml, */*',
                },
              ),
            );

  final Dio _dio;

  /// Vérifie [url] : d'abord par qualification locale (aucune requête si
  /// l'adresse est manifestement une page web), puis par requête d'en-têtes.
  Future<MediaStreamProbeResult> probe(String url) async {
    final MediaSourceAssessment assessment = assessMediaSource(url);
    if (!assessment.isPlayable) {
      return MediaStreamProbeResult(
        playable: false,
        kind: assessment.kind,
        message: assessment.explanation,
      );
    }

    try {
      // 1. HEAD : suffisant sur la plupart des CDN et ne transfère rien.
      final Response<void> head = await _dio.head<void>(assessment.url);
      final String? headType = head.headers.value('content-type');
      final int headStatus = head.statusCode ?? 0;
      if (headStatus > 0 &&
          headStatus < 400 &&
          headType != null &&
          headType.isNotEmpty &&
          !headType.toLowerCase().startsWith('text/html')) {
        return classifyMediaStream(
          statusCode: headStatus,
          contentType: headType,
          effectiveUrl: head.realUri.toString(),
        );
      }

      // 2. Beaucoup de serveurs refusent HEAD : on ouvre un GET en mode flux.
      //    Les en-têtes arrivent seules ; le corps est refermé immédiatement,
      //    donc le fichier n'est pas téléchargé.
      final Response<dynamic> get = await _dio.get<dynamic>(
        assessment.url,
        options: Options(
          responseType: ResponseType.stream,
          headers: <String, dynamic>{'Range': 'bytes=0-2047'},
        ),
      );
      final String? type = get.headers.value('content-type');
      final int status = get.statusCode ?? 0;
      final String effective = get.realUri.toString();
      // Le corps n'est jamais téléchargé : on referme le flux dès les en-têtes.
      final dynamic body = get.data;
      final StreamSubscription<dynamic>? subscription = body?.stream?.listen(null);
      await subscription?.cancel();

      return classifyMediaStream(
        statusCode: status,
        contentType: type,
        effectiveUrl: effective,
      );
    } on DioException catch (error) {
      return MediaStreamProbeResult(
        playable: false,
        kind: MediaSourceKind.unknown,
        message: probeFailureMessage(error),
        statusCode: error.response?.statusCode,
        contentType: error.response?.headers.value('content-type'),
      );
    }
  }
}

/// Résultat lisible d'une sonde de flux.
class MediaStreamProbeResult {
  const MediaStreamProbeResult({
    required this.playable,
    required this.message,
    required this.kind,
    this.statusCode,
    this.contentType,
    this.effectiveUrl,
  });

  /// `true` si un moteur de lecture a une chance réelle de lire cette adresse.
  final bool playable;

  /// Verdict en français, affichable tel quel.
  final String message;

  /// Nature détectée.
  final MediaSourceKind kind;

  final int? statusCode;
  final String? contentType;

  /// Adresse finale après redirections éventuelles.
  final String? effectiveUrl;

  @override
  String toString() =>
      'MediaStreamProbeResult(playable: $playable, status: $statusCode, type: $contentType)';
}

/// Classe une réponse HTTP sans accès réseau — fonction pure, testable.
MediaStreamProbeResult classifyMediaStream({
  required int? statusCode,
  required String? contentType,
  String? effectiveUrl,
}) {
  final int status = statusCode ?? 0;
  final String type = (contentType ?? '').toLowerCase().split(';').first.trim();

  if (status >= 400) {
    return MediaStreamProbeResult(
      playable: false,
      kind: MediaSourceKind.unknown,
      statusCode: status,
      contentType: contentType,
      effectiveUrl: effectiveUrl,
      message: _statusMessage(status),
    );
  }

  if (type.startsWith('video/')) {
    return MediaStreamProbeResult(
      playable: true,
      kind: MediaSourceKind.directVideo,
      statusCode: status,
      contentType: contentType,
      effectiveUrl: effectiveUrl,
      message: 'Flux vidéo direct détecté ($type). Lisible par le lecteur.',
    );
  }

  if (type.contains('mpegurl')) {
    return MediaStreamProbeResult(
      playable: true,
      kind: MediaSourceKind.hlsStream,
      statusCode: status,
      contentType: contentType,
      effectiveUrl: effectiveUrl,
      message: 'Flux HLS détecté ($type). Lisible par le lecteur.',
    );
  }

  if (type.contains('dash+xml') || type.contains('mpd')) {
    return MediaStreamProbeResult(
      playable: true,
      kind: MediaSourceKind.dashStream,
      statusCode: status,
      contentType: contentType,
      effectiveUrl: effectiveUrl,
      message: 'Flux DASH détecté ($type). Lisible sur desktop, à tester sur mobile.',
    );
  }

  if (type.startsWith('audio/')) {
    return MediaStreamProbeResult(
      playable: false,
      kind: MediaSourceKind.audioOnly,
      statusCode: status,
      contentType: contentType,
      effectiveUrl: effectiveUrl,
      message: mediaSourceAudioReason,
    );
  }

  if (type.startsWith('text/html') || type.startsWith('application/xhtml')) {
    return MediaStreamProbeResult(
      playable: false,
      kind: MediaSourceKind.webPage,
      statusCode: status,
      contentType: contentType,
      effectiveUrl: effectiveUrl,
      message: mediaSourceWebPageReason,
    );
  }

  // Type absent ou générique (`application/octet-stream`) : de nombreux
  // serveurs annoncent mal un MP4 parfaitement lisible. On ne bloque pas, on
  // prévient.
  final String label = type.isEmpty ? 'type de contenu non annoncé' : type;
  return MediaStreamProbeResult(
    playable: true,
    kind: MediaSourceKind.unknown,
    statusCode: status,
    contentType: contentType,
    effectiveUrl: effectiveUrl,
    message: 'Le serveur répond ($label) sans annoncer un format vidéo clair. '
        'Enregistrez puis testez la lecture ; si elle échoue, l’adresse n’est '
        'pas un fichier vidéo direct.',
  );
}

String _statusMessage(int status) {
  if (status == 401 || status == 403) {
    return 'Accès refusé par le serveur (HTTP $status) : ce lien exige une '
        'session, un jeton ou un site référent. Ce n’est pas un flux ouvert, '
        'le lecteur ne pourra pas le lire.';
  }
  if (status == 404 || status == 410) {
    return 'Fichier introuvable (HTTP $status) : l’adresse est cassée ou le '
        'fichier a été retiré.';
  }
  if (status == 429) {
    return 'Trop de requêtes (HTTP 429) : le serveur limite l’accès. Réessayez '
        'plus tard.';
  }
  if (status >= 500) {
    return 'Le serveur a échoué (HTTP $status). Réessayez plus tard.';
  }
  return 'Le serveur a répondu HTTP $status.';
}

/// Message lisible pour un échec de requête (réseau, TLS, délai).
String probeFailureMessage(DioException error) {
  final String? message = error.message;
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Le serveur n’a pas répondu dans le délai imparti. L’adresse est '
          'peut-être protégée contre les accès automatisés, ou injoignable.';
    case DioExceptionType.connectionError:
      return 'Nom de domaine injoignable ou connexion refusée ($message).';
    case DioExceptionType.badCertificate:
      return 'Certificat TLS invalide : la connexion chiffrée a été refusée.';
    case DioExceptionType.cancel:
      return 'Vérification interrompue.';
    case DioExceptionType.badResponse:
      return _statusMessage(error.response?.statusCode ?? 0);
    // `unknown`, et selon la version de dio `transformTimeout` : on ne nomme
    // pas les valeurs apparues après 5.7 pour rester compilable partout.
    default:
      return 'Impossible de joindre cette adresse ou de traiter sa réponse '
          '($message).';
  }
}
