import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_services/cineva_services.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'catalog_repository.dart';
import 'member_profile_scope.dart';
import 'user_library_json_codec.dart';
import 'user_library_repository.dart';

class SupabaseUserLibraryRepository implements UserLibraryRepository {
  SupabaseUserLibraryRepository({
    required BackendService backendService,
    required LocalPreferencesService localPreferencesService,
    required DeviceFingerprintService deviceFingerprintService,
    required CatalogRepository catalogRepository,
    MemberProfileScope? profileScope,
  })  : _backendService = backendService,
        _localPreferencesService = localPreferencesService,
        _deviceFingerprintService = deviceFingerprintService,
        _catalogRepository = catalogRepository,
        _profileScope = profileScope ?? MemberProfileScope();

  final BackendService _backendService;
  final LocalPreferencesService _localPreferencesService;
  final DeviceFingerprintService _deviceFingerprintService;
  final CatalogRepository _catalogRepository;

  /// Profil membre actif : ses favoris et sa reprise ne se mélangent pas avec
  /// ceux des autres profils du foyer. Sans profil choisi (ou base non
  /// migrée), les requêtes restent exactement celles d'avant.
  final MemberProfileScope _profileScope;

  @override
  Future<DownloadItemModel> enqueueDownload(ContentDetailModel detail) async {
    final item = DownloadItemModel(
      contentId: detail.id,
      contentType: detail.contentType,
      progressPercent: 0,
      sizeMb: detail.downloadSizeMb,
      status: DownloadStatus.queued,
      content: detail.toTile(),
      updatedAt: DateTime.now(),
      downloadedBytes: 0,
      totalBytes: 0,
      localFilePath: null,
    );

    if (await _canUseSupabase(detail.id)) {
      final client = await _client();
      final fingerprint = await _deviceFingerprintService.getOrCreateFingerprint();
      await client.from('downloads').upsert(<String, dynamic>{
        'user_id': client.auth.currentUser!.id,
        'content_type': detail.contentType,
        'content_id': detail.id,
        'local_device_fingerprint': fingerprint,
        'status': 'queued',
        'progress_percent': 0,
        'downloaded_bytes': 0,
        'total_bytes': 0,
      });
    }

    await _upsertLocalDownload(item);
    return item;
  }

  @override
  Future<List<PlaybackProgressModel>> fetchContinueWatching() async {
    final localItems = await _fetchLocalProgress().then((items) => items.where((item) => !item.isCompleted).toList());

    if (!await _canUseSupabase()) {
      localItems.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return localItems;
    }

    try {
      final client = await _client();
      final profileId = _profileScope.activeProfileId;
      var query = client.from(SupabaseConstants.historyTable).select();
      if (profileId != null) query = query.eq('profile_id', profileId);
      final rows = await query.order('last_watched_at', ascending: false).limit(20);

      final results = <PlaybackProgressModel>[];
      for (final row in rows) {
        final contentId = row['content_id'] as String;
        final contentType = row['content_type'] as String;
        final detail = await _catalogRepository.fetchContentDetail(contentId);
        final tile = detail?.toTile(
              progressPercent: ((row['progress_percent'] as num?)?.toDouble() ?? 0) / 100,
            ) ??
            _fallbackTile(contentId: contentId, contentType: contentType);

        final model = PlaybackProgressModel(
          contentId: contentId,
          contentType: contentType,
          positionSeconds: row['current_position_seconds'] as int? ?? 0,
          durationSeconds: row['total_duration_seconds'] as int? ?? 0,
          updatedAt: DateTime.tryParse(row['last_watched_at'] as String? ?? '') ?? DateTime.now(),
          content: tile,
        );
        if (!model.isCompleted) {
          results.add(model);
        }
      }

      if (results.isNotEmpty) return results;
    } catch (_) {}

    localItems.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return localItems;
  }

  @override
  Future<List<DownloadItemModel>> fetchDownloads() async {
    final local = await _fetchLocalDownloads();
    if (!await _canUseSupabase()) return local;

    try {
      final client = await _client();
      final rows = await client.from('downloads').select().order('updated_at', ascending: false).limit(30);

      final items = <DownloadItemModel>[];
      for (final row in rows) {
        final contentId = row['content_id'] as String;
        final detail = await _catalogRepository.fetchContentDetail(contentId);
        final tile = detail?.toTile() ?? _fallbackTile(contentId: contentId, contentType: row['content_type'] as String);
        items.add(
          DownloadItemModel(
            contentId: contentId,
            contentType: row['content_type'] as String,
            progressPercent: ((row['progress_percent'] as num?)?.toDouble() ?? 0) / 100,
            sizeMb: detail?.downloadSizeMb ?? 0,
            status: UserLibraryJsonCodec.statusFromString(row['status'] as String? ?? 'queued'),
            content: tile,
            updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
            downloadedBytes: row['downloaded_bytes'] as int? ?? 0,
            totalBytes: row['total_bytes'] as int? ?? 0,
            localFilePath: row['local_file_path'] as String?,
          ),
        );
      }

      if (items.isNotEmpty) {
        await _saveLocalDownloads(items);
        return items;
      }
    } catch (_) {}

    return local;
  }

