# 02 — Backend Supabase et sécurité

## 1. Rôle du backend

Supabase n'est pas seulement la base de données ; il devient le **centre de contrôle métier** de Cineva.

Tout ce qui est critique doit être validé côté serveur :

- connexion ;
- rôle admin ;
- abonnement actif ;
- suspension ;
- limite d'appareils ;
- accès streaming ;
- accès téléchargement ;
- notifications ;
- statistiques.

## 2. Briques Supabase utilisées

### Auth
- création et gestion des comptes ;
- sessions ;
- récupération mot de passe (comptes créés avec une vraie adresse email) ;
- rôles applicatifs via `profiles.role` ;
- **connexion par identifiant** : l'app convertit `noah` en `noah@cineva.app`
  (`CinevaIdentifier`), Supabase ne gère que des emails. Aucun email n'est
  envoyé à cette adresse.
- **réglage requis** : Authentication → Providers → Email → « Confirm email »
  **désactivé**, sinon un compte créé par identifiant n'obtient aucune session
  (détails dans `10_abonnement_profils.md`, section E).

### Postgres
- données métier ;
- fonctions SQL ;
- vues ;
- historique ;
- contraintes ;
- règles métier persistantes.

### Storage
Buckets recommandés :

- `avatars`
- `posters`
- `backdrops`
- `trailers`
- `movies`
- `episodes`
- `subtitles`
- `downloads-temp` si besoin

### Edge Functions
Pour encapsuler les opérations sensibles :

- `register-device`
- `remove-device`
- `validate-access`
- `extend-subscription`
- `set-expiration`
- `suspend-user`
- `reactivate-user`
- `send-user-notification`
- `send-broadcast-notification`
- `create-signed-media-url`
- `create-download-license`

## 3. Sécurité fonctionnelle

## 3.1 Abonnement
Un utilisateur peut ouvrir l'application même si l'abonnement a expiré.

Mais dans ce cas :
- l'app charge son profil ;
- le backend indique que l'accès est bloqué ;
- le contenu vidéo n'est pas délivré ;
- un écran d'abonnement expiré est affiché.

## 3.2 Appareil unique
Le backend enregistre un identifiant d'appareil.

Flux attendu :
1. connexion utilisateur ;
2. appel serveur `register-device` ;
3. vérification du nombre d'appareils actifs ;
4. si limite atteinte et appareil inconnu : refus ;
5. l'utilisateur doit supprimer l'ancien appareil ;
6. nouvelle tentative ensuite.

Le nombre maximum d'appareils ne doit pas être codé en dur dans l'app, mais dans un réglage serveur.

## 3.3 Accès média
Ne jamais exposer directement des URLs permanentes vers les vidéos.

Approche recommandée :
- stockage privé ;
- génération d'URLs signées de courte durée ;
- validation préalable de l'abonnement ;
- validation de l'appareil ;
- journalisation des accès.

## 4. Notifications

### Cas d'usage
- message à tous ;
- message à un utilisateur ;
- notification programmée ;
- rappel d'expiration ;
- annonce de nouveaux contenus.

### Flux
1. l'admin crée la notification ;
2. le backend enregistre l'événement ;
3. un worker / cron déclenche l'envoi ;
4. le statut passe à `sent`, `failed` ou `scheduled`.

## 5. Statistiques

Mesures à consolider côté backend :
- temps de visionnage ;
- contenus les plus vus ;
- nouveaux utilisateurs ;
- téléchargements ;
- appareils actifs ;
- taux d'expiration.

Ces stats peuvent être construites par :
- tables d'événements ;
- vues SQL ;
- agrégations planifiées.

## 6. Stratégie recommandée pour l'admin

L'application Admin ne doit pas utiliser de privilèges excessifs côté client.

Préférer :
- authentification admin standard ;
- vérification de rôle côté base ;
- opérations sensibles via Edge Functions ;
- audit trail sur chaque action importante.

Exemples d'actions journalisées :
- ajout de mois ;
- suspension ;
- suppression d'appareil ;
- modification date d'expiration ;
- suppression de contenu ;
- envoi de notification.

## 7. Offline et téléchargements

Les téléchargements ne doivent pas être considérés comme des copies permanentes.

Prévoir :
- licence locale ;
- clé d'expiration ;
- révocation ;
- suppression ou invalidation si abonnement non valide.

## 8. Déploiement

Le backend peut être hébergé avec :
- Supabase Cloud ;
- serveur complémentaire si besoin futur ;
- CDN additionnel pour montée en charge vidéo.

## 9. Conclusion

Supabase couvre très bien la couche métier initiale à condition de :

- bien structurer le schéma ;
- verrouiller les accès par RLS ;
- déplacer les règles sensibles en SQL/Edge Functions ;
- éviter toute confiance excessive dans le client Flutter.
