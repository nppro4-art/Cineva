import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

class AdminNotificationsScreen extends ConsumerWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(adminNotificationsProvider);
    final usersAsync = ref.watch(adminAllUsersProvider);

    return ListView(
      padding: const EdgeInsets.all(CinevaSpacing.lg),
      children: <Widget>[
        CinevaPageHeader(
          title: 'Notifications',
          subtitle: 'Envoi global, ciblé ou planifié depuis l’admin sans toucher à la base.',
          trailing: FilledButton.icon(
            onPressed: usersAsync.hasValue ? () => _showNotificationComposer(context, ref, usersAsync.value ?? const <AppUser>[]) : null,
            icon: const Icon(Icons.add_alert_rounded),
            label: const Text('Créer une notification'),
          ),
        ),
        const SizedBox(height: CinevaSpacing.xl),
        notificationsAsync.when(
          loading: () => const SizedBox(height: 220, child: CinevaLoadingView(label: 'Chargement des notifications...')),
          error: (error, _) => CinevaStatusBanner(
            title: 'Notifications indisponibles',
            message: error.toString(),
            tone: CinevaBannerTone.error,
          ),
          data: (items) {
            if (items.isEmpty) {
              return const CinevaStatusBanner(
                title: 'Aucune notification',
                message: 'Les notifications envoyées ou planifiées apparaîtront ici.',
              );
            }
            return Column(
              children: items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: CinevaSpacing.md),
                child: _NotificationCard(item: item),
              )).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});

  final AdminNotificationModel item;

  @override
  Widget build(BuildContext context) {
    return CinevaGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(item.title, style: Theme.of(context).textTheme.titleMedium)),
              _StatusPill(status: item.status),
            ],
          ),
          const SizedBox(height: CinevaSpacing.sm),
          Text(item.body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted)),
          const SizedBox(height: CinevaSpacing.md),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _MetaChip(item.isBroadcast ? 'Tous les utilisateurs' : 'Utilisateur ciblé'),
              _MetaChip('Canal : ${item.channel}'),
              if (item.scheduledAt != null) _MetaChip('Programmée : ${_format(item.scheduledAt!)}'),
              if (item.sentAt != null) _MetaChip('Envoyée : ${_format(item.sentAt!)}'),
            ],
          ),
        ],
      ),
    );
  }

  String _format(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'sent' => CinevaColors.success,
      'scheduled' => CinevaColors.warning,
      'failed' => CinevaColors.danger,
      _ => CinevaColors.accentSoft,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(999)),
      child: Text(status),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: CinevaColors.surfaceRaised, borderRadius: BorderRadius.circular(999)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(text),
      ),
    );
  }
}

Future<void> _showNotificationComposer(BuildContext context, WidgetRef ref, List<AppUser> users) async {
  final titleController = TextEditingController();
  final bodyController = TextEditingController();
  final contentIdController = TextEditingController();
  final screenController = TextEditingController();
  String? targetUserId;
  DateTime? scheduledAt;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: CinevaColors.surface,
            title: const Text('Nouvelle notification'),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Titre'),
                  ),
                  const SizedBox(height: CinevaSpacing.md),
                  TextField(
                    controller: bodyController,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Message'),
                  ),
                  const SizedBox(height: CinevaSpacing.md),
                  DropdownButtonFormField<String?>(
                    value: targetUserId,
                    decoration: const InputDecoration(labelText: 'Destinataire'),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(value: null, child: Text('Tous les utilisateurs')),
                      ...users.map((user) => DropdownMenuItem<String?>(value: user.id, child: Text('${user.fullName} — ${user.email}'))),
                    ],
                    onChanged: (value) => setState(() => targetUserId = value),
                  ),
                  const SizedBox(height: CinevaSpacing.md),
                  TextField(
                    controller: contentIdController,
                    decoration: const InputDecoration(labelText: 'ID contenu à ouvrir (optionnel)'),
                  ),
                  const SizedBox(height: CinevaSpacing.md),
                  TextField(
                    controller: screenController,
                    decoration: const InputDecoration(labelText: 'Route de fallback (optionnelle, ex: /home)'),
                  ),
                  const SizedBox(height: CinevaSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDate == null || !context.mounted) return;
                      final pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                      if (pickedTime == null) return;
                      setState(() {
                        scheduledAt = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    },
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(scheduledAt == null ? 'Envoyer immédiatement' : 'Planifiée : ${scheduledAt!.day}/${scheduledAt!.month} ${scheduledAt!.hour}:${scheduledAt!.minute.toString().padLeft(2, '0')}'),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Annuler')),
              FilledButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _runNotificationAction(
                    context,
                    ref,
                    () => ref.read(adminRepositoryProvider).createNotification(
                          title: titleController.text.trim(),
                          body: bodyController.text.trim(),
                          userId: targetUserId,
                          scheduledAt: scheduledAt,
                          contentId: contentIdController.text.trim().isEmpty ? null : contentIdController.text.trim(),
                          screen: screenController.text.trim().isEmpty ? null : screenController.text.trim(),
                        ),
                    successMessage: scheduledAt == null ? 'Notification enregistrée comme envoyée.' : 'Notification programmée.',
                  );
                },
                child: const Text('Valider'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _runNotificationAction(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action, {
  required String successMessage,
}) async {
  try {
    await action();
    ref.invalidate(adminNotificationsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}
