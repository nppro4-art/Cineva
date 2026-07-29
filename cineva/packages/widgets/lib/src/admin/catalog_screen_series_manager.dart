part of 'catalog_screen.dart';

Future<void> _showSeriesStructureManager(BuildContext context, WidgetRef ref, AdminCatalogItemModel series) async {
  final repository = ref.read(adminRepositoryProvider);
  final seasons = await repository.fetchSeasons(series.id);
  final episodesBySeason = <String, List<EpisodeModel>>{};
  for (final season in seasons) {
    episodesBySeason[season.id] = await repository.fetchEpisodes(season.id, seriesId: series.id, seasonNumber: season.seasonNumber);
  }

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> refresh() async {
            final refreshedSeasons = await repository.fetchSeasons(series.id);
            seasons
              ..clear()
              ..addAll(refreshedSeasons);
            episodesBySeason.clear();
            for (final season in seasons) {
              episodesBySeason[season.id] = await repository.fetchEpisodes(season.id, seriesId: series.id, seasonNumber: season.seasonNumber);
            }
            setState(() {});
          }

          Future<void> reorderEpisode(SeasonModel season, int oldIndex, int newIndex) async {
            final episodes = List<EpisodeModel>.from(episodesBySeason[season.id] ?? const <EpisodeModel>[]);
            if (oldIndex < 0 || newIndex < 0 || oldIndex >= episodes.length || newIndex >= episodes.length) return;
            final moved = episodes.removeAt(oldIndex);
            episodes.insert(newIndex, moved);
            for (var i = 0; i < episodes.length; i++) {
              await repository.saveEpisode(
                EpisodeModel(
                  id: episodes[i].id,
                  seriesId: episodes[i].seriesId,
                  seasonId: episodes[i].seasonId,
                  seasonNumber: episodes[i].seasonNumber,
                  episodeNumber: i + 1,
                  title: episodes[i].title,
                  synopsis: episodes[i].synopsis,
                  durationMinutes: episodes[i].durationMinutes,
                  videoUrl: episodes[i].videoUrl,
                  thumbnailPath: episodes[i].thumbnailPath,
                  audioLanguages: episodes[i].audioLanguages,
                  subtitleLanguages: episodes[i].subtitleLanguages,
                  rating: episodes[i].rating,
                  introEndSeconds: episodes[i].introEndSeconds,
                  creditsStartSeconds: episodes[i].creditsStartSeconds,
                  nextEpisodeId: episodes[i].nextEpisodeId,
                ),
              );
            }
            await refresh();
          }

          return AlertDialog(
            backgroundColor: CinevaColors.surface,
            title: Text('Structure — ${series.title}'),
            content: SizedBox(
              width: 860,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () async {
                          await _showSeasonEditor(context, ref, series.id);
                          await refresh();
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Ajouter une saison'),
                      ),
                    ),
                    const SizedBox(height: CinevaSpacing.md),
                    ...seasons.map(
                      (season) => Padding(
                        padding: const EdgeInsets.only(bottom: CinevaSpacing.lg),
                        child: CinevaGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(child: Text(season.title, style: Theme.of(context).textTheme.titleLarge)),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await _showSeasonEditor(context, ref, series.id, season: season);
                                      await refresh();
                                    },
                                    icon: const Icon(Icons.edit_rounded),
                                    label: const Text('Modifier'),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await _showEpisodeEditor(context, ref, series.id, season);
                                      await refresh();
                                    },
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('Ajouter un épisode'),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await _confirmDelete(
                                        context,
                                        title: 'Supprimer la saison',
                                        message: 'Supprimer ${season.title} et tous ses épisodes ?',
                                        onConfirm: () => _runCatalogAction(
                                          context,
                                          ref,
                                          () => repository.deleteSeason(season.id),
                                          successMessage: 'Saison supprimée.',
                                        ),
                                      );
                                      await refresh();
                                    },
                                    icon: const Icon(Icons.delete_outline_rounded),
                                    label: const Text('Supprimer'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: CinevaSpacing.sm),
                              if ((season.synopsis ?? '').isNotEmpty)
                                Text(season.synopsis!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted)),
                              const SizedBox(height: CinevaSpacing.md),
                              ...(episodesBySeason[season.id] ?? const <EpisodeModel>[]).map(
                                (episode) => Padding(
                                  padding: const EdgeInsets.only(bottom: CinevaSpacing.sm),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: CinevaColors.surfaceRaised,
                                      borderRadius: BorderRadius.circular(CinevaRadii.small),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(CinevaSpacing.md),
                                      child: Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Text('${episode.label} — ${episode.title}', style: Theme.of(context).textTheme.titleMedium),
                                                const SizedBox(height: 4),
                                                Text('${episode.durationMinutes} min', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted)),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () => reorderEpisode(season, episode.episodeNumber - 1, (episode.episodeNumber - 2).clamp(0, 999)),
                                            icon: const Icon(Icons.arrow_upward_rounded),
                                            tooltip: 'Monter',
                                          ),
                                          IconButton(
                                            onPressed: () => reorderEpisode(season, episode.episodeNumber - 1, episode.episodeNumber),
                                            icon: const Icon(Icons.arrow_downward_rounded),
                                            tooltip: 'Descendre',
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              final updatedSeries = series.copyWith(pilotEpisodeId: episode.id);
                                              await _runCatalogAction(
                                                context,
                                                ref,
                                                () => repository.saveSeries(updatedSeries),
                                                successMessage: 'Épisode pilote défini.',
                                              );
                                            },
                                            child: Text(series.pilotEpisodeId == episode.id ? 'Pilote' : 'Définir pilote'),
                                          ),
                                          IconButton(
                                            tooltip: 'Modifier ${episode.title}',
                                            onPressed: () async {
                                              await _showEpisodeEditor(context, ref, series.id, season, episode: episode);
                                              await refresh();
                                            },
                                            icon: const Icon(Icons.edit_rounded),
                                          ),
                                          IconButton(
                                            tooltip: 'Supprimer ${episode.title}',
                                            onPressed: () async {
                                              await _confirmDelete(
                                                context,
                                                title: 'Supprimer l’épisode',
                                                message: 'Supprimer ${episode.title} ?',
                                                onConfirm: () => _runCatalogAction(
                                                  context,
                                                  ref,
                                                  () => repository.deleteEpisode(episode.id),
                                                  successMessage: 'Épisode supprimé.',
                                                ),
                                              );
                                              await refresh();
                                            },
                                            icon: const Icon(Icons.delete_outline_rounded),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Fermer')),
            ],
          );
        },
      );
    },
  );
}
