import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: ref.read(adminUserSearchQueryProvider));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);
    final filter = ref.watch(adminUserFilterProvider);

    return ListView(
      padding: const EdgeInsets.all(CinevaSpacing.lg),
      children: <Widget>[
        CinevaPageHeader(
          title: 'Utilisateurs',
          subtitle: 'Gestion complète des comptes, abonnements, réinitialisation mot de passe et appareils connectés.',
          trailing: Wrap(
            spacing: 8,
            children: <Widget>[
              IconButton(
                onPressed: () {
                  ref.invalidate(adminUsersProvider);
                  ref.invalidate(dashboardSummaryProvider);
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
              FilledButton.icon(
                onPressed: () => _showUserEditor(context, ref),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Créer un utilisateur'),
              ),
            ],
          ),
        ),
        const SizedBox(height: CinevaSpacing.xl),
        CinevaGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CinevaTextField(
                controller: _searchController,
                label: 'Rechercher',
                hint: 'Nom ou email',
                prefixIcon: Icons.search_rounded,
                onChanged: (value) => ref.read(adminUserSearchQueryProvider.notifier).state = value,
              ),
              const SizedBox(height: CinevaSpacing.md),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AdminUserFilter.values
                    .map(
                      (candidate) => ChoiceChip(
                        label: Text(candidate.label),
                        selected: filter == candidate,
                        onSelected: (_) => ref.read(adminUserFilterProvider.notifier).state = candidate,
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: CinevaSpacing.xl),
        usersAsync.when(
          loading: () => const SizedBox(height: 280, child: CinevaLoadingView(label: 'Chargement des utilisateurs...')),
          error: (error, _) => CinevaStatusBanner(
            title: 'Impossible de charger les utilisateurs',
            message: error.toString(),
            tone: CinevaBannerTone.error,
          ),
          data: (users) {
            if (users.isEmpty) {
              return const CinevaStatusBanner(
                title: 'Aucun résultat',
                message: 'Aucun utilisateur ne correspond au filtre actif.',
              );
            }
            return Column(
              children: users
                  .map(
                    (user) => Padding(
                      padding: const EdgeInsets.only(bottom: CinevaSpacing.md),
                      child: _AdminUserCard(user: user),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _AdminUserCard extends ConsumerWidget {
  const _AdminUserCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = user.isAdmin
        ? CinevaColors.accentSoft
        : user.isSuspended
            ? CinevaColors.warning
            : user.hasActiveSubscription
                ? CinevaColors.success
                : CinevaColors.warning;

    return CinevaGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(user.fullName, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(user.email, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  user.isAdmin
                      ? 'Admin'
                      : user.isSuspended
                          ? 'Suspendu'
                          : user.hasActiveSubscription
                              ? 'Actif'
                              : 'Expiré',
                ),
              ),
            ],
          ),
          const SizedBox(height: CinevaSpacing.md),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _ChipText('Expiration : ${user.subscriptionExpiresLabel}'),
              _ChipText('Jours restants : ${user.daysRemaining}'),
              _ChipText('Rôle : ${user.role}'),
            ],
          ),
          const SizedBox(height: CinevaSpacing.lg),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => _showUserEditor(context, ref, user: user),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Modifier'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showSubscriptionDialog(context, ref, user),
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text('Abonnement'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showDevicesDialog(context, ref, user),
                icon: const Icon(Icons.devices_other_rounded),
                label: const Text('Appareils'),
              ),
              OutlinedButton.icon(
                onPressed: () => _confirmAction(
                  context,
                  title: 'Réinitialiser le mot de passe',
                  message: 'Envoyer un email de réinitialisation à ${user.email} ?',
                  onConfirm: () => _runAdminAction(
                    context,
                    ref,
                    () => ref.read(adminRepositoryProvider).resetPassword(email: user.email),
                    successMessage: 'Email de réinitialisation envoyé.',
                  ),
                ),
                icon: const Icon(Icons.lock_reset_rounded),
                label: const Text('Réinitialiser mot de passe'),
              ),
              OutlinedButton.icon(
                onPressed: user.isSuspended
                    ? () => _runAdminAction(
                          context,
                          ref,
                          () => ref.read(adminRepositoryProvider).reactivateUser(userId: user.id),
                          successMessage: '${user.fullName} réactivé.',
                        )
                    : () => _confirmAction(
                          context,
                          title: 'Suspendre ce compte',
                          message: 'Suspendre l’accès de ${user.fullName} ?',
                          onConfirm: () => _runAdminAction(
                            context,
                            ref,
                            () => ref.read(adminRepositoryProvider).suspendUser(userId: user.id),
                            successMessage: '${user.fullName} suspendu.',
                          ),
                        ),
                icon: Icon(user.isSuspended ? Icons.play_circle_outline_rounded : Icons.pause_circle_outline_rounded),
                label: Text(user.isSuspended ? 'Réactiver' : 'Suspendre'),
              ),
              if (!user.isAdmin)
                OutlinedButton.icon(
                  onPressed: () => _confirmAction(
                    context,
                    title: 'Supprimer définitivement',
                    message: 'Cette action supprimera le compte ${user.email} et ses accès Auth.',
                    onConfirm: () => _runAdminAction(
                      context,
                      ref,
                      () => ref.read(adminRepositoryProvider).deleteUser(user.id),
                      successMessage: 'Utilisateur supprimé.',
                    ),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('Supprimer'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipText extends StatelessWidget {
  const _ChipText(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CinevaColors.surfaceRaised,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(label),
      ),
    );
  }
}

Future<void> _showUserEditor(BuildContext context, WidgetRef ref, {AppUser? user}) async {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: user?.fullName ?? '');
  final emailController = TextEditingController(text: user?.email ?? '');
  final passwordController = TextEditingController();
  final expiresController = TextEditingController(text: user?.subscriptionExpiresLabel == 'Aucune date' ? '' : user?.subscriptionExpiresLabel ?? '');
  String role = user?.role ?? 'user';
  String status = user?.status ?? 'active';
  DateTime? expiresAt = user?.subscriptionExpiresAt;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: CinevaColors.surface,
            title: Text(user == null ? 'Créer un utilisateur' : 'Modifier ${user.fullName}'),
            content: SizedBox(
              width: 520,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nom complet'),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'Nom requis' : null,
                    ),
                    const SizedBox(height: CinevaSpacing.md),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) => (value == null || !value.contains('@')) ? 'Email invalide' : null,
                    ),
                    const SizedBox(height: CinevaSpacing.md),
                    if (user == null)
                      TextFormField(
                        controller: passwordController,
                        decoration: const InputDecoration(labelText: 'Mot de passe temporaire'),
                        validator: (value) => (value == null || value.length < 6) ? '6 caractères minimum' : null,
                      ),
                    const SizedBox(height: CinevaSpacing.md),
                    DropdownButtonFormField<String>(
                      value: role,
                      decoration: const InputDecoration(labelText: 'Rôle'),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(value: 'user', child: Text('Utilisateur')),
                        DropdownMenuItem(value: 'admin', child: Text('Administrateur')),
                      ],
                      onChanged: (value) => setState(() => role = value ?? 'user'),
                    ),
                    const SizedBox(height: CinevaSpacing.md),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'Statut'),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(value: 'active', child: Text('Actif')),
                        DropdownMenuItem(value: 'suspended', child: Text('Suspendu')),
                      ],
                      onChanged: (value) => setState(() => status = value ?? 'active'),
                    ),
                    const SizedBox(height: CinevaSpacing.md),
                    TextFormField(
                      controller: expiresController,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: 'Date d’expiration'),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: expiresAt ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) {
                          expiresAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
                          expiresController.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                          setState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.of(dialogContext).pop();
                  await _runAdminAction(
                    context,
                    ref,
                    () => user == null
                        ? ref.read(adminRepositoryProvider).createUser(
                              email: emailController.text.trim(),
                              password: passwordController.text,
                              fullName: nameController.text.trim(),
                              role: role,
                              expiresAt: expiresAt,
                            )
                        : ref.read(adminRepositoryProvider).updateUserProfile(
                              userId: user.id,
                              email: emailController.text.trim(),
                              fullName: nameController.text.trim(),
                              role: role,
                              status: status,
                              expiresAt: expiresAt,
                            ),
                    successMessage: user == null ? 'Utilisateur créé.' : 'Utilisateur mis à jour.',
                  );
                },
                child: Text(user == null ? 'Créer' : 'Enregistrer'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showSubscriptionDialog(BuildContext context, WidgetRef ref, AppUser user) async {
  final monthsController = TextEditingController(text: '1');
  final noteController = TextEditingController();
  DateTime? expiresAt = user.subscriptionExpiresAt ?? DateTime.now().add(const Duration(days: 30));

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: CinevaColors.surface,
            title: Text('Abonnement — ${user.fullName}'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Expiration actuelle : ${user.subscriptionExpiresLabel}'),
                  const SizedBox(height: CinevaSpacing.md),
                  TextField(
                    controller: monthsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Ajouter des mois'),
                  ),
                  const SizedBox(height: CinevaSpacing.md),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Note interne'),
                  ),
                  const SizedBox(height: CinevaSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: expiresAt ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) {
                        expiresAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.event_rounded),
                    label: Text(expiresAt == null ? 'Choisir une date d’expiration' : 'Expiration : ${expiresAt!.day}/${expiresAt!.month}/${expiresAt!.year}'),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Fermer')),
              OutlinedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _runAdminAction(
                    context,
                    ref,
                    () => ref.read(adminRepositoryProvider).addMonths(
                          userId: user.id,
                          months: int.tryParse(monthsController.text.trim()) ?? 1,
                          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                        ),
                    successMessage: 'Abonnement prolongé.',
                  );
                },
                child: const Text('+ Ajouter du temps'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _runAdminAction(
                    context,
                    ref,
                    () => ref.read(adminRepositoryProvider).setExpiration(
                          userId: user.id,
                          expiresAt: expiresAt ?? DateTime.now(),
                          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                        ),
                    successMessage: 'Date d’expiration mise à jour.',
                  );
                },
                child: const Text('Définir la date'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showDevicesDialog(BuildContext context, WidgetRef ref, AppUser user) async {
  final devices = await ref.read(adminRepositoryProvider).fetchUserDevices(user.id);
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: CinevaColors.surface,
        title: Text('Appareils — ${user.fullName}'),
        content: SizedBox(
          width: 560,
          child: devices.isEmpty
              ? const Text('Aucun appareil enregistré.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.devices_rounded),
                      title: Text(device.displayName),
                      subtitle: Text('${device.platform.toUpperCase()} • ${device.appVersion ?? 'Version inconnue'}'),
                      trailing: IconButton(
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          await _runAdminAction(
                            context,
                            ref,
                            () => ref.read(adminRepositoryProvider).removeUserDevice(device.id),
                            successMessage: 'Appareil supprimé.',
                          );
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(),
                  itemCount: devices.length,
                ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Fermer')),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _runAdminAction(
                context,
                ref,
                () => ref.read(adminRepositoryProvider).disconnectAllDevices(user.id),
                successMessage: 'Tous les appareils ont été déconnectés.',
              );
            },
            icon: const Icon(Icons.power_settings_new_rounded),
            label: const Text('Tout déconnecter'),
          ),
        ],
      );
    },
  );
}

Future<void> _confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required Future<void> Function() onConfirm,
}) async {
  final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: CinevaColors.surface,
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Confirmer')),
          ],
        ),
      ) ??
      false;
  if (confirmed) {
    await onConfirm();
  }
}

Future<void> _runAdminAction(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action, {
  required String successMessage,
}) async {
  try {
    await action();
    ref.invalidate(adminUsersProvider);
    ref.invalidate(adminAllUsersProvider);
    ref.invalidate(dashboardSummaryProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}
