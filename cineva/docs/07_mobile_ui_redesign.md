# 07 — Refonte de l'interface mobile Cineva (Design System + écrans)

Document d'analyse et de pilotage de la refonte mobile portrait.
Cible : **Flutter 3.24.5 / Dart 3.5.4**, monorepo Melos `cineva/`.

---

## A. Architecture actuelle

```
cineva/
├── apps/
│   ├── cineva_mobile/     → CinevaUserApp(target: AppTarget.mobile)
│   ├── cineva_web/        → CinevaUserApp(target: AppTarget.web)
│   ├── cineva_android_tv/ → CinevaUserApp(target: AppTarget.androidTv)
│   ├── cineva_macos|windows → CinevaUserApp(desktop)
│   └── cineva_admin/      → CinevaAdminApp
└── packages/
    ├── shared/       AppTarget, AppSurface, SessionRouteResolver, AppFormatters
    ├── models/       ContentTileModel, ContentDetailModel, HomeSectionModel,
    │                 SeasonModel/EpisodeModel, DownloadItemModel,
    │                 PlaybackProgressModel, SearchResultModel, AppSettingsModel…
    ├── repositories/ CatalogRepository (Supabase + repli demo_catalog.json),
    │                 UserLibraryRepository, AppSettingsRepository, AuthRepository…
    ├── services/     MediaDownloadService, NetworkStatusService,
    │                 DeviceFingerprintService, PushNotificationService…
    ├── audio_engine/ DSP C99 + miroirs Dart/JS (profils, DRC, loudness, A/B)
    ├── theme/        CinevaColors, CinevaRadii, CinevaSpacing, CinevaTheme
    ├── ui/           8 composants génériques (glass card, bouton, skeleton…)
    ├── animations/   CinevaFadeSlide (unique primitive)
    └── widgets/      ÉCRANS + CONTROLLERS (Riverpod StateNotifier) + router
```

**État** : Riverpod (`StateNotifierProvider`) + `go_router` 14 (`StatefulShellRoute.indexedStack`).
Les controllers métier (`LibraryController`, `SearchController`, `SettingsController`,
`SessionController`, `AudioEngineController`, `VisionController`) sont **sains et testés** :
la refonte ne les touche pas, elle se branche dessus.

## B. Écrans actuels (surface utilisateur)

| Route | Écran | Fichier |
|---|---|---|
| `/splash` | SplashScreen | `app/splash_screen.dart` |
| `/login` | LoginScreen | `auth/login_screen.dart` |
| `/device-limit` | DeviceLimitScreen | `user/device_limit_screen.dart` |
| `/subscription-expired` | SubscriptionExpiredScreen | `user/subscription_expired_screen.dart` |
| `/home` | HomeScreen (+ hero PageView, rails) | `user/home_screen*.dart` |
| `/search` | SearchScreen | `user/search_screen.dart` |
| `/downloads` | DownloadsScreen | `user/downloads_screen.dart` |
| `/account` | AccountScreen | `user/account_screen.dart` |
| `/content/:id` | ContentDetailScreen (film **et** série) | `user/content_detail_screen.dart` |
| `/player/:id` | PlayerScreen | `player/player_screen.dart` |
| `/settings*` | Hub, langue, thème, vidéo, notifs, confidentialité, Vision, Audio, Audio avancé | `settings/*`, `audio/*`, `vision/*` |

## C. Système de navigation actuel

- `StatefulShellRoute.indexedStack` 4 branches : `/home`, `/search`, `/downloads`, `/account`.
- `AdaptiveUserShell` : `NavigationBar` Material sur mobile, `Row` + rail sur desktop/TV.
- Toutes les routes poussées utilisent `_fadePage` (fade + scale 0.985 → 1, `easeOutCubic`).
- `redirect` piloté par `SessionRouteResolver` (booting/guest/authenticated/deviceLimit/expired).
- **Aucun `SystemChrome`** : l'app n'est pas verrouillée en portrait et le lecteur ne
  propose pas de passage paysage.

## D. Système de player actuel

`video_player` 2.9 + `CinevaVisionLayer` (profil de rendu) + `AudioEngineController`.
Fonctionnalités **à préserver intégralement** :

