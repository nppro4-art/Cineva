import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

import 'user/cineva_artwork.dart';

class CinevaPosterCard extends StatelessWidget {
  const CinevaPosterCard({
    super.key,
    required this.item,
    this.width = 156,
    this.onTap,
  });

  final ContentTileModel item;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(CinevaRadii.medium),
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Hero(
                tag: 'poster-${item.id}',
                child: CinevaArtwork(
                  content: item,
                  showTypeBadge: true,
                  child: Padding(
                    padding: const EdgeInsets.all(CinevaSpacing.md),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (item.year != null || item.durationMinutes != null)
                            Text(
                              [
                                if (item.year != null) '${item.year}',
                                if (item.durationMinutes != null) '${item.durationMinutes} min',
                              ].join(' • '),
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            item.contentType == 'movie' ? 'Film premium' : 'Série premium',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: CinevaColors.textPrimary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: CinevaSpacing.sm),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              item.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CinevaColors.textMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
