/// Widgets Cineva : applications, écrans et utilitaires partagés.
///
/// * `src/app/` : applications (abonné, admin), routes, transitions, providers ;
/// * `src/user/` : écrans de l'application abonné (accueil, recherche,
///   bibliothèque, téléchargements, fiche contenu, profil, appareils) ;
/// * `src/settings/` : écrans de réglages et scaffolding commun ;
/// * `src/player/` : lecteur vidéo (paysage immersif) et contrat de lecture
///   [CinevaVideoController], injectable par cible ;
/// * `src/audio/`, `src/vision/`, `src/library/`, `src/search/`,
///   `src/session/` : contrôleurs et couches techniques ;
/// * `src/admin/` : console d'administration.
library;

// ------------------------------------------------------------- applications
export 'src/app/admin_app.dart';
export 'src/app/cineva_page_transitions.dart';
export 'src/app/user_app.dart';

// ------------------------------------------------------------------ écrans
export 'src/settings/audio_video_screen.dart';
export 'src/settings/help_screen.dart';
export 'src/settings/settings_scaffold.dart';
export 'src/user/content_detail_screen.dart';
export 'src/user/devices_screen.dart';
export 'src/user/downloads_screen.dart';
export 'src/user/home_screen.dart';
export 'src/user/home_skeleton.dart';
export 'src/user/library_screen.dart';
export 'src/user/profile_form_sheet.dart';
export 'src/user/profile_gate_screen.dart';
export 'src/user/profile_screen.dart';
export 'src/user/profiles_screen.dart';
export 'src/user/search_screen.dart';
export 'src/user/subscription_screen.dart';

// ---------------------------------------------------------------- lecteur
// Contrat de lecture vidéo : public afin qu'une cible desktop puisse injecter
// son propre moteur (paquet `cineva_desktop_video`) sans que `cineva_widgets`
// ne dépende de media_kit — les APK mobiles n'embarquent aucune lib desktop.
export 'src/player/cineva_video_controller.dart';

// --------------------------------------------------------------- héritage
export 'src/cineva_empty_state_card.dart';
export 'src/cineva_poster_card.dart';
export 'src/cineva_stat_tile.dart';
