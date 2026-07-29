import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

class CinevaVisionLayer extends StatelessWidget {
  const CinevaVisionLayer({
    super.key,
    required this.renderProfile,
    required this.child,
  });

  final CinevaVisionRenderProfile renderProfile;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(_matrix()),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          child,
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color.lerp(Colors.transparent, const Color(0xFFF59E0B), renderProfile.warmth.abs())!,
                    Colors.transparent,
                    Colors.black.withOpacity(renderProfile.shadowBoost.clamp(0, 0.18)),
                  ],
                  stops: const <double>[0.0, 0.48, 1.0],
                ),
              ),
            ),
          ),
          if (renderProfile.overlayOpacity > 0)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: CinevaColors.accentSoft.withOpacity(renderProfile.overlayOpacity * 0.45),
                    width: 1.2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.white.withOpacity(renderProfile.overlayOpacity * 0.12),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<double> _matrix() {
    final c = renderProfile.contrast;
    final s = renderProfile.saturation;
    final b = renderProfile.brightness * 255;
    final warm = renderProfile.warmth;
    final invSat = 1 - s;
    final r = 0.2126 * invSat;
    final g = 0.7152 * invSat;
    final bl = 0.0722 * invSat;

    final redScale = c + warm * 0.08;
    final blueScale = c - warm * 0.08;

    return <double>[
      (r + s) * redScale, g * redScale, bl * redScale, 0, b,
      r * c, (g + s) * c, bl * c, 0, b,
      r * blueScale, g * blueScale, (bl + s) * blueScale, 0, b,
      0, 0, 0, 1, 0,
    ];
  }
}