  @override
  Future<Set<String>> fetchFavoriteIds() async {
    final profileId = _profileScope.activeProfileId;
    final local = await _localPreferencesService.readFavoriteIds(profileId: profileId);
    if (!await _canUseSupabase()) return local;

    try {
      final client = await _client();
      var query = client.from(SupabaseConstants.favoritesTable).select('content_id');
      if (profileId != null) query = query.eq('profile_id', profileId);
      final rows = await query;
      final ids = rows.map<String>((row) => row['content_id'] as String).toSet();
      if (ids.isNotEmpty) {
        await _localPreferencesService.saveFavoriteIds(ids, profileId: profileId);
        return ids;
      }
    } catch (_) {}

    return local;
  }

  @override
  Future<PlaybackProgressModel?> fetchProgress({required String contentId, required String contentType}) async {
    final local = await _fetchLocalProgress();
    PlaybackProgressModel? localMatch;
    for (final item in local) {
      if (item.contentId == contentId && item.contentType == contentType) {
        localMatch = item;
        break;
      }
    }

    if (!await _canUseSupabase(contentId)) return localMatch;

    try {
      final client = await _client();
      final profileId = _profileScope.activeProfileId;
      var query = client.from(SupabaseConstants.historyTable).select().eq('content_id', contentId).eq('content_type', contentType);
      if (profileId != null) query = query.eq('profile_id', profileId);
      final row = await query.maybeSingle();
      if (row == null) return localMatch;
      final detail = await _catalogRepository.fetchContentDetail(contentId);
      return PlaybackProgressModel(
        contentId: contentId,
        contentType: contentType,
        positionSeconds: row['current_position_seconds'] as int? ?? 0,
        durationSeconds: row['total_duration_seconds'] as int? ?? 0,
        updatedAt: DateTime.tryParse(row['last_watched_at'] as String? ?? '') ?? DateTime.now(),
        content: detail?.toTile(progressPercent: ((row['progress_percent'] as num?)?.toDouble() ?? 0) / 100) ??
            _fallbackTile(contentId: contentId, contentType: contentType),
      );
    } catch (_) {
      return localMatch;
    }
  }

  @override
  Future<void> removeDownload(String contentId) async {
    if (await _canUseSupabase(contentId)) {
      try {
        final client = await _client();
        await client.from('downloads').delete().eq('content_id', contentId);
      } catch (_) {}
    }

    final current = await _fetchLocalDownloads();
    current.removeWhere((item) => item.contentId == contentId);
    await _saveLocalDownloads(current);
  }

  @override
  Future<void> savePlaybackProgress({
    required ContentTileModel content,
    required int positionSeconds,
    required int durationSeconds,
  }) async {
    final progress = PlaybackProgressModel(
      contentId: content.id,
      contentType: content.contentType,
      positionSeconds: positionSeconds,
      durationSeconds: durationSeconds,
      updatedAt: DateTime.now(),
      content: content.copyWith(progressPercent: durationSeconds <= 0 ? 0 : positionSeconds / durationSeconds),
    );

    await _upsertLocalProgress(progress);

    if (await _canUseSupabase(content.id)) {
      try {
        final client = await _client();
        final profileId = _profileScope.activeProfileId;
        final payload = <String, dynamic>{
          'user_id': client.auth.currentUser!.id,
          'content_type': content.contentType,
          'content_id': content.id,
          'current_position_seconds': positionSeconds,
          'total_duration_seconds': durationSeconds,
          'progress_percent': progress.progressPercent * 100,
          'is_completed': progress.isCompleted,
          'last_watched_at': DateTime.now().toIso8601String(),
          if (profileId != null) 'profile_id': profileId,
        };
        // Unicité par profil (migration `history_unique_per_profile`) : sans
        // cible de conflit explicite, chaque sauvegarde ajouterait une ligne.
        if (profileId != null) {
          await client
              .from(SupabaseConstants.historyTable)
              .upsert(payload, onConflict: 'user_id,profile_id,content_type,content_id');
        } else {
          await client.from(SupabaseConstants.historyTable).upsert(payload);
        }
      } catch (_) {}
    }
  }

