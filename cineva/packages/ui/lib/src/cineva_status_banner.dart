import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

enum CinevaBannerTone { info, warning, error, success }

class CinevaStatusBanner extends StatelessWidget {
  const CinevaStatusBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = CinevaBannerTone.info,
  });

  final String message;
  final String? title;
  final CinevaBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      CinevaBannerTone.info => CinevaColors.accentSoft,
      CinevaBannerTone.warning => CinevaColors.warning,
      CinevaBannerTone.error => CinevaColors.danger,
      CinevaBannerTone.success => CinevaColors.success,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CinevaSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(CinevaRadii.medium),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Text(title!, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color)),
            const SizedBox(height: 6),
          ],
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
