/// Gestion de l'identifiant Cineva.
///
/// L'app accepte un **identifiant simple** (`noah`) à la place d'une adresse
/// email : Supabase n'authentifie que des emails, l'identifiant est donc
/// converti en adresse synthétique `noah@cineva.app` côté client. Aucun email
/// n'est envoyé à cette adresse — elle n'existe pas — ce qui permet de se
/// passer d'un service de messagerie.
///
/// Une vraie adresse email reste acceptée (comptes existants, administrateurs,
/// abonnés qui préfèrent un email) : dans ce cas rien n'est transformé et les
/// emails Supabase (confirmation, réinitialisation) fonctionnent normalement.
///
/// Conséquence à connaître : un compte par identifiant ne peut pas recevoir
/// d'email de réinitialisation de mot de passe. Le mot de passe se change
/// alors depuis la console d'administration, ou en passant le compte sur une
/// vraie adresse email.
abstract final class CinevaIdentifier {
  /// Domaine de repli des comptes créés sans adresse email.
  static const String fallbackDomain = 'cineva.app';

  /// Longueur minimale d'un identifiant.
  static const int minLength = 3;

  /// Longueur maximale d'un identifiant.
  static const int maxLength = 24;

  /// Caractères autorisés dans un identifiant : lettres, chiffres, point,
  /// tiret, underscore. Ni espace, ni accent, ni signe `@`.
  static final RegExp _allowed = RegExp(r'^[a-z0-9._-]+$');

  /// Un identifiant commence et finit par une lettre ou un chiffre.
  static final RegExp _edges = RegExp(r'^[a-z0-9].*[a-z0-9]$');

  /// Met en forme ce que l'utilisateur a saisi : minuscules, sans espaces.
  ///
  /// `Noah S` → `noahs`, `  NOAH ` → `noah`. Les emails sont également
  /// normalisés en minuscules, comme le fait Supabase.
  static String normalize(String raw) {
    return raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  /// Indique si [value] ressemble à une adresse email (et non à un identifiant).
  static bool looksLikeEmail(String value) {
    final int at = value.indexOf('@');
    if (at <= 0) return false;
    final String domain = value.substring(at + 1);
    return domain.contains('.') && !domain.startsWith('.') && !domain.endsWith('.');
  }

  /// Convertit la saisie en adresse utilisable par Supabase.
  ///
  /// À appeler après [normalize] : `noah` → `noah@cineva.app`,
  /// `noah@exemple.fr` → `noah@exemple.fr`.
  static String toEmail(String normalized) {
    return looksLikeEmail(normalized) ? normalized : '$normalized@$fallbackDomain';
  }

  /// Indique si cette adresse est une adresse synthétique d'identifiant.
  static bool isSyntheticEmail(String? email) {
    if (email == null) return false;
    return email.toLowerCase().endsWith('@$fallbackDomain');
  }

  /// Ce qui doit être affiché à l'utilisateur : l'identifiant pour un compte
  /// synthétique (`noah`), l'adresse complète pour un vrai email.
  static String displayName(String? email) {
    if (email == null) return '';
    final String value = email.trim();
    if (value.isEmpty) return '';
    return isSyntheticEmail(value) ? value.substring(0, value.indexOf('@')) : value;
  }

  /// Message d'erreur lisible, ou `null` si la saisie est acceptable.
  ///
  /// Un seul point d'entrée pour la connexion, l'inscription et les tests :
  /// les règles ne divergent pas d'un écran à l'autre.
  static String? validationError(String raw) {
    final String value = normalize(raw);
    if (value.isEmpty) return 'Saisissez votre identifiant.';

    if (looksLikeEmail(value)) {
      final int at = value.indexOf('@');
      final String name = value.substring(0, at);
      final String domain = value.substring(at + 1);
      if (name.isEmpty || domain.split('.').any((String part) => part.isEmpty)) {
        return 'Cette adresse email est incomplète.';
      }
      return null;
    }

    if (value.contains('@')) {
      return 'Identifiant invalide : le signe @ n’est autorisé que dans une adresse email complète.';
    }
    if (!_allowed.hasMatch(value)) {
      return 'L’identifiant accepte uniquement des lettres, des chiffres, le point, '
          'le tiret et le tiret bas.';
    }
    if (value.length < minLength) {
      return 'L’identifiant doit contenir au moins $minLength caractères.';
    }
    if (value.length > maxLength) {
      return 'L’identifiant doit contenir au plus $maxLength caractères.';
    }
    if (!_edges.hasMatch(value)) {
      return 'L’identifiant doit commencer et finir par une lettre ou un chiffre.';
    }
    return null;
  }
}
