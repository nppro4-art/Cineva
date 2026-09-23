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
  String? Function(dynamic result)? warningOf,
}) async {
  try {
    final result = await action();
    final warning = warningOf?.call(result);
    _finishCatalogAction(
      context,
      ref,
      message: warning == null || warning.isEmpty ? successMessage : '$successMessage $warning',
      long: warning != null && warning.isNotEmpty,
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(_catalogErrorText(error)),
            duration: const Duration(seconds: 9),
          ),
        );
    }
  }
}

/// Recharge les listes du catalogue puis affiche [message].
///
/// Séparé de [_runCatalogAction] pour les écrans qui pilotent eux-mêmes
/// l'enregistrement (éditeur de fiche : la boîte de dialogue reste ouverte tant
/// que ça n'a pas abouti).
void _finishCatalogAction(
  BuildContext context,
  WidgetRef ref, {
  required String message,
  bool long = false,
}) {
  ref.invalidate(adminMoviesProvider);
  ref.invalidate(adminSeriesProvider);
  ref.invalidate(adminCategoriesProvider);
  ref.invalidate(adminHomeSectionsProvider);
  ref.invalidate(dashboardSummaryProvider);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: long ? 10 : 4),
      ),
    );
}

/// Message d'erreur lisible pour une action de catalogue.
///
/// Les erreurs PostgREST brutes (`PostgrestException(message: …, code: 42P01)`)
/// ne disent rien à un administrateur. On traduit les codes qui correspondent à
/// un état de base connu — table supprimée, droits perdus, colonne manquante —
/// en pointant vers le script de réparation.
String _catalogErrorText(Object error) {
  if (error is AppFailure) return error.message;

  final String raw = error.toString();
  String? hint;
  if (raw.contains('42P01') || raw.contains('could not find the table')) {
    hint = 'Table absente en base : jouez `supabase/repair_movies.sql` '
        '(SQL Editor), puis réessayez.';
  } else if (raw.contains('42501') ||
      raw.contains('row-level security') ||
      raw.contains('permission denied')) {
    hint = 'Droits refusés par la base : rejouez `supabase/repair_movies.sql` '
        '(il pose les GRANT et les droits par défaut), puis réessayez.';
  } else if (raw.contains('42703') || (raw.contains('column') && raw.contains('does not exist'))) {
    hint = 'Colonne manquante en base : rejouez `supabase/repair_movies.sql`.';
  } else if (raw.contains('23505')) {
    hint = 'Une fiche identique existe déjà (contrainte d’unicité).';
  } else if (raw.contains('23503')) {
    hint = 'Référence introuvable (catégorie ou contenu supprimé entre-temps) : '
        'rechargez l’écran puis réessayez.';
  } else if (raw.contains('PGRST301') || raw.contains('JWT')) {
    hint = 'Session expirée : reconnectez-vous.';
  }

  return hint == null ? raw : '$raw\n\n$hint';
}
