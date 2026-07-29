class UserProfileModel {
  const UserProfileModel({
    required this.fullName,
    required this.email,
    required this.subscriptionExpiresLabel,
    required this.daysRemaining,
    this.avatarPath,
  });

  final String fullName;
  final String email;
  final String subscriptionExpiresLabel;
  final int daysRemaining;
  final String? avatarPath;
}
