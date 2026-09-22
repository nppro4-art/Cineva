/// Design system Cineva — composants.
///
/// Trois familles :
/// * `primitives/` : éléments atomiques (boutons, chips, curseurs, surfaces…) ;
/// * `chrome/` : navigation basse, header de marque, barre supérieure ;
/// * `content/` : composants liés aux modèles (affiches, carrousels, hero…).
///
/// Les composants historiques (`CinevaGlassCard`, `CinevaPrimaryButton`, …)
/// restent exportés : ils servent à la console d'administration et aux écrans
/// non refondus.
library;

// ------------------------------------------------------------------ chrome
export 'src/chrome/cineva_bottom_navigation.dart';
export 'src/chrome/cineva_brand_header.dart';
export 'src/chrome/cineva_top_bar.dart';

// ----------------------------------------------------------------- contenu
export 'src/content/cineva_artwork_image.dart';
export 'src/content/cineva_carousel.dart';
export 'src/content/cineva_content_labels.dart';
export 'src/content/cineva_download_tile.dart';
export 'src/content/cineva_episode_tile.dart';
export 'src/content/cineva_hero.dart';
export 'src/content/cineva_movie_card.dart';

// -------------------------------------------------------------- primitives
export 'src/primitives/cineva_buttons.dart';
export 'src/primitives/cineva_chip.dart';
export 'src/primitives/cineva_list_tile.dart';
export 'src/primitives/cineva_pressable.dart';
export 'src/primitives/cineva_progress.dart';
export 'src/primitives/cineva_reveal.dart';
export 'src/primitives/cineva_search_field.dart';
export 'src/primitives/cineva_section_header.dart';
export 'src/primitives/cineva_sheet.dart';
export 'src/primitives/cineva_slider.dart';
export 'src/primitives/cineva_surface.dart';
export 'src/primitives/cineva_switch.dart';

// -------------------------------------------------------------- héritage
export 'src/cineva_glass_card.dart';
export 'src/cineva_loading_view.dart';
export 'src/cineva_page_header.dart';
export 'src/cineva_primary_button.dart';
export 'src/cineva_scaffold_container.dart';
export 'src/cineva_section_title.dart';
export 'src/primitives/cineva_skeleton.dart';
export 'src/cineva_status_banner.dart';
export 'src/cineva_text_field.dart';
