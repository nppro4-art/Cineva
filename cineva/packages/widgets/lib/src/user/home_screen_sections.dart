part of 'home_screen.dart';

/// Hero de l'accueil, branché sur la section `hero` du catalogue.
class _HomeHero extends ConsumerWidget {
  const _HomeHero({
    required this.section,
    required this.scrollController,
    required this.myListIds,
  });

  final HomeSectionModel section;
  final ScrollController scrollController;
  final Set<String> myListIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CinevaMetrics metrics = CinevaMetrics.of(context);
    final List<ContentTileModel> items = section.items;

    return CinevaHero(
      items: items,
      height: metrics.heroHeight,
      overline: section.title,
      myListIds: myListIds,
      parallaxController: scrollController,
      onPlay: (ContentTileModel item) =>
          context.push('/player/${Uri.encodeComponent(item.id)}'),
      onOpen: (ContentTileModel item) =>
          context.push('/content/${Uri.encodeComponent(item.id)}'),
      onToggleMyList: (ContentTileModel item) => _toggleMyList(context, ref, item),
    );
  }
}

/// Rail standard : affiches 2:3 + titre + métadonnées.
class HomeRail extends ConsumerWidget {
  const HomeRail({super.key, required this.section, required this.myListIds});

  final HomeSectionModel section;
  final Set<String> myListIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CinevaMetrics metrics = CinevaMetrics.of(context);
    final double posterWidth = metrics.posterWidth;
    final List<ContentTileModel> items = section.items;

    return CinevaRail(
      title: section.title,
      itemHeight: (posterWidth * 1.5) + 46,
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final ContentTileModel item = items[index];
        return CinevaMovieCard(
          item: item,
          width: posterWidth,
          onTap: () => context.push('/content/${Uri.encodeComponent(item.id)}'),
          onLongPress: () => showHomeQuickActions(
            context: context,
            ref: ref,
            item: item,
            myListIds: myListIds,
          ),
        );
      },
    );
  }
}

/// Rail « Continuer à regarder » : backdrops 16:9 + barre de reprise.
/// Un appui reprend exactement là où l'utilisateur s'est arrêté.
class HomeContinueRail extends ConsumerWidget {
  const HomeContinueRail({super.key, required this.progress});

  final List<PlaybackProgressModel> progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CinevaMetrics metrics = CinevaMetrics.of(context);
    final double cardWidth = metrics.continueWidth;

    return CinevaRail(
      title: 'Continuer à regarder',
      overline: 'Reprise instantanée',
      itemHeight: (cardWidth * 9 / 16) + 56,
      itemCount: progress.length,
      itemBuilder: (BuildContext context, int index) {
        final PlaybackProgressModel entry = progress[index];
        return CinevaContinueCard(
          item: entry.content,
          width: cardWidth,
          progress: entry,
          onTap: () =>
              context.push('/player/${Uri.encodeComponent(entry.content.id)}'),
          onLongPress: () => showHomeQuickActions(
            context: context,
            ref: ref,
            item: entry.content,
            myListIds: ref.read(libraryControllerProvider).favoriteIds,
          ),
        );
      },
    );
  }
}

/// « Reprendre la lecture » si le contenu est commencé mais pas terminé.
String _resumeLabel(ContentTileModel item) {
  final double percent = item.progressPercent ?? 0;
  return percent > 0.02 && percent < 0.97 ? 'Reprendre la lecture' : 'Regarder';
}

/// Ajoute/retire de « Ma liste » avec un retour visuel court.
Future<void> _toggleMyList(
  BuildContext context,
  WidgetRef ref,
  ContentTileModel item,
) async {
  final LibraryController controller = ref.read(libraryControllerProvider.notifier);
  final bool wasFavorite = ref.read(libraryControllerProvider).isFavorite(item.id);
  await controller.toggleFavorite(item);
  if (!context.mounted) return;
  final bool nowFavorite = ref.read(libraryControllerProvider).isFavorite(item.id);
  if (nowFavorite == wasFavorite) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1800),
        content: Text(nowFavorite ? 'Ajouté à Ma liste' : 'Retiré de Ma liste'),
      ),
    );
}

/// Actions rapides au maintien d'une affiche.
Future<void> showHomeQuickActions({
  required BuildContext context,
  required WidgetRef ref,
  required ContentTileModel item,
  required Set<String> myListIds,
}) {
  final bool inList = myListIds.contains(item.id);
  final DownloadItemModel? download =
      ref.read(libraryControllerProvider).downloadFor(item.id);
  final NavigatorState navigator = Navigator.of(context);

  return showCinevaSheet<void>(
    context: context,
    builder: (BuildContext sheetContext) => CinevaSheetContainer(
      title: item.title,
      subtitle: CinevaContentLabels.meta(item),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CinevaSheetAction(
              icon: Icons.play_arrow_rounded,
              label: _resumeLabel(item),
              onTap: () {
                navigator.pop();
                context.push('/player/${Uri.encodeComponent(item.id)}');
              },
            ),
            CinevaSheetAction(
              icon: inList ? Icons.check_rounded : Icons.add_rounded,
              label: inList ? 'Retirer de Ma liste' : 'Ajouter à Ma liste',
              tone: inList ? CinevaButtonTone.gold : CinevaButtonTone.neutral,
              onTap: () {
                navigator.pop();
                _toggleMyList(context, ref, item);
              },
            ),
            CinevaSheetAction(
              icon: ContentDetailHelpers.downloadIcon(download),
              label: ContentDetailHelpers.downloadLabel(download),
              onTap: () {
                navigator.pop();
                _handleDownloadFromTile(context, ref, item, download);
              },
            ),
            CinevaSheetAction(
              icon: Icons.info_outline_rounded,
              label: 'Plus d’informations',
              onTap: () {
                navigator.pop();
                context.push('/content/${Uri.encodeComponent(item.id)}');
              },
            ),
            const SizedBox(height: CinevaSpacing.sm),
          ],
        ),
      ),
    ),
  );
}

/// Téléchargement réel : récupère la fiche (flux, taille, qualité) puis
/// met en file / reprend / supprime selon l'état courant.
Future<void> _handleDownloadFromTile(
  BuildContext context,
  WidgetRef ref,
  ContentTileModel item,
  DownloadItemModel? current,
) async {
  final LibraryController controller = ref.read(libraryControllerProvider.notifier);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

  if (current != null) {
    if (current.isDownloading) {
      await controller.pauseDownload(item.id);
      return;
    }
    if (current.isCompleted) {
      final bool confirmed = await CinevaDialog.show(
        context,
        title: 'Supprimer le téléchargement',
        message: '« ${item.title} » ne sera plus disponible hors ligne.',
        confirmLabel: 'Supprimer',
        cancelLabel: 'Conserver',
        icon: Icons.delete_outline_rounded,
        destructive: true,
      );
      if (confirmed) await controller.removeDownload(item.id);
      return;
    }
    await controller.resumeDownload(item.id);
    return;
  }

  messenger.showSnackBar(
    const SnackBar(duration: Duration(milliseconds: 1400), content: Text('Préparation du téléchargement…')),
  );
  final ContentDetailModel? detail =
      await ref.read(contentDetailProvider(item.id).future);
  if (detail == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Fiche indisponible : téléchargement impossible.')),
    );
    return;
  }
  await controller.enqueueDownload(detail);
  final String? error = ref.read(libraryControllerProvider).errorMessage;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(error ?? 'Téléchargement ajouté à la file.'),
      ),
    );
}
