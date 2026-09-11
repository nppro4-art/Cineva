/// Sélection de l'implémentation native selon la plateforme.
library;

export 'native_dsp_stub.dart'
    if (dart.library.io) 'native_dsp_io.dart';
