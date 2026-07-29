# Cineva — RC1 Checklist Notifications

## Backend / Edge Functions
- [ ] `send-fcm-notification` déployée
- [ ] `process-scheduled-notifications` déployée
- [ ] `CRON_SECRET` configuré
- [ ] `FCM_SERVER_KEY` configuré
- [ ] `SUPABASE_SERVICE_ROLE_KEY` configuré
- [ ] tokens invalides nettoyés

## Admin
- [ ] création notification globale
- [ ] création notification ciblée
- [ ] création notification programmée
- [ ] historique visible
- [ ] statuts visibles (scheduled / sent / failed)
- [ ] deep link contenu renseigné

## App utilisateur
- [ ] récupération du token FCM
- [ ] enregistrement du token sur l'appareil
- [ ] réception en foreground
- [ ] réception en arrière-plan
- [ ] réception app fermée
- [ ] ouverture du bon contenu via `contentId`
- [ ] fallback route via `screen`

## Android réel
- [ ] notification globale reçue
- [ ] notification ciblée reçue
- [ ] notification programmée reçue
- [ ] clic ouvre la bonne fiche
- [ ] comportement foreground correct

## iOS réel
- [ ] autorisation notifications
- [ ] notification globale reçue
- [ ] notification ciblée reçue
- [ ] notification programmée reçue
- [ ] clic ouvre la bonne fiche
- [ ] comportement app fermée correct

## Windows / macOS
- [ ] vérifier comportement Flutter desktop si support actif
- [ ] absence de crash si FCM non disponible

## Android TV
- [ ] ouverture profonde fonctionnelle
- [ ] comportement focus après ouverture depuis notification
