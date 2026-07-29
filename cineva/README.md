# Cineva

Socle initial du projet **Cineva** sous forme de **monorepo Flutter + Supabase**, pensé pour une application de streaming premium, multiplateforme et maintenable sur le long terme.

> **État actuel du dossier**
>
> Ce dossier contient un **cahier technique exécutable** : architecture cible, organisation du monorepo, schéma de base de données Supabase, stratégie sécurité, plan d'implémentation, scripts de build documentés et structure de dépôt prête à être complétée.
>
> C'est la base professionnelle sur laquelle implémenter ensuite le produit complet, fonctionnalité par fonctionnalité.

---

## 1. Vision produit

Cineva vise une expérience :

- premium ;
- extrêmement fluide ;
- visuellement minimaliste ;
- pensée par type d'appareil ;
- sécurisée côté serveur ;
- robuste en production.

Inspirations de design et d'UX :

- Apple
- Linear
- Raycast
- Arc Browser
- Porsche

Palette cible :

- Noir OLED
- Blanc cassé
- Violet électrique

---

## 2. Stack validée

### Frontend
- Flutter
- Architecture modulaire par features
- Responsive + adaptive UI selon support
- Animations haute fluidité

### Backend
- Supabase
  - Auth
  - Postgres
  - Storage
  - Edge Functions
  - Realtime si nécessaire
  - Cron / tâches planifiées selon besoin

### Notifications
- Firebase Cloud Messaging

### Outils
- Visual Studio Code
- GitHub
- Scripts de build documentés
- Monorepo recommandé avec `melos`

---

## 3. Structure retenue

```text
cineva/
├── apps/
│   ├── cineva_mobile/
│   ├── cineva_admin/
│   ├── cineva_windows/
│   ├── cineva_macos/
│   ├── cineva_android_tv/
│   └── cineva_web/
├── packages/
│   ├── ui/
│   ├── animations/
│   ├── widgets/
│   ├── services/
│   ├── models/
│   ├── repositories/
│   ├── theme/
│   └── shared/
├── backend/
├── supabase/
├── docs/
└── scripts/
```

### Principe d'architecture

- **Logique partagée** dans `packages/`
- **Applications indépendantes** dans `apps/`
- **Backend métier** dans Supabase + fonctions serveur
- **Interfaces spécifiques** selon appareil
- **Aucune logique critique uniquement dans l'app**

---

## 4. Décisions d'architecture clés

### 4.1 Applications séparées

Deux grandes familles fonctionnelles :

1. **Application Utilisateur**
2. **Application Admin**

Même si elles vivent dans le même monorepo, elles doivent pouvoir :

- être compilées séparément ;
- avoir leurs propres routes et layouts ;
- partager uniquement ce qui est pertinent ;
- évoluer sans couplage excessif.

### 4.2 Sécurité serveur prioritaire

Les vérifications critiques doivent être faites côté serveur :

- validité de l'abonnement ;
- suspension du compte ;
- limite du nombre d'appareils ;
- génération d'URLs signées pour médias ;
- autorisation des téléchargements ;
- envoi de notifications administrateur.

### 4.3 Limite appareils configurable

Le projet part sur **1 appareil maximum par compte**, mais cette limite doit être configurable par variable métier côté serveur.

### 4.4 Stockage des médias

Conformément à votre choix actuel :

- **Supabase Storage** pour affiches, bannières, avatars, sous-titres et médias de départ.

> Remarque importante : pour une vraie montée en charge vidéo, un CDN et/ou un stockage média spécialisé pourra être ajouté ensuite sans casser l'architecture métier.

---

## 5. Documentation incluse

### Dossier technique
- `docs/01_architecture_generale.md`
- `docs/02_backend_supabase.md`
- `docs/03_flutter_architecture.md`
- `docs/04_plan_execution.md`

### Base de données
- `supabase/schema.sql`

### Build / release
- `scripts/README.md`
- `scripts/build_android.sh`
- `scripts/build_ios.sh`
- `scripts/build_windows.sh`
- `scripts/build_macos.sh`
- `scripts/build_android_tv.sh`
- `scripts/bootstrap_flutter_targets.sh`

### Scaffold Flutter
- `docs/05_scaffold_flutter_bootstrap.md`

---

## 6. Points techniques importants à anticiper

### DRM vidéo
Flutter peut lire de la vidéo très correctement, mais un **DRM de niveau production** (Widevine / FairPlay) demande souvent une intégration plus poussée qu'un simple lecteur générique.

**Approche recommandée :**
- V1 robuste avec contrôle d'accès serveur + URLs signées courtes ;
- V2 possible avec intégration DRM native ou lecteur compatible si le catalogue le nécessite.

### Téléchargements hors ligne
Le téléchargement offline de contenus premium doit être protégé.

**Approche recommandée :**
- chiffrage local ;
- validation périodique de licence ;
- expiration locale ;
- suppression automatique si abonnement invalide.

### iOS et notifications
FCM sur iOS nécessite la configuration APNs en complément.

### Android TV
Le focus, la navigation télécommande et les raccourcis d'actions devront être traités comme une interface à part entière.

---

## 7. Recommandations Flutter

Architecture moderne recommandée :

- `flutter_riverpod`
- `go_router`
- `freezed`
- `json_serializable`
- `supabase_flutter`
- lecteur vidéo selon choix final
- cache image + cache disque
- analytics internes côté backend

---

## 8. Mode de réalisation conseillé

Vu l'ampleur du projet, la réalisation doit se faire **par lots finalisés** :

1. socle monorepo ;
2. backend Supabase ;
3. authentification + profils ;
4. abonnements + appareils ;
5. shell utilisateur ;
6. catalogue + recherche ;
7. player + historique ;
8. téléchargements ;
9. admin ;
10. notifications ;
11. statistiques ;
12. QA et release.

Cela respecte votre exigence : **chaque fonctionnalité doit être finalisée avant de passer à la suivante**.

---

## 9. Prochaine étape recommandée

La suite logique est :

1. transformer cette architecture en **scaffold Flutter réel** ;
2. générer la base Supabase ;
3. implémenter le premier lot fonctionnel :
   - auth,
   - profils,
   - abonnement,
   - gestion appareil unique,
   - écran abonnement expiré.

---

## 10. Objectif final

Faire en sorte que Cineva donne réellement l'impression d'un produit développé par une grande entreprise :

- code propre ;
- performances élevées ;
- UX premium ;
- maintenance durable ;
- sécurité côté serveur.

---

## 11.1 État du scaffold Flutter

Le dépôt contient désormais un **scaffold Flutter réel côté Dart** pour les applications et packages principaux.

> Les dossiers natifs Flutter (`android`, `ios`, `macos`, `windows`, `web`) n'ont pas pu être générés automatiquement ici car le SDK Flutter n'est pas installé dans cet environnement.
>
> Un script dédié a été ajouté pour les générer proprement sur votre machine : `scripts/bootstrap_flutter_targets.sh`.

---

## 11. Utilisation du dossier

Vous pouvez ouvrir ce dossier directement dans :

- Visual Studio Code
- Android Studio

et vous appuyer sur la documentation fournie pour construire l'implémentation complète.

Si vous le souhaitez, je peux maintenant passer à l'étape suivante et **générer le scaffold technique réel du monorepo Flutter** dans ce dossier.