/// Stub natif — plateformes sans FFI (web). Retourne toujours null / no-op.
library;

import 'dart:typed_data';

/// Sur le web `dart:ffi` n'existe pas : le type de retour est volontairement
/// `Object?` — aucun consommateur n'ouvre réellement la bibliothèque hors du
/// mode IO (le backend natif est alors simplement indisponible).
Object? openCinevaDspLibrary() => null;

/// Surface identique à [NativeDspCore] du mode IO, en no-op : le moteur
/// retombe toujours sur le cœur Dart (ou le worklet web).
class NativeDspCore {
  NativeDspCore._();

  static NativeDspCore? create(double sampleRate) => null;

  int setParams(Float64List values) => -1;

  Float64List getParams() => Float64List(128);

  int process(
    List<Float32List> input,
    int inChannels,
    List<Float32List> output,
    int outChannels,
    int frames,
  ) => -1;

  int reset() => -1;

  Float64List getMetrics() => Float64List(16);

  void destroy() {}
}
