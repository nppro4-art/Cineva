import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

/// Réponses réelles d'Internet Archive (formes tronquées mais fidèles) :
/// `year` et `downloads` arrivent en nombres, `size`/`length`/`height` en
/// chaînes, `title` peut être une liste, `description` contient du HTML.
const Map<String, dynamic> _searchJson = <String, dynamic>{
  'responseHeader': <String, dynamic>{'status': 0, 'QTime': 47},
  'response': <String, dynamic>{
    'numFound': 28470,
    'start': 0,
    'docs': <Map<String, dynamic>>[
      <String, dynamic>{
        'downloads': 4557821,
        'identifier': 'HisNewJobCharlesChaplin-1915',
        'title': "CUKESIM's New Job! ( Charles Chaplin-1915)",
      },
      <String, dynamic>{
        'downloads': 3719675,
        'identifier': 'sex_madness',
        'title': 'Sex Madness',
        'year': 1938,
      },
    ],
  },
};

Map<String, dynamic> _itemJson() => <String, dynamic>{
      'dir': '/0/items/sex_madness',
      'server': 'dn800304.us.archive.org',
      'files': <Map<String, dynamic>>[
        <String, dynamic>{'name': '__ia_thumb.jpg', 'source': 'original', 'format': 'JPEG Thumb', 'size': '10287'},
        <String, dynamic>{'name': 'sex_madness.asr.srt', 'source': 'original', 'format': 'SubRip', 'size': '35248'},
        <String, dynamic>{
          'name': 'sex_madness.mp3',
          'source': 'derivative',
          'format': 'MP3',
          'length': '51:57',
          'height': '0',
          'width': '0',
        },
        <String, dynamic>{
          'name': 'sex_madness.mp4',
          'source': 'derivative',
          'format': 'h.264',
          'original': 'sex_madness.mpeg',
          'size': '324928028',
          'length': '3117.52',
          'height': '480',
          'width': '640',
        },
        <String, dynamic>{
          'name': 'sex_madness.mpeg',
          'source': 'original',
          'format': 'MPEG2',
          'height': '720',
          'width': '720',
          'length': '3117.48',
          'size': '2054154246',
        },
        <String, dynamic>{
          'name': 'sex_madness.ogv',
          'source': 'derivative',
          'format': 'Ogg Video',
          'length': '3117.39',
          'height': '304',
          'width': '400',
        },
        <String, dynamic>{'name': 'sex_madness.thumbs/sex_madness_000001.jpg', 'source': 'derivative', 'format': 'Thumbnail'},
      ],
      'metadata': <String, dynamic>{
        'identifier': 'sex_madness',
        'mediatype': 'movies',
        'title': 'Sex Madness',
        'description': '<p>Un film de propagande de 1938.</p>\n<p>Restauré par l’archive.</p>',
        'year': '1938',
        'creator': 'Dwain Esper',
        'subject': <String>['Feature Film', 'Drama', 'Public Domain'],
        'language': 'English',
        'licenseurl': 'http://creativecommons.org/licenses/publicdomain/',
        'collection': <String>['feature_films', 'publicdomain'],
      },
    };

