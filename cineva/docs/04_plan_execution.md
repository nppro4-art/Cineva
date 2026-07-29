# 04 — Plan d'exécution recommandé

## Principe

Le projet doit avancer par **lots fermés et validés**, conformément à votre exigence :

> chaque fonctionnalité doit être finalisée avant de passer à la suivante.

---

## Lot 0 — Fondation

### Objectifs
- monorepo créé ;
- conventions de code ;
- structure packages ;
- base documentaire ;
- scripts standard.

### Critère de validation
- dépôt propre ;
- structure claire ;
- documentation lisible.

---

## Lot 1 — Backend initial Supabase

### Objectifs
- schéma BDD ;
- tables principales ;
- buckets ;
- RLS ;
- fonctions SQL de base ;
- rôles admin.

### Critère de validation
- base initialisable sans erreur ;
- règles d'accès en place.

---

## Lot 2 — Authentification et profils

### Objectifs
- inscription / connexion ;
- récupération mot de passe ;
- profil utilisateur ;
- rôle admin ;
- écran de chargement de session.

### Critère de validation
- session stable ;
- navigation sécurisée.

---

## Lot 3 — Abonnements et gestion d'appareil unique

### Objectifs
- date d'expiration ;
- calcul jours restants ;
- suspension ;
- réactivation ;
- blocage de contenu si expiré ;
- écran abonnement expiré ;
- appareil unique côté serveur ;
- suppression ancien appareil.

### Critère de validation
- aucune lecture possible si abonnement invalide ;
- connexion refusée si appareil en trop.

---

## Lot 4 — Shell utilisateur premium

### Objectifs
- home shell ;
- bottom nav mobile ;
- sidebar desktop ;
- fondations TV ;
- thème premium ;
- animations système.

### Critère de validation
- expérience cohérente sur mobile, desktop, TV.

---

## Lot 5 — Catalogue et accueil

### Objectifs
- bannière principale ;
- sections dynamiques ;
- catégories ;
- films ;
- séries ;
- animés ;
- documentaires ;
- derniers ajouts ;
- ma liste.

### Critère de validation
- home configurable via admin/back-end.

---

## Lot 6 — Recherche

### Objectifs
- recherche instantanée ;
- historique ;
- suggestions ;
- filtres film/série/acteur/réalisateur/genre.

### Critère de validation
- résultats rapides et pertinents.

---

## Lot 7 — Lecteur vidéo

### Objectifs
- play/pause ;
- plein écran ;
- sous-titres ;
- langue ;
- sauvegarde progression ;
- reprise automatique.

### Critère de validation
- progression persistée ;
- reprise fidèle ;
- UX premium.

---

## Lot 8 — Téléchargements

### Objectifs
- téléchargement ;
- progression ;
- pause ;
- reprise ;
- suppression ;
- validation d'accès offline.

### Critère de validation
- téléchargements fiables ;
- comportement clair à expiration.

---

## Lot 9 — Application Admin

### Objectifs
- dashboard ;
- gestion utilisateurs ;
- gestion films ;
- gestion séries ;
- gestion accueil ;
- notes privées ;
- reset mot de passe ;
- appareils ;
- abonnements.

### Critère de validation
- administration complète sans SQL manuel.

---

## Lot 10 — Notifications

### Objectifs
- push global ;
- push ciblé ;
- planification.

### Critère de validation
- delivery observable et traçable.

---

## Lot 11 — Statistiques

### Objectifs
- temps de visionnage ;
- contenus les plus vus ;
- nouveaux utilisateurs ;
- téléchargements ;
- comptes actifs/expirés.

### Critère de validation
- dashboard utile et cohérent.

---

## Lot 12 — Stabilisation finale

### Objectifs
- corrections ;
- tests ;
- polish ;
- optimisation ;
- scripts finaux de compilation ;
- README final.

### Critère de validation
- build sans erreur ;
- documentation complète ;
- livraison propre.

---

## Priorité immédiate recommandée

Pour transformer ce dossier en projet réel, le meilleur enchaînement est :

1. générer le scaffold Flutter réel ;
2. poser le backend Supabase ;
3. implémenter le lot 2 et le lot 3 avant tout le reste.
