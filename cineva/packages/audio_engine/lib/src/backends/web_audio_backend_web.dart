/// Backend Web Audio (web) — branche le Cineva Audio Engine dans le graphe
/// Web Audio de la page via un AudioWorklet.
///
/// Implémentation 100 % `dart:js_interop` (bibliothèque cœur, aucune
/// dépendance externe). Le pipeline DSP complet vit dans
/// `assets/js/cineva_audio_worklet.js` (miroir exact du cœur C) :
///  - chargé par `audioWorklet.addModule` → processeur
///    'cineva-audio-processor' ;
///  - chargé par `<script>` en mode glue → `globalThis.__cinevaAudioEngine`.
///
/// Ce backend injecte d'abord le <script> glue (URLs candidates), puis
/// délègue : attach (MediaElementSource sur le <video> actif), setParams
/// (tableau de 128 doubles), detach, métriques.
library;

import 'dart:async';

import 'dart:js_interop';

import 'audio_backend.dart';

/// URLs candidates du worklet (ordre : asset de package bundlé par Flutter
/// web, variantes, puis même dossier que la page).
const List<String> kWorkletAssetUrls = <String>[
  'assets/packages/cineva_audio_engine/assets/js/cineva_audio_worklet.js',
  'packages/cineva_audio_engine/assets/js/cineva_audio_worklet.js',
  'assets/assets/js/cineva_audio_worklet.js',
  'assets/js/cineva_audio_worklet.js',
  'cineva_audio_worklet.js',
];

/// Backend Web Audio pour le web (JS et Wasm).
class WebAudioBackend implements CinevaAudioBackend {
  bool _attached = false;
  String? _lastError;

  static bool get _hasWebAudio =>
      globalContext.hasProperty('AudioContext'.toJS).toDart ||
      globalContext.hasProperty('webkitAudioContext'.toJS).toDart;

  JSObject? get _engine {
    final JSAny? any = globalContext.getProperty<JSAny?>('__cinevaAudioEngine'.toJS);
    if (any == null || !any.isA<JSObject>()) return null;
    return any as JSObject;
  }

  @override
  AudioBackendCapabilities get capabilities => AudioBackendCapabilities(
        available: _hasWebAudio,
        label: 'Web Audio (AudioWorklet)',
        detail: _lastError,
        supportsMultichannel: false,
        supportsAbCompare: true,
      );

  @override
  bool get isAttached => _attached;

  /// Injecte le script glue si nécessaire et attend qu'il soit chargé.
  Future<bool> _ensureEngineLoaded() async {
    if (_engine != null) return true;
    for (final String url in kWorkletAssetUrls) {
      if (await _injectScript(url) && _engine != null) return true;
    }
    _lastError = 'worklet JS introuvable';
    return false;
  }

  Future<bool> _injectScript(String src) {
    final JSAny? docAny = globalContext.getProperty<JSAny?>('document'.toJS);
    if (docAny == null || !docAny.isA<JSObject>()) {
      _lastError = 'document indisponible';
      return Future<bool>.value(false);
    }
    final JSObject document = docAny as JSObject;
    final JSObject script =
        document.callMethod<JSObject>('createElement'.toJS, 'script'.toJS);
    script.setProperty('src'.toJS, src.toJS);
    script.setProperty('type'.toJS, 'text/javascript'.toJS);

    final Completer<bool> completer = Completer<bool>();
    script.setProperty<JSFunction>(
      'onload'.toJS,
      (() {
        if (!completer.isCompleted) completer.complete(true);
      }).toJS,
    );
    script.setProperty<JSFunction>(
      'onerror'.toJS,
      (() {
        if (!completer.isCompleted) completer.complete(false);
      }).toJS,
    );
    document.getProperty<JSObject>('head'.toJS).callMethod<JSVoid>(
          'appendChild'.toJS,
          script,
        );
    return completer.future;
  }

  @override
  Future<bool> attach() async {
    if (_attached) return true;
    if (!_hasWebAudio) {
      _lastError = 'Web Audio indisponible sur ce navigateur';
      return false;
    }
    if (!await _ensureEngineLoaded()) return false;
    final JSObject? engine = _engine;
    if (engine == null) {
      _lastError = 'glue __cinevaAudioEngine absente';
      return false;
    }
    try {
      final Future<JSBoolean> pending =
          engine.callMethod<JSPromise<JSBoolean>>('attach'.toJS).toDart;
      _attached = (await pending).toDart;
    } catch (e) {
      _lastError = 'attach échoué : $e';
      _attached = false;
    }
    if (_attached) _lastError = null;
    return _attached;
  }

  @override
  Future<void> detach() async {
    final JSObject? engine = _engine;
    if (engine != null) {
      try {
        engine.callMethod<JSVoid>('detach'.toJS);
      } catch (_) {
        // déjà détaché
      }
    }
    _attached = false;
  }

  @override
  void setParams(List<double> params) {
    final JSObject? engine = _engine;
    if (engine == null) return;
    final JSArray<JSNumber> jsParams =
        params.map((double v) => v.toJS).toList().toJS;
    try {
      // La glue bufferise : les params sont appliqués dès l'attach si
      // le nœud worklet n'existe pas encore.
      engine.callMethod<JSVoid>('setParams'.toJS, jsParams);
    } catch (_) {
      // glue disparue entre-temps
    }
  }

  // ── Extensions web (hors interface) ──────────────────────────────────

  /// Demande un refresh des métriques au worklet (réponse asynchrone).
  void requestMetrics() {
    final JSObject? engine = _engine;
    if (engine == null || !_attached) return;
    try {
      engine.callMethod<JSVoid>('requestMetrics'.toJS);
    } catch (_) {
      // nœud disparu
    }
  }

  /// Dernières métriques reçues (16 doubles, cf. DspMetric).
  List<double> getMetrics() {
    final JSObject? engine = _engine;
    if (engine == null) return const <double>[];
    try {
      final JSArray<JSNumber> arr =
          engine.callMethod<JSArray<JSNumber>>('getMetrics'.toJS);
      return arr.toDart.map((JSNumber v) => v.toDart).toList();
    } catch (_) {
      return const <double>[];
    }
  }

  /// État brut de la glue { attached, error, sampleRate }.
  Map<String, Object?> getStatus() {
    final JSObject? engine = _engine;
    if (engine == null) return const <String, Object>{};
    try {
      final JSObject status = engine.callMethod<JSObject>('getStatus'.toJS);
      final JSAny? err = status.getProperty<JSAny?>('error'.toJS);
      final JSAny? sr = status.getProperty<JSAny?>('sampleRate'.toJS);
      return <String, Object?>{
        'attached': status.getProperty<JSBoolean>('attached'.toJS).toDart,
        'error': (err != null && err.isA<JSString>()) ? (err as JSString).toDart : null,
        'sampleRate': (sr != null && sr.isA<JSNumber>()) ? (sr as JSNumber).toDart : 0,
      };
    } catch (_) {
      return const <String, Object>{};
    }
  }
}
