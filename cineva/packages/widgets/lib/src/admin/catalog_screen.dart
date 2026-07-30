import 'dart:typed_data';

import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cineva_services/cineva_services.dart';

import '../app/providers.dart';
import 'import_url_screen.dart';

part 'catalog_screen_tabs.dart';
part 'catalog_screen_editors.dart';
part 'catalog_movie_series_editor.dart';
part 'catalog_category_editor.dart';
part 'catalog_home_editor.dart';
part 'catalog_media_picker.dart';
part 'catalog_screen_series_manager.dart';
part 'catalog_season_editor.dart';
part 'catalog_episode_editor.dart';
part 'catalog_screen_helpers.dart';

class AdminCatalogScreen extends StatelessWidget {
  const AdminCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 5,
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(CinevaSpacing.lg, CinevaSpacing.lg, CinevaSpacing.lg, 0),
            child: _CatalogHeader(),
          ),
          TabBar(
            isScrollable: true,
            tabs: <Tab>[
              Tab(text: 'Films'),
              Tab(text: 'Séries'),
              Tab(text: 'Catégories'),
              Tab(text: 'Accueil'),
              Tab(text: 'Importer'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _MoviesTab(),
                _SeriesTab(),
                _CategoriesTab(),
                _HomeEditorTab(),
                const ImportUrlScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