- reprise de position (`PlaybackProgressModel`) + sauvegarde périodique (5 s) + `dispose` ;
- reprise « intelligente » hors segment à passer (`PlayerRuntimePolicy.resolveSeekTarget`) ;
- skip intro / générique / segments génériques ;
- épisode suivant (compte à rebours 10 s, dismissal, `nextContentId`) ;
- changement de qualité avec re-création du controller à position constante ;
- lecture hors ligne (`DownloadItemModel.canPlayOffline` → `contentUri`) avec repli réseau ;
- pistes audio / sous-titres / qualité en bottom sheets ;
- gestes : double-tap seek ±10 s, drag vertical volume/luminosité, drag horizontal seek ;
- verrouillage des commandes, mode immersif, bannière réseau instable ;
- Cineva Audio Engine : attach, pill d'état, comparaison A/B, accès réglages ;
- raccourcis clavier / D-pad (TV) via `Shortcuts` + `Actions` ;
- cycle de vie applicatif (`didChangeAppLifecycleState`).

## E. Composants réutilisables existants

`cineva_ui` : `CinevaGlassCard`, `CinevaLoadingView`, `CinevaPageHeader`, `CinevaPrimaryButton`,
`CinevaScaffoldContainer`, `CinevaSectionTitle`, `CinevaSkeleton`, `CinevaStatusBanner`,
`CinevaTextField`. `cineva_animations` : `CinevaFadeSlide`.
`cineva_widgets` : `CinevaArtwork` (+ `CinevaArtworkPalette`), `CinevaPosterCard`,
`CinevaEmptyStateCard`, `CinevaStatTile`, `PlayerControls`, `ControlButton`, `ActionPill`,
`GestureToast`, `NextEpisodeCard`.

## F. Problèmes visuels constatés

1. **Identité** : accent violet `#7C4DFF` générique, surfaces bleutées (`#101014`, `#16161B`),
   aucune touche champagne/or → ressemble à un « thème sombre Flutter », pas à un produit.
2. **Bordures partout** : `CinevaGlassCard` met un `Border.all` + un dégradé blanc sur chaque
   carte → bruit visuel, hiérarchie illisible.
3. **Accents violets sur les visuels** : posters de repli en dégradé violet/orange saturé,
   tuiles recherche/téléchargements en `LinearGradient(accent, accentSoft)` → criard.
4. **Hero desktopisé** : `PageView` avec `viewportFraction: 0.96`, boutons 220 px fixes,
   poster 2/3 à droite dès 850 px, hauteur 380 px, texte `displaySmall` : aucune logique
   mobile portrait, pas de rotation automatique cinématographique, pas de parallaxe.
5. **Rails** : `SizedBox(height: 274)` fixes, cartes 156 px, pas de peek cohérent,
   `BouncingScrollPhysics` sans `cacheExtent`, pas d'interaction tactile (scale/halo).
6. **Boutons** : `FilledButton.icon` Material par défaut, aucune micro-interaction de presse,
   aucun bouton « Regarder » distinctif ; 3 boutons identiques 220 px sur la fiche film.
7. **Navigation** : `NavigationBar` Material standard (indicateur pill violet), pas de
   translucidité, pas d'animation d'icône/label, libellé « Compte » au lieu de « Bibliothèque ».
8. **Header** : `CinevaPageHeader` = un gros titre + un paragraphe explicatif de développeur
   (« Catalogue premium, recommandations dynamiques et reprise instantanée. ») visible par
   l'utilisateur final. Pas de wordmark CINEVA, pas de header réactif au scroll.
9. **Fiche film** : `SliverAppBar(expandedHeight: 420)` + colonne poster/texte pensée desktop,
   pas de note mise en avant, pas d'actions circulaires, pas de bande-annonce.
10. **Fiche série** : épisodes en `CinevaGlassCard` avec un carré dégradé violet en guise de
    vignette, pas de saison选中 horizontale, pas de « Continuer S1 · Ép. 3 ».
11. **Recherche** : `CinevaTextField` Material avec `labelText` flottant, `ChoiceChip` /
    `ActionChip` / `InputChip` Material par défaut (gros, colorés), résultats en tuiles
    64×64 violettes, aucune animation staggered.
12. **Téléchargements** : pas de séparation Téléchargés / En cours, vignettes violettes,
    `LinearProgressIndicator` Material (violet, 4 px), aucune animation de confirmation.
13. **Profil** : pas d'avatar réel, tuiles statistiques 220 px fixes (débordent en portrait),
    lignes d'action en cartes bordées, pas de structure « Mon compte / Appareils / Lecture… ».
14. **Audio & Vidéo** : réglages éclatés sur 2 écrans Material (`SwitchListTile.adaptive`,
    `Slider` violet par défaut), pas de page unifiée.
15. **Player** : contrôles en colonne plein écran avec `CinevaGlassCard` en bas, `Slider`
    Material violet, pas de gradient haut/bas, pas d'animation ±10 s, pas de rangée
    Audio/Sous-titres/Qualité/Vitesse, **pas de paysage**.
