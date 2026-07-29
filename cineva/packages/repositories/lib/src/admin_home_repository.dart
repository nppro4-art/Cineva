import 'package:cineva_models/cineva_models.dart';

import 'admin_supabase_gateway.dart';

class SupabaseAdminHomeRepository {
  SupabaseAdminHomeRepository(this._gateway);

  final AdminSupabaseGateway _gateway;

  Future<void> deleteHomeSection(String id) async {
    final client = await _gateway.client();
    await client.from('home_sections').delete().eq('id', id);
  }

  Future<List<AdminHomeSectionModel>> fetchHomeSections() async {
    final client = await _gateway.client();
    final sectionsRows = await client.from('home_sections').select().order('sort_order');
    if (sectionsRows.isEmpty) return const <AdminHomeSectionModel>[];

    final sectionIds = sectionsRows.map<String>((row) => row['id'] as String).toList();
    final itemsRows = await client.from('home_section_items').select().inFilter('home_section_id', sectionIds).order('sort_order');

    final movieIds = itemsRows.where((row) => row['content_type'] == 'movie').map<String>((row) => row['content_id'] as String).toSet().toList();
    final seriesIds = itemsRows.where((row) => row['content_type'] == 'series').map<String>((row) => row['content_id'] as String).toSet().toList();
    final titles = <String, String>{};

    if (movieIds.isNotEmpty) {
      final movieRows = await client.from('movies').select('id, title').inFilter('id', movieIds);
      for (final dynamic row in movieRows) {
        final map = Map<String, dynamic>.from(row as Map);
        titles['movie:${map['id']}'] = map['title'] as String? ?? 'Film';
      }
    }
    if (seriesIds.isNotEmpty) {
      final seriesRows = await client.from('series').select('id, title').inFilter('id', seriesIds);
      for (final dynamic row in seriesRows) {
        final map = Map<String, dynamic>.from(row as Map);
        titles['series:${map['id']}'] = map['title'] as String? ?? 'Série';
      }
    }

    return sectionsRows.map<AdminHomeSectionModel>((dynamic row) {
      final map = Map<String, dynamic>.from(row as Map);
      final items = itemsRows.where((item) => item['home_section_id'] == map['id']).map<AdminHomeSectionItemModel>((dynamic item) {
        final itemMap = Map<String, dynamic>.from(item as Map);
        return AdminHomeSectionItemModel(
          id: itemMap['id'] as String,
          homeSectionId: itemMap['home_section_id'] as String,
          contentType: itemMap['content_type'] as String,
          contentId: itemMap['content_id'] as String,
          sortOrder: itemMap['sort_order'] as int? ?? 0,
          title: titles['${itemMap['content_type']}:${itemMap['content_id']}'] ?? itemMap['content_id'] as String,
        );
      }).toList();
      return AdminHomeSectionModel(
        id: map['id'] as String,
        sectionKey: map['section_key'] as String? ?? '',
        title: map['title'] as String? ?? '',
        layoutType: map['layout_type'] as String? ?? 'rail',
        sortOrder: map['sort_order'] as int? ?? 0,
        isEnabled: map['is_enabled'] as bool? ?? true,
        items: items,
      );
    }).toList();
  }

  Future<void> replaceHomeSectionItems({required String homeSectionId, required List<AdminHomeSectionItemModel> items}) async {
    final client = await _gateway.client();
    await client.from('home_section_items').delete().eq('home_section_id', homeSectionId);
    if (items.isEmpty) return;
    await client.from('home_section_items').insert(items.map((item) => <String, dynamic>{
          'home_section_id': homeSectionId,
          'content_type': item.contentType,
          'content_id': item.contentId,
          'sort_order': item.sortOrder,
        }).toList());
  }

  Future<AdminHomeSectionModel> saveHomeSection(AdminHomeSectionModel section) async {
    final client = await _gateway.client();
    final payload = <String, dynamic>{
      if (section.id.isNotEmpty) 'id': section.id,
      'section_key': section.sectionKey,
      'title': section.title,
      'layout_type': section.layoutType,
      'sort_order': section.sortOrder,
      'is_enabled': section.isEnabled,
    };
    final row = await client.from('home_sections').upsert(payload).select().single();
    final saved = AdminHomeSectionModel(
      id: row['id'] as String,
      sectionKey: row['section_key'] as String,
      title: row['title'] as String,
      layoutType: row['layout_type'] as String,
      sortOrder: row['sort_order'] as int? ?? 0,
      isEnabled: row['is_enabled'] as bool? ?? true,
      items: section.items,
    );
    await replaceHomeSectionItems(homeSectionId: saved.id, items: section.items);
    return saved;
  }
}
