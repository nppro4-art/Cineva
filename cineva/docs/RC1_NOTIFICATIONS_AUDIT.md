# Cineva — Audit RC1 Module Notifications

## Module audité
Notifications

## Résultat

### État du code
**❌ Corrections nécessaires**

### Validation réelle
**❌ Validation réelle encore requise**

---

## 1. Audit

### Points forts
- Le module dispose d'une vraie séparation entre :
  - service client Flutter (`PushNotificationService`),
  - orchestration UI/app (`user_app.dart`, providers),
  - couche admin (`AdminNotificationsScreen`),
  - backend serveur (`send-fcm-notification`, `process-scheduled-notifications`).
- Les deep links sont déjà prévus via `contentId` et `screen`.
- Les tokens invalides commencent à être nettoyés côté Edge Functions.
- L'Admin peut déjà gérer les notifications globales, ciblées et programmées.
- L'historique des notifications est persisté dans Supabase.

### Points faibles
- Le module ne distingue pas encore explicitement des types métier de notification (nouveau contenu, rappel abonnement, téléchargement terminé, etc.).
- Il n'existe pas encore d'annulation / suppression d'une notification programmée côté Admin.
- Le service Flutter gère la route et les messages foreground, mais pas encore une vraie stratégie de présentation locale / priorisation UX.
- L'utilité des notifications n'est pas encore pilotée par un moteur de pertinence : on peut envoyer, mais pas encore personnaliser intelligemment.
- Le support desktop reste structurellement tolérant mais pas validé réellement.

### Dette technique
- `packages/services/lib/src/notifications/push_notification_service.dart`
- `packages/widgets/lib/src/admin/notifications_screen.dart`
- `packages/repositories/lib/src/supabase_admin_repository.dart`
- `supabase/functions/send-fcm-notification/index.ts`
- `supabase/functions/process-scheduled-notifications/index.ts`

### Risques
- dépendance forte à la configuration Firebase réelle ;
- différences Android / iOS sur permissions et comportement background ;
- absence de validation bout-en-bout ;
- notifications programmées dépendantes du déclenchement réel du cron ;
- notifications potentiellement utiles sur le plan technique mais pas encore assez pertinentes côté produit.

---

## 2. Refactoring réalisé

### Réalisé dans ce lot
- extraction d'un helper partagé Edge Functions :
  - `supabase/functions/_shared/fcm.ts`
- réduction de duplication entre :
  - `send-fcm-notification`
  - `process-scheduled-notifications`
- conservation du parser de route comme point unique via `PushNotificationService.routeFromData()`.

### Effet
- meilleure lisibilité ;
- moins de duplication serveur ;
- comportement plus homogène sur le nettoyage des tokens invalides.

### Ce qui reste à refactoriser
- découper `AdminNotificationsScreen` si on enrichit l'UX ;
- isoler un modèle métier de type de notification ;
- centraliser plus formellement les validations serveur.

---

## 3. Validation logique

### Ce qui peut être considéré comme valide dans le code
- création de notification globale ;
- création de notification ciblée ;
- création de notification programmée ;
- persistance de l'historique ;
- statut `scheduled / sent / failed` ;
- deep link par `contentId` ;
- fallback route via `screen` ;
- nettoyage des tokens invalides quand FCM renvoie une erreur compatible.

### Ce qui n'est pas encore prouvé uniquement par le code
- réception réelle Android ;
- réception réelle iOS ;
- comportement app ouverte / arrière-plan / fermée ;
- déclenchement réel du scheduler ;
- qualité UX perçue des notifications (intrusion, utilité, fréquence).

### Ce qui nécessite impérativement une validation réelle
- configuration Firebase ;
- APNs iOS ;
- permissions utilisateur ;
- deep links sur appareils réels ;
- cron / trigger programmé ;
- vrai nettoyage de tokens obsolètes en production.

---

## 4. Tests

### Tests présents / améliorés
- `packages/services/test/push_notification_service_test.dart`
  - route via `contentId`
  - fallback via `screen`

### Ce qu'il manque encore
- tests d'intégration Admin → Edge Function ;
- tests de parsing de payloads plus complexes ;
- tests de gestion d'erreurs côté service ;
- tests de régression navigation après clic notification ;
- tests de programmation logique.

### Checklist dédiée
- `docs/RC1_NOTIFICATIONS_CHECKLIST.md`

---

## 5. Utilité réelle des notifications

### Types déjà cohérents / utiles
1. **Rappel d'expiration d'abonnement**
   - Utilité réelle : élevée
   - Intérêt utilisateur : élevé
   - Risque d'intrusion : faible

2. **Téléchargement terminé**
   - Utilité réelle : élevée
   - Intérêt utilisateur : moyen à élevé
   - Risque d'intrusion : faible

3. **Nouveau contenu lié à un intérêt utilisateur**
   - Utilité réelle : potentiellement élevée
   - Intérêt utilisateur : élevé si ciblage réel
   - Risque d'intrusion : moyen si trop fréquent

4. **Ouverture directe d'un contenu éditorialement mis en avant**
   - Utilité réelle : moyenne
   - Intérêt utilisateur : moyen
   - Risque d'intrusion : moyen

### Types à éviter ou limiter
- notifications trop générales sans contexte ;
- répétitions de contenu non personnalisé ;
- push trop fréquents ;
- notifications purement marketing sans valeur produit.

### Recommandation produit
Pour RC1, limiter les notifications aux cas les plus utiles :
- rappel abonnement ;
- téléchargement terminé ;
- nouveau contenu pertinent ;
- éventuellement notification éditoriale exceptionnelle.

---

## 6. Évaluation UX du module Notifications

- **Pertinence** : **6/10**
- **Clarté** : **8/10**
- **Fiabilité** : **6/10**
- **Discrétion** : **7/10**
- **Intégration dans l'application** : **8/10**

### Commentaire
L'intégration est propre et structurée. Ce qui manque n'est pas tant l'UI que :
- la validation réelle ;
- un cadrage produit plus fin de la pertinence ;
- une vraie stratégie anti-bruit / anti-spam.

---

## 7. Décision finale

### État du code
**❌ Corrections nécessaires**

#### Points bloquants côté code
1. pas encore de modèle métier clair par type de notification ;
2. absence d'annulation côté notifications programmées ;
3. validations serveur encore minimales ;
4. couverture de tests encore trop faible.

### Validation réelle
**❌ Validation réelle encore requise**

#### Points bloquants côté validation
1. Android réel ;
2. iOS réel ;
3. app ouverte / arrière-plan / fermée ;
4. deep link réel ;
5. scheduler réel ;
6. validation Firebase/APNs.

---

## Conclusion
Le module Notifications est fonctionnel sur le plan structurel et déjà bien intégré dans Cineva, mais il n'est pas encore certifiable RC1.

Il est proche d'un niveau commercial côté architecture, mais sa valeur réelle dépend de validations Firebase réelles et d'un meilleur cadrage produit sur la pertinence des messages.
