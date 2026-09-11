# Cineva

Plateforme de streaming premium multiplateforme — monorepo Flutter + Supabase.

## Structure du dépôt

```text
Cineva/
├── cineva/                 # monorepo actif (Melos)
│   ├── apps/               # 6 applications
│   │   ├── cineva_mobile/  # abonné Android / iOS
│   │   ├── cineva_admin/   # console d'administration
│   │   ├── cineva_web/
│   │   ├── cineva_android_tv/
│   │   ├── cineva_macos/
│   │   └── cineva_windows/
│   ├── packages/           # 9 packages partagés
│   │   ├── audio_engine/   # Cineva Audio (DSP C99 + miroirs Dart/JS)
│   │   ├── shared, models, repositories, services…
│   │   └── ui, widgets, theme, animations
│   ├── supabase/           # schéma SQL + README backend
│   └── scripts/            # builds multiplateformes + icônes Android
├── cineva_admin/           # app historique (legacy)
├── cineva_app/             # app historique (legacy)
└── .github/workflows/      # build-android → APK release + GitHub Release
```

## Cineva Audio

Moteur DSP **C99** avec miroirs Dart/JS **bit-exacts** :

- profils **Cinéma**, **Nuit**, **Immersif**
- bypass A/B pour comparaison instantanée
- cœur C : **1684 tests** unitaires

## État qualité

| Contrôle | Résultat |
|---|---|
| `flutter analyze` (15 packages) | 0 issue |
| Tests monorepo | **103 / 103** |
| Build web release | OK |
| Cœur C (audio_engine) | **1684 tests** |

## Démarrage rapide

Prérequis : **Flutter 3.24.5** (Dart 3.5.4).

```bash
cd cineva/apps/cineva_web
flutter pub get
flutter build web --release
```

### Applications Android (APK release, backend Supabase réel)

1. Configurer les secrets GitHub Actions `SUPABASE_URL` et `SUPABASE_ANON_KEY`
2. Lancer le workflow :

```bash
gh workflow run build-android.yml --ref main
gh run watch
gh release list   # → apk-<n> avec Cineva-User.apk et Cineva-Admin.apk
```

Le mode démo est **refusé** : sans secrets Supabase, le workflow échoue volontairement.

### Backend Supabase

Voir [`cineva/supabase/README.md`](cineva/supabase/README.md) : exécuter `schema.sql`, créer les buckets Storage, puis promouvoir le premier admin :

```sql
update public.profiles set role = 'admin' where email = 'vous@exemple.com';
```

## Licence

Projet privé — tous droits réservés.