  @override
  Future<bool> toggleFavorite({required String contentId, required String contentType}) async {
    final profileId = _profileScope.activeProfileId;
    final current = await _localPreferencesService.readFavoriteIds(profileId: profileId);
    final isNowFavorite = !current.contains(contentId);
    if (isNowFavorite) {
      current.add(contentId);
    } else {
      current.remove(contentId);
    }
    await _localPreferencesService.saveFavoriteIds(current, profileId: profileId);

    if (await _canUseSupabase(contentId)) {
      try {
        final client = await _client();
        if (isNowFavorite) {
          await client.from(SupabaseConstants.favoritesTable).insert(<String, dynamic>{
            'user_id': client.auth.currentUser!.id,
            'content_type': contentType,
            'content_id': contentId,
            if (profileId != null) 'profile_id': profileId,
          });
        } else {
          var removal = client
              .from(SupabaseConstants.favoritesTable)
              .delete()
              .eq('user_id', client.auth.currentUser!.id)
              .eq('content_type', contentType)
              .eq('content_id', contentId);
          if (profileId != null) removal = removal.eq('profile_id', profileId);
          await removal;
        }
      } catch (_) {}
    }

    return isNowFavorite;
  }

  @override
  Future<void> updateDownload(DownloadItemModel item) async {
    await _upsertLocalDownload(item);

    if (await _canUseSupabase(item.contentId)) {
      try {
        final client = await _client();
        final fingerprint = await _deviceFingerprintService.getOrCreateFingerprint();
        await client.from('downloads').upsert(<String, dynamic>{
          'user_id': client.auth.currentUser!.id,
          'content_type': item.contentType,
          'content_id': item.contentId,
          'local_device_fingerprint': fingerprint,
          'status': item.status.name,
          'progress_percent': item.progressPercent * 100,
          'downloaded_bytes': item.downloadedBytes,
          'total_bytes': item.totalBytes,
          'local_file_path': item.localFilePath,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }
  }

  Future<bool> _canUseSupabase([String? contentId]) async {
    final state = await _backendService.ensureInitialized();
    if (!state.supabaseReady || _backendService.client?.auth.currentUser == null) return false;
    if (contentId == null) return true;
    return _uuidRegex.hasMatch(contentId);
  }

  Future<SupabaseClient> _client() async {
    final state = await _backendService.ensureInitialized();
    final client = _backendService.client;
    if (!state.supabaseReady || client == null || client.auth.currentUser == null) {
      throw const AppFailure('Supabase n’est pas configuré.', code: 'SUPABASE_NOT_READY');
    }
    return client;
  }

  Future<List<PlaybackProgressModel>> _fetchLocalProgress() async {
    final map = await _localPreferencesService.readPlaybackProgressMap(
      profileId: _profileScope.activeProfileId,
    );
    return map.values
        .where((value) => value is Map)
        .map((value) => UserLibraryJsonCodec.progressFromJson(Map<String, dynamic>.from(value as Map)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> _upsertLocalProgress(PlaybackProgressModel model) async {
    final profileId = _profileScope.activeProfileId;
    final map = await _localPreferencesService.readPlaybackProgressMap(profileId: profileId);
    map['${model.contentType}:${model.contentId}'] = UserLibraryJsonCodec.progressToJson(model);
    await _localPreferencesService.savePlaybackProgressMap(map, profileId: profileId);
  }

  Future<List<DownloadItemModel>> _fetchLocalDownloads() async {
    final map = await _localPreferencesService.readDownloadsMap();
    return map.values
        .where((value) => value is Map)
        .map((value) => UserLibraryJsonCodec.downloadFromJson(Map<String, dynamic>.from(value as Map)))
        .toList()
      ..sort((a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
  }

  Future<void> _saveLocalDownloads(List<DownloadItemModel> items) async {
    final map = <String, dynamic>{
      for (final item in items) '${item.contentType}:${item.contentId}': UserLibraryJsonCodec.downloadToJson(item),
    };
    await _localPreferencesService.saveDownloadsMap(map);
  }

  Future<void> _upsertLocalDownload(DownloadItemModel item) async {
    final map = await _localPreferencesService.readDownloadsMap();
    map['${item.contentType}:${item.contentId}'] = UserLibraryJsonCodec.downloadToJson(item);
    await _localPreferencesService.saveDownloadsMap(map);
  }

  ContentTileModel _fallbackTile({required String contentId, required String contentType}) {
    return ContentTileModel(
      id: contentId,
      title: 'Cineva',
      subtitle: contentType == 'movie' ? 'Film' : 'Série',
      badge: 'Cineva',
      contentType: contentType,
    );
  }

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
}
