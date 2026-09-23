/// Offre Cineva et coordonnées de paiement.
///
/// Un seul abonnement couvre tout le foyer : **15 € par mois**, **5 appareils**
/// (téléphone, PC, TV) et **5 profils membres**. Le règlement se fait
/// directement auprès de Noah — par carte via Revolut, ou en main propre.
///
/// Ces valeurs vivent dans le code et non dans la table `app_settings` :
/// celle-ci est protégée par une policy « administration uniquement », l'app
/// abonné ne peut donc pas la lire. Les plafonds **techniques** (nombre
/// d'appareils, nombre de profils) restent pilotés par la base via
/// `app_settings.limits` — voir `supabase/migration_profils_abonnement.sql`.
abstract final class CinevaOffer {
  /// Prix mensuel d'un abonnement, en euros.
  static const int monthlyPriceEur = 15;

  /// Appareils connectés simultanément sur un même abonnement.
  static const int maxDevices = 5;

  /// Profils membres sur un même abonnement.
  static const int maxProfiles = 5;

  static const String priceLabel = '15 € / mois';
  static const String headline = 'Un abonnement, tout le foyer';
  static const String summary =
      'Un seul paiement couvre 5 appareils et 5 profils. Chacun garde sa liste '
      'et sa reprise de lecture.';

  /// Intermédiaire : qui contacter pour payer ou pour une question de compte.
  static const String contactName = 'Noah';

  /// Numéro affiché (format français lisible).
  static const String supportPhoneDisplay = '+33 7 87 14 69 92';

  /// Numéro au format E.164, utilisable pour un appel ou un copier-coller.
  static const String supportPhoneRaw = '+33787146992';

  /// Identifiant Revolut : le payer par carte ou depuis l'app Revolut.
  static const String revolutTag = '@noah_s0_xy5c';

  /// Ce que l'abonnement comprend, tel que vendu.
  static const List<String> included = <String>[
    '15 € par mois : un seul paiement pour tout le foyer',
    '5 appareils connectés — téléphone, PC, TV',
    '5 profils membres, chacun ses favoris et sa reprise',
    'Catalogue films et séries, lecture en continu',
    'Téléchargements pour regarder hors connexion',
  ];

  /// Marche à suivre pour régler l'abonnement.
  static const List<String> paymentSteps = <String>[
    'Par carte ou depuis Revolut : envoyez 15 € à $revolutTag.',
    'En main propre : remettez le montant à $contactName, puis prévenez au '
        '$supportPhoneDisplay pour que ce soit rattaché à votre compte.',
    'Dès réception, l’abonnement est prolongé d’un mois sur votre compte — la '
        'nouvelle date d’expiration s’affiche ici même.',
  ];

  /// Rappel affiché quand un paiement est en attente ou qu'une question se pose.
  static const String supportHint =
      'Une question sur votre abonnement, un appareil à déconnecter ou un '
      'paiement à régulariser ? Appelez ou écrivez au $supportPhoneDisplay.';
}
