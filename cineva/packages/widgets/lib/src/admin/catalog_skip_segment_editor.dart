part of 'catalog_screen.dart';

/// Ligne éditant un segment à passer (début / fin, en secondes).
class _SkipSegmentRow {
  _SkipSegmentRow({String start = '', String end = ''})
      : startController = TextEditingController(text: start),
        endController = TextEditingController(text: end);

  final TextEditingController startController;
  final TextEditingController endController;

  int? get start => int.tryParse(startController.text.trim());
  int? get end => int.tryParse(endController.text.trim());

  void dispose() {
    startController.dispose();
    endController.dispose();
  }
}

/// Conserve uniquement les segments valides (fin > début) et les trie par ordre.
List<SkipSegment> _skipSegmentsFromRows(List<_SkipSegmentRow> rows) {
  final segments = <SkipSegment>[
    for (final row in rows)
      SkipSegment(startSeconds: row.start ?? 0, endSeconds: row.end ?? 0),
  ]..removeWhere((segment) => !segment.isValid);
  segments.sort((a, b) => a.startSeconds.compareTo(b.startSeconds));
  return segments;
}

/// Éditeur de segments à passer (générique, publicité…) partagé par les
/// éditeurs film/série et épisode.
class _SkipSegmentEditor extends StatelessWidget {
  const _SkipSegmentEditor({
    required this.rows,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_SkipSegmentRow> rows;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var index = 0; index < rows.length; index += 1) ...<Widget>[
          if (index > 0) const SizedBox(height: CinevaSpacing.sm),
          Row(
            children: <Widget>[
              SizedBox(
                width: 104,
                child: TextField(
                  controller: rows[index].startController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Début (sec)'),
                ),
              ),
              const SizedBox(width: 8),
              const Text('→'),
              const SizedBox(width: 8),
              SizedBox(
                width: 104,
                child: TextField(
                  controller: rows[index].endController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Fin (sec)'),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Retirer ce segment',
                onPressed: () => onRemove(index),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ],
        const SizedBox(height: CinevaSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ajouter un segment à passer'),
          ),
        ),
      ],
    );
  }
}