16. **Transitions** : un seul `_fadePage` pour tout, aucun zoom partagé, aucun lien
    visuel affiche → fiche → lecteur.
17. **Loading** : `CinevaLoadingView` = `CircularProgressIndicator` + texte ; skeleton
    d'accueil en `ListView` non scrollable avec shimmer trop marqué.
18. **Responsive** : nombreuses largeurs fixes (220, 240, 320 px), `SizedBox(width: 220)`
    dans des `Wrap` → débordements possibles sur petit écran (360 dp).
19. **Performance** : `setState` complet du `PlayerScreen` à chaque tick vidéo,
    `AnimatedContainer` sur le hero à chaque changement de page, pas de `RepaintBoundary`,
    images réseau décodées pleine taille pour des vignettes 156 px.

## G. Architecture recommandée du Design System

```
packages/theme/lib/src/
├── cineva_palette.dart      CinevaColors (échelle de surfaces #070707 → #1C1C1E,
│                            or/champagne, texte, sémantiques, scrims)
├── cineva_typography.dart   CinevaTypography (échelle mobile + tracking)
├── cineva_metrics.dart      CinevaSpacing, CinevaRadii, CinevaMetrics (responsive)
├── cineva_motion.dart       CinevaMotion (durées + courbes), CinevaCurve
├── cineva_elevation.dart    CinevaShadows, CinevaGlows
├── cineva_gradients.dart    CinevaScrims, CinevaArtworkGradients
└── cineva_theme.dart        CinevaTheme.premiumDark() / .dark() / .light()

packages/ui/lib/src/            (dépend désormais de cineva_models)
├── primitives/  cineva_pressable, cineva_buttons, cineva_chip, cineva_switch,
│                cineva_slider, cineva_search_field, cineva_progress,
│                cineva_skeleton, cineva_surface, cineva_list_tile,
│                cineva_section_header, cineva_sheet, cineva_reveal
├── chrome/      cineva_bottom_navigation, cineva_brand_header, cineva_top_bar
└── content/     cineva_artwork_image, cineva_movie_card, cineva_carousel,
                 cineva_hero, cineva_episode_tile, cineva_download_tile
```

**Règles**

- Un token, un seul endroit. Aucun écran ne contient de couleur/littéral de durée en dur.
- `cineva_ui` reste sans logique métier : il reçoit des modèles et des callbacks.
- Les controllers Riverpod existants sont l'unique source de vérité (aucune donnée simulée).
- Animations GPU-friendly : `Transform`, `Opacity`, `ClipRRect` ; pas de `BackdropFilter`
  hors navigation (une seule instance, petite surface).
- `RepaintBoundary` sur hero, rails et contrôles du player.
- Anciens composants conservés (utilisés par la console admin) : rien n'est supprimé.

## H. Fichiers modifiés / créés

### Créés

| Fichier | Rôle |
|---|---|
| `packages/theme/lib/src/cineva_palette.dart` | Échelle de surfaces + or |
| `packages/theme/lib/src/cineva_typography.dart` | Échelle typographique |
| `packages/theme/lib/src/cineva_metrics.dart` | Espacements, rayons, responsive |
| `packages/theme/lib/src/cineva_motion.dart` | Durées & courbes |
| `packages/theme/lib/src/cineva_elevation.dart` | Ombres & halos |
| `packages/theme/lib/src/cineva_gradients.dart` | Scrims & visuels de repli |
| `packages/ui/lib/src/primitives/*.dart` (13) | Primitives du design system |
| `packages/ui/lib/src/chrome/*.dart` (3) | Nav basse, header CINEVA, top bar |
| `packages/ui/lib/src/content/*.dart` (6) | Artwork, cartes, carrousel, hero |
| `packages/widgets/lib/src/user/library_screen.dart` | Bibliothèque / Ma liste |
| `packages/widgets/lib/src/user/profile_screen.dart` | Mon profil |
| `packages/widgets/lib/src/user/devices_screen.dart` | Appareils connectés |
| `packages/widgets/lib/src/user/my_list_controller.dart` | Résolution favoris → tuiles |
| `packages/widgets/lib/src/settings/audio_video_screen.dart` | Audio & Vidéo unifié |
| `packages/widgets/lib/src/settings/help_screen.dart` | Aide & support |
| `packages/ui/test/*`, `packages/widgets/test/*` | Tests des nouveaux helpers |

### Modifiés

