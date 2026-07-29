# Cineva — Audit RC1 Module Téléchargements

## Module audité
Téléchargements

## Résultat

### État du code
**❌ Corrections nécessaires**

### Validation réelle
**❌ Validation réelle encore requise**

---

## 1. Audit

### Points forts
- Une vraie base de téléchargement local existe désormais ; ce n'est plus une simple simulation visuelle.
- Le système gère déjà :
  - file d'attente,
  - téléchargements simultanés,
  - pause,
  - reprise,
  - suppression,
  - progression,
  - vitesse,
  - temps restant.
- L'état des téléchargements est persistant localement.
- Le module est relié au compte utilisateur et à Supabase quand la session est disponible.
- La lecture hors connexion est prévue via priorité au fichier local.

### Points faibles
- Le téléchargement en arrière-plan dépend encore du cycle de vie de l'application, pas d'un gestionnaire natif complet.
- L'espace disque n'est pas encore réellement mesuré au niveau système.
- Le nettoyage automatique des contenus expirés n'est pas complètement finalisé métier/licence.
- La protection locale des contenus téléchargés n'est pas encore au niveau d'un produit commercial sécurisé.
- La logique offline, la persistence locale et la sync Supabase restent encore très concentrées dans quelques fichiers.

### Incohérences / points sensibles
- Le système distingue maintenant mieux les flux téléchargeables des manifests HLS/DASH, mais cette logique doit être validée sur un vrai catalogue.
- Les téléchargements peuvent être cohérents côté app tout en restant limités par le comportement réel du système d'exploitation.
- Le module ne prouve pas encore une vraie reprise “OS-level” si l'application est totalement tuée.

### Dette technique
- `packages/services/lib/src/downloads/media_download_service.dart`
- `packages/widgets/lib/src/library/library_controller.dart`
- `packages/repositories/lib/src/supabase_user_library_repository.dart`
- dépendance actuelle de la lecture offline à des conventions simples de fichier local

### Risques
- interruption OS non maîtrisée ;
- espace disque insuffisant non détecté à temps ;
- divergence entre état local et état backend ;
- fichiers locaux manquants / corrompus ;
- comportement différent selon Android / iOS / desktop / TV.

---

## 2. Refactoring réalisé

### Réalisé dans ce lot
- Création de `download_runtime_policy.dart`.
- Centralisation de règles métier simples :
  - détection d'un fichier local manquant ;
  - politique de reprise au redémarrage ;
  - sélection de qualité téléchargeable ;
  - interprétation des annulations.
- Découplage de l'écran téléchargements des utilitaires du player via `AppFormatters` partagé.
- Réduction d'une duplication d'extension dans `library_controller.dart` grâce à `cineva_shared`.

### Effet
- meilleure lisibilité ;
- meilleure testabilité ;
- logique métier plus explicite ;
- réduction de couplages inutiles.

### Ce qui reste à refactoriser
- séparation plus nette entre orchestration UI, sync backend et moteur de téléchargement ;
- meilleure isolation du stockage local ;
- stratégie de gestion des erreurs plus homogène.

---

## 3. Validation logique

### Ce qui peut être considéré comme valide dans le code
- création d'un téléchargement ;
- mise en file ;
- limitation du nombre de téléchargements simultanés ;
- pause ;
- reprise ;
- suppression ;
- persistence locale des métadonnées ;
- réhydratation des téléchargements au lancement ;
- détection des fichiers offline manquants ;
- tentative de lecture hors connexion via fichier local ;
- synchronisation d'état avec Supabase lorsque disponible.

### Ce qui n'est pas encore réellement prouvé dans le code seul
- véritable background download natif OS ;
- gestion fiable d'un espace disque insuffisant ;
- nettoyage automatique complet selon expiration/licence ;
- protection locale forte / chiffrement réel ;
- robustesse totale si l'application est tuée par le système.

### Ce qui nécessite impérativement une validation réelle
- Android : téléchargement long, pause/reprise, relance app, lecture offline ;
- iOS : cycle de vie, relance, comportement background réel ;
- desktop : lecture locale stable, suppression locale ;
- Android TV : ergonomie et file de téléchargements sur télécommande.

---

## 4. Tests

### Tests ajoutés / renforcés
- `packages/services/test/download_runtime_policy_test.dart`
- réutilisation des tests playback/download déjà présents

### Ce que ces tests couvrent
- normalisation d'un fichier offline manquant ;
- politique de reprise au lancement ;
- cohérence des décisions métier simples.

### Ce qui manque encore côté tests
- tests d'intégration sur reprise téléchargement ;
- tests widget de l'écran Téléchargements ;
- tests de sync local / backend ;
- tests d'erreur réseau ;
- tests de suppression réelle.

### Checklist dédiée
- `docs/RC1_DOWNLOADS_CHECKLIST.md`

---

## 5. Distinction importante demandée

### Téléchargements réellement fonctionnels dans le code
- file d'attente applicative ;
- reprise applicative ;
- progression ;
- vitesse ;
- estimation ;
- lecture locale si fichier présent ;
- suppression locale ;
- persistance des états.

### Comportements encore simulés ou partiellement dépendants de l'OS
- background download si l'app est totalement fermée ;
- protection locale forte ;
- politique complète de nettoyage automatique ;
- vérification d'espace disque disponible ;
- garanties offline “store-grade” sur toutes les plateformes.

### Dépendance aux capacités système
- Android et iOS peuvent nécessiter des mécanismes natifs dédiés pour un vrai background fiable ;
- desktop est généralement plus simple ;
- Android TV doit être validé pour l'ergonomie plus que pour la technique pure.

---

## 6. Évaluation UX du module Téléchargements

- **Simplicité d'utilisation** : **8/10**
- **Clarté des informations** : **8/10**
- **Gestion des erreurs** : **7/10**
- **Fiabilité perçue** : **7/10**
- **Fluidité** : **8/10**
- **Gestion des téléchargements multiples** : **7/10**

### Commentaire
L'UX est déjà crédible pour un produit premium Flutter. Ce qui manque n'est pas tant l'interface que la validation réelle du moteur sur les différentes plateformes.

---

## 7. Décision finale

### État du code
**❌ Corrections nécessaires**

#### Points bloquants côté code
1. `media_download_service.dart` reste trop central ;
2. gestion disque encore incomplète ;
3. protection locale non finalisée ;
4. stratégie de background non encore durcie ;
5. couverture de tests encore insuffisante.

### Validation réelle
**❌ Validation réelle encore requise**

#### Points bloquants côté validation
1. Android réel ;
2. iOS réel ;
3. reprise après redémarrage réel ;
4. lecture hors connexion réelle ;
5. comportement si l'OS tue l'application ;
6. comportement sur faible espace disque.

---

## Conclusion
Le module Téléchargements est bien plus avancé qu'un simple prototype, mais il ne peut pas encore être certifié RC1.

Il est proche d'un niveau produit côté UX et logique applicative, mais sa maturité réelle dépend encore fortement de validations sur appareils et des limites des systèmes d'exploitation.
