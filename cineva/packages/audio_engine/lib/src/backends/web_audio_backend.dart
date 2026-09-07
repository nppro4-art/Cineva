/// Backend Web Audio — sélectionné conditionnellement.
///
/// Sur le web (JS et Wasm), `dart:js_interop` est disponible et la vraie
/// implémentation est utilisée ; ailleurs, le stub déclare le backend
/// indisponible (jamais de faux « traitement actif »).
library;

export 'web_audio_backend_stub.dart'
    if (dart.library.js_interop) 'web_audio_backend_web.dart';