`packages/theme/lib/cineva_theme.dart`, `packages/theme/lib/src/cineva_theme.dart`,
`packages/ui/pubspec.yaml`, `packages/ui/lib/cineva_ui.dart`,
`packages/ui/lib/src/cineva_skeleton.dart`, `packages/ui/lib/src/cineva_scaffold_container.dart`,
`packages/animations/lib/src/cineva_fade_slide.dart`,
`packages/widgets/lib/src/app/user_app.dart` (routes + transitions + portrait),
`packages/widgets/lib/src/user/adaptive_user_shell.dart`,
`packages/widgets/lib/src/user/home_screen.dart`, `home_screen_sections.dart`, `home_skeleton.dart`,
`packages/widgets/lib/src/user/search_screen.dart`,
`packages/widgets/lib/src/user/content_detail_screen.dart`, `content_detail_components.dart`,
`packages/widgets/lib/src/user/downloads_screen.dart`,
`packages/widgets/lib/src/player/player_screen.dart`, `player_overlays.dart`,
`player_screen_actions.dart`, `player_screen_gestures.dart`,
`packages/widgets/lib/src/settings/*`, `packages/widgets/lib/src/audio/audio_settings_screen.dart`,
`packages/widgets/lib/src/auth/login_screen.dart`, `packages/widgets/lib/src/app/splash_screen.dart`,
`packages/widgets/lib/src/user/device_limit_screen.dart`, `subscription_expired_screen.dart`,
`packages/widgets/lib/src/user/cineva_artwork.dart` (palette déléguée au design system),
`packages/widgets/lib/cineva_widgets.dart`.

**Supprimés** : `packages/widgets/lib/src/user/account_screen.dart`
(fonctionnalités redistribuées vers `profile_screen.dart` + `devices_screen.dart`).

### Non touchés (logique métier préservée)

`packages/models`, `packages/repositories`, `packages/services`, `packages/audio_engine`,
`packages/shared`, tous les `*_controller.dart`, `player_runtime_policy.dart`,
`player_formatters.dart`, `content_detail_helpers.dart`, `home_section_resolver.dart`,
`packages/widgets/lib/src/admin/**`, `apps/cineva_admin`.

---

## Contraintes d'implémentation retenues

- **Pas de nouvelle dépendance pub** : le design system est 100 % Flutter SDK
  (pas de `google_fonts`, pas de `cached_network_image`, pas de `shimmer`, pas de
  `speech_to_text`). Le cache image utilise le `ImageCache` natif + `cacheWidth`.
- **Bouton microphone absent** : aucune dépendance de reconnaissance vocale n'existe dans
  le projet. Plutôt que simuler, le bouton n'est pas affiché (spéc. « si disponible »).
- **Polices** : pile système (SF Pro / Roboto) travaillée en graisses, hauteurs de ligne et
  tracking — c'est ce que font les apps premium natives, et cela évite un téléchargement.
- **Thème clair** : `CinevaTheme.light()` reste fonctionnel (utilisé par le réglage Thème)
  mais n'est pas redessiné, conformément à la demande.

---

## I. Suivi d'implémentation

### Routes de l'application abonné (`src/app/user_app.dart`)

| Route | Écran | Transition |
| --- | --- | --- |
| `/splash`, `/login`, `/device-limit`, `/subscription-expired` | splash, connexion, limite d'appareils, abonnement expiré | `modal` |
| `/home` (branche 0) | `HomeScreen` | — |
| `/search` (branche 1) | `SearchScreen` | — |
| `/downloads` (branche 2) | `DownloadsScreen` | — |
| `/library` (branche 3) | `LibraryScreen` (`?tab=resume`) | — |
| `/content/:id` | `ContentDetailScreen` (film **et** série) | `push` |
| `/player/:id` (`?trailer=true`) | `PlayerScreen` (paysage immersif) | `player` |
| `/profile` | `ProfileScreen` | `push` |
| `/account` | → redirection `/profile` (compatibilité) | — |
| `/account/devices` | `DevicesScreen` | `push` |
| `/settings` | `SettingsHubScreen` | `push` |
| `/settings/audio-video` | `AudioVideoScreen` | `push` |
| `/settings/audio` | → redirection `/settings/audio-video` | — |
| `/settings/video` | → redirection `/settings/audio-video` | — |
| `/settings/help` | `HelpScreen` | `push` |
| `/settings/{language,theme,notifications,privacy,cineva-vision,audio/advanced}` | écrans existants | `push` |

### Matrice « aucune fonctionnalité perdue »

