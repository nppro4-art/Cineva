import 'package:equatable/equatable.dart';

/// Profil membre d'un foyer Cineva.
///
/// Un abonnement (15 € / mois) couvre jusqu'à 5 appareils **et** 5 profils :
/// chacun a sa propre liste de favoris, sa reprise de lecture et ses
/// téléchargements, sans compte ni adresse e-mail supplémentaires.
///
/// Le plafond est appliqué côté base (`enforce_member_profile_limit`) et
/// vérifié côté app avant l'appel réseau — voir
/// `supabase/migration_profils_abonnement.sql`.
class MemberProfileModel extends Equatable {
  const MemberProfileModel({
    required this.id,
    required this.accountId,
    required this.name,
    this.avatarKey = defaultAvatarKey,
    this.colorKey = defaultColorKey,
    this.isKid = false,
    this.sortOrder = 0,
    this.createdAt,
  });

  /// Avatar par défaut d'un profil créé sans choix explicite.
  static const String defaultAvatarKey = 'popcorn';

  /// Couleur par défaut de la pastille du profil.
  static const String defaultColorKey = 'gold';

  /// Avatars proposés à la création (clés stables, mappées vers des icônes
  /// dans la couche présentation — aucune dépendance à un asset distant).
  static const List<String> avatarChoices = <String>[
    'popcorn',
    'star',
    'clap',
    'rocket',
    'mask',
    'reel',
  ];

  /// Couleurs proposées à la création.
  static const List<String> colorChoices = <String>[
    'gold',
    'violet',
    'emerald',
    'sky',
    'rose',
    'amber',
  ];

  /// Identifiant du profil (`''` tant qu'il n'est pas enregistré).
  final String id;

  /// Compte propriétaire : l'abonnement est partagé, les profils sont rattachés
  /// au même `user_id`.
  final String accountId;

  final String name;
  final String avatarKey;
  final String colorKey;

  /// Profil enfant : affichage adapté, sans contenu signalé adulte.
  final bool isKid;

  final int sortOrder;
  final DateTime? createdAt;

  /// Vrai tant que le profil n'existe pas encore en base.
  bool get isDraft => id.isEmpty;

  /// Initiale majuscule, pour la pastille quand aucune icône ne convient.
  String get initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  /// Nom nettoyé et borné : évite les noms vides ou interminables en base.
  static String normalizeName(String raw) {
    final collapsed = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length <= 24) return collapsed;
    return collapsed.substring(0, 24).trim();
  }

  MemberProfileModel copyWith({
    String? id,
    String? accountId,
    String? name,
    String? avatarKey,
    String? colorKey,
    bool? isKid,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return MemberProfileModel(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      name: name ?? this.name,
      avatarKey: avatarKey ?? this.avatarKey,
      colorKey: colorKey ?? this.colorKey,
      isKid: isKid ?? this.isKid,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        accountId,
        name,
        avatarKey,
        colorKey,
        isKid,
        sortOrder,
        createdAt,
      ];
}
