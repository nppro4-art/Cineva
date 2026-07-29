part of 'catalog_screen.dart';

class _MediaPickerCard extends StatelessWidget {
  const _MediaPickerCard({
    required this.label,
    required this.bytes,
    required this.existingPath,
    required this.filename,
    required this.onPick,
  });

  final String label;
  final Uint8List? bytes;
  final String? existingPath;
  final String? filename;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return CinevaGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: CinevaSpacing.sm),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: CinevaColors.surfaceRaised,
                borderRadius: BorderRadius.circular(CinevaRadii.medium),
                border: Border.all(color: CinevaColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: bytes != null
                  ? Image.memory(bytes!, fit: BoxFit.cover)
                  : Center(
                      child: Text(
                        existingPath ?? 'Aucun média sélectionné',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CinevaColors.textMuted),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: CinevaSpacing.sm),
          FilledButton.tonalIcon(
            onPressed: onPick,
            icon: const Icon(Icons.upload_rounded),
            label: Text(filename ?? 'Choisir un fichier'),
          ),
        ],
      ),
    );
  }
}

List<String> _splitCommaValues(String raw) {
  return raw
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();
}

String _inferContentType(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}
