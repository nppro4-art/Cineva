import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_repositories/cineva_repositories.dart';
import 'package:cineva_services/cineva_services.dart';
import 'package:cineva_shared/cineva_shared.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/providers.dart';

/// Écran admin : colle une URL de site listant des films/séries, lance le
/// scraping (Edge Function) et importe la sélection dans le catalogue.
/// Gère aussi l'allowlist de domaines (sécurité / navigation sûre).
class ImportUrlScreen extends ConsumerStatefulWidget {
  const ImportUrlScreen({super.key});

  @override
  ConsumerState<ImportUrlScreen> createState() => _ImportUrlScreenState();
}

class _ImportUrlScreenState extends ConsumerState<ImportUrlScreen> {
  final _urlController = TextEditingController();
  final _domainsController = TextEditingController();
  bool _loading = false;
  String? _error;
  List<ImportedContentItem> _items = [];
  final Set<int> _selected = {};
  List<String> _allowedDomains = const <String>[];

  @override
  void initState() {
    super.initState();
    _loadAllowedDomains();
  }

  WebImportService _service() =>
      WebImportService(client: Supabase.instance.client);

  Future<void> _loadAllowedDomains() async {
    try {
      final domains = await _service().fetchAllowedDomains();
      if (mounted) {
        _allowedDomains = domains;
        _domainsController.text = domains.join(', ');
      }
    } catch (_) {
      // Non bloquant : l'allowlist reste vide (aucune restriction).
    }
  }

  Future<void> _saveDomains() async {
    final domains = _domainsController.text
        .split(RegExp(r'[,\n]'))
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    setState(() => _loading = true);
    try {
      await _service().saveAllowedDomains(domains);
      setState(() => _allowedDomains = domains);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Domaines autorisés enregistrés.')),
        );
      }
    } on AppFailure catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Erreur : $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _analyze() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
      _selected.clear();
    });
    try {
      final items = await _service().analyze(
        url,
        allowedDomains: _allowedDomains,
      );
      setState(() {
        _items = items;
        _selected.addAll(List<int>.generate(items.length, (i) => i));
      });
      if (items.isEmpty) {
        setState(() => _error =
            'Aucun élément détecté. Le site utilise peut-être une '
            'structure non reconnue : adapte les sélecteurs CSS.');
      }
    } on AppFailure catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Erreur : $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _import() async {
    final chosen = _selected.map((i) => _items[i]).toList();
    if (chosen.isEmpty) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final count = await _service().importItems(chosen, repo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$count élément(s) importé(s) dans le catalogue '
              '(fusion des doublons par qualité/langues).',
            ),
          ),
        );
        setState(() {
          _items = [];
          _selected.clear();
          _urlController.clear();
          _error = null;
        });
      }
    } on AppFailure catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Erreur : $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(CinevaSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Importer depuis une URL', style: theme.textTheme.titleLarge),
          const SizedBox(height: CinevaSpacing.sm),
          const Text(
            'Colle l’URL d’un site que tu maîtrises (source autorisée). '
            'L’app détecte les langues audio/sous-titres et la qualité, '
            'et fusionne les doublons en gardant le meilleur.',
          ),
          const SizedBox(height: CinevaSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: CinevaTextField(
                  controller: _urlController,
                  label: 'URL du site',
                  hint: 'https://un-site-autorise...',
                  onSubmitted: (_) => _analyze(),
                ),
              ),
              const SizedBox(width: CinevaSpacing.md),
              ElevatedButton(
                onPressed: _loading ? null : _analyze,
                child: const Text('Analyser'),
              ),
            ],
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: CinevaSpacing.md),
            CinevaStatusBanner(
              title: 'Erreur',
              message: _error!,
              tone: CinevaBannerTone.error,
            ),
          ],
          const SizedBox(height: CinevaSpacing.lg),
          _AllowlistCard(
            controller: _domainsController,
            onSave: _saveDomains,
            loading: _loading,
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(CinevaSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_items.isNotEmpty) ...<Widget>[
            const SizedBox(height: CinevaSpacing.lg),
            Row(
              children: <Widget>[
                Text('${_selected.length} / ${_items.length} sélectionné(s)'),
                const Spacer(),
                ElevatedButton(
                  onPressed: _loading ? null : _import,
                  child: const Text('Importer la sélection'),
                ),
              ],
            ),
            const SizedBox(height: CinevaSpacing.md),
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, i) {
                  final item = _items[i];
                  final selected = _selected.contains(i);
                  return CheckboxListTile(
                    value: selected,
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selected.add(i);
                      } else {
                        _selected.remove(i);
                      }
                    }),
                    title: Text(item.title),
                    subtitle: Text(_preview(item)),
                    secondary: item.posterPath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              item.posterPath!,
                              width: 48,
                              height: 72,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.movie_outlined),
                            ),
                          )
                        : const Icon(Icons.movie_outlined),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _preview(ImportedContentItem item) {
    final parts = <String>[
      if (item.releaseYear != null) item.releaseYear.toString(),
      if (item.quality != null) item.quality!,
      if (item.audioLanguages.isNotEmpty)
        'Audio: ${item.audioLanguages.join(', ')}',
      if (item.subtitleLanguages.isNotEmpty)
        'Sous-titres: ${item.subtitleLanguages.join(', ')}',
      item.contentType == 'series' ? 'Série' : 'Film',
    ];
    return parts.join('   •   ');
  }

  @override
  void dispose() {
    _urlController.dispose();
    _domainsController.dispose();
    super.dispose();
  }
}

class _AllowlistCard extends StatelessWidget {
  const _AllowlistCard({
    required this.controller,
    required this.onSave,
    required this.loading,
  });

  final TextEditingController controller;
  final VoidCallback onSave;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(CinevaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Domaines autorisés (sécurité)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: CinevaSpacing.sm),
            const Text(
              'Laisse vide pour tout autoriser. Sinon, seuls ces hôtes '
              '(ou leurs sous-domaines) pourront être scrapés.',
            ),
            const SizedBox(height: CinevaSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'ex: example.com, mon-site.fr',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: CinevaSpacing.md),
                ElevatedButton(
                  onPressed: loading ? null : onSave,
                  child: const Text('Enregistrer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
