# Cineva — RC1 Checklist

## Application utilisateur

### Authentification
- [ ] Connexion email / mot de passe
- [ ] Inscription utilisateur
- [ ] Réinitialisation mot de passe
- [ ] Session persistée après redémarrage
- [ ] Session expirée correctement gérée

### Abonnement
- [ ] Compte actif : accès complet
- [ ] Compte expiré : blocage du contenu
- [ ] Réactivation automatique après prolongation admin
- [ ] Affichage date d’expiration et jours restants

### Accueil / recherche
- [ ] Hero chargé correctement
- [ ] Rails dynamiques
- [ ] Ma liste fonctionnelle
- [ ] Continuer le visionnage fonctionnel
- [ ] Recherche instantanée
- [ ] Filtres recherche
- [ ] Suggestions recherche
- [ ] Navigation fiche contenu depuis Home et Recherche

### Lecture vidéo
- [ ] Lecture standard
- [ ] Reprise à la bonne position
- [ ] Changement de qualité
- [ ] Test flux HLS
- [ ] Test flux DASH
- [ ] Sous-titres sélectionnables
- [ ] Multi-audio si disponible
- [ ] Skip intro
- [ ] Skip crédits
- [ ] Épisode suivant auto
- [ ] Android TV navigation télécommande
- [ ] Plein écran
- [ ] Retour fiche contenu
- [ ] Erreur réseau bien affichée
- [ ] Reprise après interruption application

### Téléchargements
- [ ] Téléchargement local réel
- [ ] Pause téléchargement
- [ ] Reprise téléchargement
- [ ] File d’attente
- [ ] Plusieurs téléchargements simultanés
- [ ] Relance application avec téléchargement non terminé
- [ ] Lecture hors connexion
- [ ] Suppression locale
- [ ] Nettoyage local après suppression
- [ ] Comportement faible espace disque

### Notifications
- [ ] Réception notification app ouverte
- [ ] Réception notification arrière-plan
- [ ] Réception notification app fermée
- [ ] Ouverture fiche contenu au clic
- [ ] Notification globale
- [ ] Notification individuelle
- [ ] Notification programmée

### Paramètres / Cineva Vision
- [ ] Langue
- [ ] Thème
- [ ] Qualité vidéo globale
- [ ] Notifications utilisateur
- [ ] Confidentialité
- [ ] Cineva Vision profils
- [ ] Cineva Vision aperçu avant/après
- [ ] Cineva Vision appliqué pendant la lecture

## Application Admin

### Utilisateurs
- [ ] Créer utilisateur
- [ ] Modifier utilisateur
- [ ] Suspendre / réactiver
- [ ] Réinitialiser mot de passe
- [ ] Supprimer utilisateur
- [ ] Voir appareils
- [ ] Supprimer appareil
- [ ] Déconnecter tous les appareils

### Abonnements
- [ ] Ajouter des mois
- [ ] Définir une date d’expiration
- [ ] Voir comptes expirés
- [ ] Voir comptes bientôt expirés

### Catalogue
- [ ] CRUD films
- [ ] CRUD séries
- [ ] CRUD saisons
- [ ] CRUD épisodes
- [ ] Définir épisode pilote
- [ ] Upload affiche
- [ ] Upload bannière
- [ ] Upload logo
- [ ] Upload miniature épisode
- [ ] Gestion catégories

### Accueil
- [ ] CRUD sections accueil
- [ ] Réordonner contenus dans une section
- [ ] Publier/masquer une section
- [ ] Vérifier rendu côté app utilisateur

### Notifications
- [ ] Créer notification globale
- [ ] Créer notification ciblée
- [ ] Créer notification programmée
- [ ] Historique notifications
- [ ] Statuts envoyée / programmée / échouée

### Statistiques
- [ ] Dashboard principal
- [ ] Contenus les plus vus
- [ ] Watch time
- [ ] Téléchargements
- [ ] Utilisateurs récents
- [ ] Appareils récents

## Multi-plateforme
- [ ] Android
- [ ] iOS
- [ ] Windows
- [ ] macOS
- [ ] Android TV

## Pré-release
- [ ] Analyse Flutter sans erreur bloquante
- [ ] Tests unitaires lancés
- [ ] Tests d’intégration lancés
- [ ] Edge Functions déployées
- [ ] Variables d’environnement configurées
- [ ] Base de données migrée
- [ ] Buckets Storage configurés
