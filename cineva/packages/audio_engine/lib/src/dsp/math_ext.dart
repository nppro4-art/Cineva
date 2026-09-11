/// Fonctions mathématiques absentes de `dart:math` avant Dart 3.9
/// (`tanh`) et jamais fournies (`log10`). Les implémentations sont
/// numériquement stables et suffisamment proches des versions C
/// (`tanhf`, `log10f`) pour tout usage audio.
library;

import 'dart:math' as math;

/// Tangente hyperbolique.
double tanh(double x) {
  if (x < -20.0) return -1.0;
  if (x > 20.0) return 1.0;
  final double e2x = math.exp(2.0 * x);
  return (e2x - 1.0) / (e2x + 1.0);
}

/// Logarithme décimal.
double log10(double x) => math.log(x) / math.ln10;