| Fonctionnalité d'origine | Où elle vit maintenant |
| --- | --- |
| Accueil (sections, hero, continuer, rails) | `HomeScreen` + `home_screen_sections.dart` (mêmes providers) |
| Recherche (debounce, filtres, historique, suggestions) | `SearchScreen` (`SearchController` inchangé) |
| Fiche film / série (saisons, épisodes, similaires) | `ContentDetailScreen` + `content_detail_components.dart` |
| Ma liste (favoris) | `LibraryScreen` onglet « Ma liste » |
| Continuer à regarder | `LibraryScreen` onglet « Reprendre » + rail d'accueil + fiches |
| Téléchargements (file, pause, reprise, suppression, relance) | `DownloadsScreen` (groupes par statut, mode édition, suppression globale) |
| Compte (session, refresh, déconnexion) | `ProfileScreen` |
| Appareils (liste, suppression, limite) | `DevicesScreen` + `DeviceLimitScreen` |
| Préférences vidéo (qualité, sous-titres, autoplay) | `AudioVideoScreen` |
| Cineva Audio (moteur, profils, dialogues, basses, spatialisation, loudness, A/B, dynamique, sortie) | `AudioVideoScreen` (+ `AdvancedAudioScreen` pour l'EQ) |
| Cineva Vision | lien depuis Profil / Audio & Vidéo / hub (écran conservé) |
| Lecteur (qualité, audio, sous-titres, gestes, skip intro/générique/segment, épisode suivant, verrou, immersif, Vision, Audio Engine, raccourcis TV) | `PlayerScreen` inchangé sur le fond, contrôles redessinés + mode bande-annonce |
| Notifications / confidentialité / langue / thème | écrans conservés, réécrits avec le scaffolding Cineva |

**Fichiers supprimés** : `user/account_screen.dart`, `settings/video_preferences_screen.dart`,
`audio/audio_settings_screen.dart` — chaque fonction a été reprise ailleurs (voir matrice),
les routes historiques redirigent.

### Écrans réglages secondaires (terminés)

- `audio/advanced_audio_screen.dart` : réécrit sur `SettingsScreenScaffold` +
  `CinevaSwitchTile` / `CinevaSliderTile` (valeurs dB et Hz affichées via `valueLabel`),
  bannière si le backend n'est pas disponible, bouton « Réinitialiser ».
  `AudioEngineController` inchangé.
- `vision/cineva_vision_settings_screen.dart` : réécrit sur `SettingsScreenScaffold` —
  carte de recommandation (mode recommandé + bascule auto + appliquer), aperçu avant/après
  avec séparateur draggable alimenté par `CinevaVisionService.buildRenderProfile`, profils
  en options pleine largeur, 7 options avancées **désactivées quand l'appareil ne les
  supporte pas** (`capabilities.*Supported`), chips des réglages appliqués et synthèse de
  l'analyse matérielle. `VisionController` inchangé.

### Vérifications effectuées sans SDK

Le sandbox de travail ne contient ni Flutter ni Dart et n'a pas d'accès réseau :
`melos run analyze`, `melos run test` et le build APK n'ont pas pu être exécutés.
Des contrôles statiques ont été menés à la place sur les 71 fichiers modifiés ou créés :

1. **Structure** : équilibre accolades/parenthèses en ignorant chaînes, échappements,
   interpolations `${}` et commentaires — 0 anomalie sur les 270 fichiers Dart du monorepo.
2. **Imports** : chaque symbole `package:` utilisé est exporté par un package déclaré dans
   le `pubspec` du paquet ; aucun import manquant, aucun `part` / `part of` orphelin.
3. **API** : tous les constructeurs Cineva sont appelés avec des paramètres nommés
   existants ; tous les membres statiques référencés existent ; tous les getters de modèles
   utilisés existent. Corrections apportées en cours de route : `ContentTileModel` n'expose
   pas `isMovie` / `isSeries` (remplacé par `contentType ==`), `resolveDownloadUrl` accepte
   une qualité optionnelle, `resolvePlaybackUrl` exige une qualité.
4. **API sous test** : les classes couvertes par les tests existants (`HomeSectionResolver`,
   `HomeScreenLayout`, `ContentDetailHelpers`, `ContentDetailLayout`, `CinevaArtworkPalette`,
   `PlayerFormatters`, `PlayerRuntimePolicy`, `DownloadProgressMetrics`) sont intactes.

**Reste à faire dans un environnement outillé** : `melos bootstrap` → `melos run analyze` →
`melos run test` → build APK debug, puis validation sur appareil (encoche / Dynamic Island,
densités d'écran, thèmes Clair & Noir, TalkBack, lecteur en paysage).