void main() {
  group('ArchiveOrgReference.tryParse', () {
    test('lien d’un élément', () {
      final reference = ArchiveOrgReference.tryParse('https://archive.org/details/sex_madness');

      expect(reference!.kind, ArchiveOrgSourceKind.item);
      expect(reference.value, 'sex_madness');
      expect(reference.isItem, isTrue);
    });

    test('lien de recherche', () {
      final reference = ArchiveOrgReference.tryParse('https://archive.org/search?query=charlie+chaplin');

      expect(reference!.kind, ArchiveOrgSourceKind.query);
      expect(reference.value, 'charlie chaplin');
    });

    test('syntaxe courte collection:', () {
      final reference = ArchiveOrgReference.tryParse('collection:feature_films');

      expect(reference!.kind, ArchiveOrgSourceKind.collection);
      expect(reference.isCollection, isTrue);
      expect(reference.value, 'feature_films');
    });

    test('identifiant nu et mots-clés libres', () {
      expect(ArchiveOrgReference.tryParse('sex_madness')!.kind, ArchiveOrgSourceKind.item);
      expect(
        ArchiveOrgReference.tryParse('night of the living dead')!.kind,
        ArchiveOrgSourceKind.query,
      );
    });

    test('entrée vide ou hors Internet Archive : rien d’exploitable', () {
      expect(ArchiveOrgReference.tryParse(''), isNull);
      expect(ArchiveOrgReference.tryParse('   '), isNull);
      // Une source qui n'est pas archive.org n'est pas énumérable par ce client :
      // il ne va chercher ni flux ni liens sur un site tiers.
      expect(ArchiveOrgReference.tryParse('https://fopov.com/aww2u06rk/home/fopov'), isNull);
      expect(ArchiveOrgReference.tryParse('https://1337x.to/search/inception/'), isNull);
    });
  });

  group('ArchiveOrgClient.buildSearchQuery', () {
    test('une recherche libre est limitée aux films', () {
      expect(
        ArchiveOrgClient.buildSearchQuery('night of the living dead'),
        'night of the living dead AND mediatype:(movies)',
      );
    });

    test('une requête déjà qualifiée n’est pas modifiée', () {
      expect(ArchiveOrgClient.buildSearchQuery('collection:feature_films'), 'collection:feature_films');
      expect(
        ArchiveOrgClient.buildSearchQuery('title:(nosferatu) AND mediatype:movies'),
        'title:(nosferatu) AND mediatype:movies',
      );
    });
  });

  group('ArchiveOrgClient.parseSearchResponse', () {
    test('champs manquants tolérés, nombres lus', () {
      final hits = ArchiveOrgClient.parseSearchResponse(_searchJson);

      expect(hits, hasLength(2));
      expect(hits.first.identifier, 'HisNewJobCharlesChaplin-1915');
      expect(hits.first.releaseYear, isNull);
      expect(hits.first.downloads, 4557821);
      expect(hits.last.identifier, 'sex_madness');
      expect(hits.last.releaseYear, 1938);
    });

    test('réponse inattendue : liste vide, jamais d’exception', () {
      expect(ArchiveOrgClient.parseSearchResponse(null), isEmpty);
      expect(ArchiveOrgClient.parseSearchResponse(<String, dynamic>{}), isEmpty);
      expect(ArchiveOrgClient.parseSearchResponse('erreur html'), isEmpty);
    });
  });

  group('ArchiveOrgClient.parseItemMetadata', () {
    test('le MP4 dérivé est choisi, pas l’original MPEG2 ni l’Ogg', () {
      final draft = ArchiveOrgClient.parseItemMetadata('sex_madness', _itemJson());

      expect(draft, isNotNull);
      expect(draft!.videoFileName, 'sex_madness.mp4');
      expect(draft.videoUrl, 'https://archive.org/download/sex_madness/sex_madness.mp4');
      expect(draft.videoWidth, 640);
      expect(draft.videoHeight, 480);
      expect(draft.resolutionLabel, '640×480');
      expect(draft.videoSizeBytes, 324928028);
    });

    test('durée dérivée du fichier, pas devinée', () {
      final draft = ArchiveOrgClient.parseItemMetadata('sex_madness', _itemJson());

      // 3117,52 s → 52 min.
      expect(draft!.durationMinutes, 52);
    });

    test('métadonnées : titre, année, réalisateur, synopsis nettoyé, genres', () {
      final draft = ArchiveOrgClient.parseItemMetadata('sex_madness', _itemJson());

      expect(draft!.title, 'Sex Madness');
      expect(draft.releaseYear, 1938);
      expect(draft.directorName, 'Dwain Esper');
      expect(draft.synopsis, contains('film de propagande'));
      expect(draft.synopsis, isNot(contains('<p>')));
      // « Feature Film » et « Public Domain » ne sont pas des genres.
      expect(draft.genres, <String>['Drama']);
      expect(draft.languages, <String>['English']);
    });

    test('affiche, page de l’élément et sous-titres réels', () {
      final draft = ArchiveOrgClient.parseItemMetadata('sex_madness', _itemJson());

      expect(draft!.posterUrl, 'https://archive.org/services/img/sex_madness');
      expect(draft.itemPageUrl, 'https://archive.org/details/sex_madness');
      expect(draft.subtitleUrl, 'https://archive.org/download/sex_madness/sex_madness.asr.srt');
    });

    test('licence lue dans la fiche', () {
      final draft = ArchiveOrgClient.parseItemMetadata('sex_madness', _itemJson());

      expect(draft!.licenseLabel, 'Domaine public');
      expect(draft.isLicenseOpen, isTrue);
    });

    test('sans licence déclarée : rien n’est affirmé', () {
      final json = _itemJson();
      (json['metadata'] as Map<String, dynamic>).remove('licenseurl');
      final draft = ArchiveOrgClient.parseItemMetadata('sex_madness', json);

      expect(draft!.licenseLabel, 'Licence non précisée');
      expect(draft.isLicenseOpen, isFalse);
    });

    test('aucun MP4 → élément écarté (jamais d’URL inventée)', () {
      final json = _itemJson();
      json['files'] = <Map<String, dynamic>>[
        <String, dynamic>{'name': 'film.mpeg', 'source': 'original', 'format': 'MPEG2', 'height': '720'},
        <String, dynamic>{'name': 'film.ogv', 'source': 'derivative', 'format': 'Ogg Video', 'height': '304'},
      ];

      expect(ArchiveOrgClient.parseItemMetadata('film', json), isNull);
    });

    test('fiche absente ou illisible → null', () {
      expect(ArchiveOrgClient.parseItemMetadata('x', <String, dynamic>{}), isNull);
      expect(ArchiveOrgClient.parseItemMetadata('x', null), isNull);
      expect(
        ArchiveOrgClient.parseItemMetadata('x', <String, dynamic>{'metadata': <String, dynamic>{}}),
        isNull,
      );
    });

    test('titre fourni sous forme de liste', () {
      final json = _itemJson();
      (json['metadata'] as Map<String, dynamic>)['title'] = <String>['Nosferatu', 'Nosferatu (1922)'];

      expect(ArchiveOrgClient.parseItemMetadata('nosferatu', json)!.title, 'Nosferatu');
    });

    test('une collection est reconnue comme telle', () {
      expect(
        ArchiveOrgClient.mediatypeOf(<String, dynamic>{
          'metadata': <String, dynamic>{'mediatype': 'collection'},
        }),
        'collection',
      );
      expect(ArchiveOrgClient.mediatypeOf(_itemJson()), 'movies');
    });
  });

  group('ArchiveOrgClient.downloadUrlFor', () {
    test('chemin simple et sous-dossier encodés', () {
      expect(
        ArchiveOrgClient.downloadUrlFor('sex_madness', 'sex_madness.mp4'),
        'https://archive.org/download/sex_madness/sex_madness.mp4',
      );
      expect(
        ArchiveOrgClient.downloadUrlFor('item', 'derives/mon film 512kb.mp4'),
        'https://archive.org/download/item/derives/mon%20film%20512kb.mp4',
      );
    });
  });

  group('ArchiveOrgItemDraft.toCatalogItem', () {
    test('film non publié par défaut, URL vidéo en place', () {
      final item = ArchiveOrgClient.parseItemMetadata('sex_madness', _itemJson())!.toCatalogItem();

      expect(item.contentType, 'movie');
      expect(item.id, '');
      expect(item.isPublished, isFalse);
      expect(item.isFeatured, isFalse);
      expect(item.videoPath, 'https://archive.org/download/sex_madness/sex_madness.mp4');
      expect(item.posterPath, 'https://archive.org/services/img/sex_madness');
      expect(item.releaseYear, 1938);
      expect(item.durationMinutes, 52);
      expect(item.metadata['source'], 'archive_org');
      expect(item.metadata['archive_identifier'], 'sex_madness');
      expect(item.metadata['archive_license_open'], isTrue);
    });

    test('publication immédiate et catégorie sur demande', () {
      final item = ArchiveOrgClient.parseItemMetadata('sex_madness', _itemJson())!
          .toCatalogItem(isPublished: true, categoryIds: <String>['cat-1']);

      expect(item.isPublished, isTrue);
      expect(item.categoryIds, <String>['cat-1']);
    });
  });
}
