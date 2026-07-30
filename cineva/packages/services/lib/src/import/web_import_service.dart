import 'dart:convert';

import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service d'import de contenu depuis une URL web.
///
/// Le scraping lui-même est effectué côté serveur par la Supabase Edge
/// Function `import-from-url` (pour éviter les blocages CORS du web). Ce
/// service orchestre l'appel, applique l'allowlist de domaines, et insère
/// (ou fusionne) les éléments dans le catalogue.
class WebImportService {
  WebImportService({required SupabaseClient client}) : _client = client;

  static const String _functionName = 'import-from-url';
  static const String _allowlistKey = 'allowed_import_domains';

  final SupabaseClient _client;

  /// Analyse une URL et renvoie les éléments détectés.
  ///
  /// [allowedDomains] : si non vide, seul un hôte présent dans cette liste
  /// (ou un sous-domaine) est autorisé → sécurise l'import (navigateur sûr).
  Future<List<ImportedContentItem>> analyze(
    String url, {
    Map<String, String>? selectors,
    List<String>? allowedDomains,
  }) async {
    if (allowedDomains != null && allowedDomains.isNotEmpty) {
      final host = Uri.parse(url).host.toLowerCase();
      final ok = allowedDomains.any(
        (d) =>
            host == d.toLowerCase() || host.endsWith('.${d.toLowerCase()}'),
      );
      if (!ok) {
        throw AppFailure(
          'Domaine non autorisé pour l’import : $host',
          code: 'IMPORT_DOMAIN_BLOCKED',
        );
      }
    }

    final response = await _client.functions.invoke(
      _functionName,
      body: <String, dynamic>{
        'url': url,
        if (selectors != null) 'selectors': selectors,
      },
    );

    if (response.status != 200) {
      final data = response.data;
      final String detail;
      if (data is Map && data['error'] != null) {
        detail = data['error'].toString();
      } else if (data is String) {
        detail = data;
      } else {
        detail = 'HTTP ${response.status}';
      }
      throw AppFailure('Import impossible : $detail', code: 'IMPORT_FAILED');
    }

    final dynamic rawData = response.data;
    final Map<String, dynamic> json = rawData is String
        ? (jsonDecode(rawData) as Map<String, dynamic>)
        : Map<String, dynamic>.from(rawData as Map);
    final List<dynamic> rows = (json['items'] as List? ?? const <dynamic>[]);
    return rows.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Insère les éléments sélectionnés dans le catalogue.
  ///
  /// Si un film de même titre existe déjà, les langues sont fusionnées et la
  /// meilleure qualité est conservée (au lieu de créer un doublon).
  Future<int> importItems(
    List<ImportedContentItem> items,
    AdminRepository repo,
  ) async {
    var imported = 0;
    for (final item in items) {
      final existing = await _findExistingAsync(repo, item);
      if (existing != null) {
        final merged = _merge(existing, item);
        if (existing.isSeries) {
          await repo.saveSeries(merged);
        } else {
          await repo.saveMovie(merged);
        }
      } else if (item.contentType == 'series') {
        await repo.saveSeries(item.toAdminCatalogItemModel());
      } else {
        await repo.saveMovie(item.toAdminCatalogItemModel());
      }
      imported++;
    }
    return imported;
  }

  /// Domaines autorisés pour l'import (stockés dans `app_settings`).
  Future<List<String>> fetchAllowedDomains() async {
    final res = await _client
        .from('app_settings')
        .select()
        .eq('key', _allowlistKey)
        .maybeSingle();
    if (res == null) return const <String>[];
    final domains = (res['value_json'] as Map<String, dynamic>)['domains'];
    if (domains is List) {
      return domains.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    return const <String>[];
  }

  Future<void> saveAllowedDomains(List<String> domains) async {
    await _client.from('app_settings').upsert(<String, dynamic>{
      'key': _allowlistKey,
      'value_json': <String, dynamic>{'domains': domains},
      'description': 'Domaines autorisés pour l’import depuis URL.',
    });
  }

  Future<AdminCatalogItemModel?> _findExistingAsync(
    AdminRepository repo,
    ImportedContentItem item,
  ) async {
    final list = await repo.fetchMovies(query: item.title);
    final norm = _normalize(item.title);
    for (final m in list) {
      if (_normalize(m.title) == norm) return m;
    }
    return null;
  }

  AdminCatalogItemModel _merge(
    AdminCatalogItemModel existing,
    ImportedContentItem incoming,
  ) {
    final audio = <String>{...existing.audioLanguages, ...incoming.audioLanguages};
    final subs = <String>{
      ...existing.subtitleLanguages,
      ...incoming.subtitleLanguages
    };
    final existingRank = _qualityRank(_qualityOf(existing));
    final incomingRank = _qualityRank(incoming.quality);
    final quality = incomingRank > existingRank
        ? incoming.quality
        : _qualityOf(existing);

    return existing.copyWith(
      audioLanguages: audio.toList(),
      subtitleLanguages: subs.toList(),
      genres: <String>{...existing.genres, ...incoming.genres}.toList(),
      posterPath: existing.posterPath ?? incoming.posterPath,
      backdropPath: existing.backdropPath ?? incoming.backdropPath,
      releaseYear: existing.releaseYear ?? incoming.releaseYear,
      isPublished: true,
      metadata: <String, dynamic>{
        ...existing.metadata,
        if (quality != null) 'quality': quality,
        if (incoming.sourceUrl != null)
          'sourceUrl': incoming.sourceUrl,
      },
    );
  }

  String? _qualityOf(AdminCatalogItemModel m) => m.metadata['quality'] as String?;

  String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  int _qualityRank(String? q) {
    if (q == null) return -1;
    const ranks = <String, int>{
      'CAM': 0,
      'TS': 1,
      'HD': 2,
      '720P': 3,
      '1080P': 4,
      'WEBRIP': 4,
      'WEB-DL': 4,
      'BLURAY': 5,
      'BRIP': 5,
      '2160P': 6,
      '4K': 6,
    };
    return ranks[q.toUpperCase()] ?? -1;
  }

  ImportedContentItem _fromJson(Map<String, dynamic> j) => ImportedContentItem(
        contentType: j['contentType'] == 'series' ? 'series' : 'movie',
        title: (j['title'] as String? ?? '').trim(),
        originalTitle: j['originalTitle'] as String?,
        synopsis: j['synopsis'] as String?,
        posterPath: j['posterPath'] as String?,
        backdropPath: j['backdropPath'] as String?,
        releaseYear: j['releaseYear'] as int?,
        durationMinutes: j['durationMinutes'] as int?,
        ageRating: j['ageRating'] as String?,
        directorName: j['directorName'] as String?,
        genres: List<String>.from((j['genres'] as List?) ?? const <dynamic>[]),
        castNames:
            List<String>.from((j['castNames'] as List?) ?? const <dynamic>[]),
        countries:
            List<String>.from((j['countries'] as List?) ?? const <dynamic>[]),
        audioLanguages: List<String>.from(
          (j['audioLanguages'] as List?) ?? const <dynamic>[],
        ),
        subtitleLanguages: List<String>.from(
          (j['subtitleLanguages'] as List?) ?? const <dynamic>[],
        ),
        quality: j['quality'] as String?,
        sourceUrl: j['sourceUrl'] as String?,
        rating: (j['rating'] as num?)?.toDouble(),
      );
}
