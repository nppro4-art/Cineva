# Cineva

Application de streaming premium (**Flutter + Supabase**) organisée en **monorepo**.

> Le projet vit dans le dossier **[`cineva/`](cineva)**. C'est la source de vérité unique.

## Structure

```text
cineva/
├── apps/          # applications (mobile, admin, web, windows, macos, android_tv)
├── packages/      # code partagé (models, repositories, services, widgets, ui, …)
├── supabase/      # schéma SQL, seed et Edge Functions
├── docs/          # architecture, plan d'exécution et audits
├── scripts/       # build par plateforme + bootstrap Flutter
└── melos.yaml     # orchestration du monorepo
```

## Démarrage

1. Installer le SDK Flutter (les dossiers `flutter/` / `android-sdk/` à la racine
   de ce dépôt sont des artefacts d'environnement incomplets et ne doivent pas
   être utilisés tels quels).
2. Depuis `cineva/` :
   ```bash
   flutter pub get
   # ou, via melos :
   melos bootstrap
   melos run pub:get
   ```
3. Générer les cibles natives si besoin :
   ```bash
   bash scripts/bootstrap_flutter_targets.sh
   ```
4. Lancer une application, par exemple :
   ```bash
   cd cineva/apps/cineva_mobile && flutter run
   ```

## Notes

- Les anciennes applications à la racine (`cineva_app/`, `cineva_admin/`) étaient des
  ébauches redondantes/ cassées dupliquant le monorepo et ont été **supprimées**.
  Toute la logique se trouve désormais dans `cineva/`.
- Voir [`cineva/README.md`](cineva/README.md) et [`cineva/docs/`](cineva/docs) pour
  l'architecture détaillée et le plan d'exécution.
