part of 'catalog_screen.dart';

Future<void> _confirmDelete(
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

Future<void> _runCatalogAction(
  BuildContext context,
  WidgetRef ref,
  Future<dynamic> Function() action, {
  required String successMessage,
}) async {
  try {
    await action();
    ref.invalidate(adminMoviesProvider);
    ref.invalidate(adminSeriesProvider);
    ref.invalidate(adminCategoriesProvider);
    ref.invalidate(adminHomeSectionsProvider);
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
