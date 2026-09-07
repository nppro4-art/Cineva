/// Stub natif — plateformes sans FFI (web). Retourne toujours null.
library;

DynamicLibrary? openCinevaDspLibrary() => null;

class NativeDspCore {
  NativeDspCore._();

  static NativeDspCore? create(double sampleRate) => null;
}
