import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

Future<void> runAdminAction(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action, {
  required String successMessage,
  bool refreshUsers = false,
  bool refreshDashboard = false,
  bool refreshNotifications = false,
}) async {
  try {
    await action();
    if (refreshUsers) {
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminAllUsersProvider);
    }
    if (refreshDashboard) {
      ref.invalidate(dashboardSummaryProvider);
    }
    if (refreshNotifications) {
      ref.invalidate(adminNotificationsProvider);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

Future<void> confirmAdminAction(
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
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ) ??
      false;
  if (confirmed) {
    await onConfirm();
  }
}

class AdminChipText extends StatelessWidget {
  const AdminChipText(this.label, {super.key});

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
