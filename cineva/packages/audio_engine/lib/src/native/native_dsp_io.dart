/// Bindings FFI du cœur C `libcineva_dsp` — implémentation native (IO).
///
/// La bibliothèque est recherchée dans cet ordre :
///   1. variable d'environnement `CINEVA_DSP_LIB` (tests/outils) ;
///   2. `libcineva_dsp.so` / `libcineva_dsp.dylib` / `cineva_dsp.dll`.
library;

import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart' as ffi;

typedef _CreateC = Pointer<Void> Function(Double);
typedef _CreateDart = Pointer<Void> Function(double);
typedef _DestroyC = Void Function(Pointer<Void>);
typedef _DestroyDart = void Function(Pointer<Void>);
typedef _SetParamsC = Int32 Function(Pointer<Void>, Pointer<Double>, Int32);
typedef _SetParamsDart = int Function(Pointer<Void>, Pointer<Double>, int);
typedef _GetParamsC = Int32 Function(Pointer<Void>, Pointer<Double>, Int32);
typedef _GetParamsDart = int Function(Pointer<Void>, Pointer<Double>, int);
typedef _ProcessC = Int32 Function(Pointer<Void>, Pointer<Pointer<Float>>, Int32,
    Pointer<Pointer<Float>>, Int32, Int32);
typedef _ProcessDart = int Function(Pointer<Void>, Pointer<Pointer<Float>>, int,
    Pointer<Pointer<Float>>, int, int);
typedef _ResetC = Int32 Function(Pointer<Void>);
typedef _ResetDart = int Function(Pointer<Void>);
typedef _GetMetricsC = Int32 Function(Pointer<Void>, Pointer<Double>, Int32);
typedef _GetMetricsDart = int Function(Pointer<Void>, Pointer<Double>, int);
typedef _VersionC = Pointer<Uint8> Function();
typedef _VersionDart = Pointer<Uint8> Function();

/// Localise la bibliothèque native, ou retourne null si indisponible.
DynamicLibrary? openCinevaDspLibrary() {
  try {
    final String? env = Platform.environment['CINEVA_DSP_LIB'];
    if (env != null && env.isNotEmpty) {
      return DynamicLibrary.open(env);
    }
    const List<String> candidates = <String>[
      'libcineva_dsp.so',
      'libcineva_dsp.dylib',
      'cineva_dsp.dll',
    ];
    for (final String name in candidates) {
      try {
        return DynamicLibrary.open(name);
      } catch (_) {
        // essayer le suivant
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

/// Wrapper Dart du cœur C. Toutes les méthodes copient les données vers/depuis
/// des tampons natifs : sûr et simple. Retourne null si la lib est absente.
class NativeDspCore {
  NativeDspCore._(this._lib, this._handle);

  final DynamicLibrary _lib;
  final Pointer<Void> _handle;

  static NativeDspCore? create(double sampleRate) {
    final DynamicLibrary? lib = openCinevaDspLibrary();
    if (lib == null) return null;
    final _CreateDart create =
        lib.lookupFunction<_CreateC, _CreateDart>('cineva_dsp_create');
    final Pointer<Void> handle = create(sampleRate);
    if (handle == nullptr) return null;
    return NativeDspCore._(lib, handle);
  }

  int setParams(Float64List values) {
    final _SetParamsDart fn =
        _lib.lookupFunction<_SetParamsC, _SetParamsDart>('cineva_dsp_set_params');
    final ffi.Pointer<Double> ptr = ffi.malloc<Double>(values.length);
    try {
      ptr.asTypedList(values.length).setAll(0, values);
      return fn(_handle, ptr, values.length);
    } finally {
      ffi.malloc.free(ptr);
    }
  }

  Float64List getParams() {
    final _GetParamsDart fn =
        _lib.lookupFunction<_GetParamsC, _GetParamsDart>('cineva_dsp_get_params');
    final ffi.Pointer<Double> ptr = ffi.malloc<Double>(128);
    try {
      fn(_handle, ptr, 128);
      return Float64List.fromList(ptr.asTypedList(128));
    } finally {
      ffi.malloc.free(ptr);
    }
  }

  /// Traite un bloc en copiant vers des tampons natifs.
  int process(
    List<Float32List> input,
    int inChannels,
    List<Float32List> output,
    int outChannels,
    int frames,
  ) {
    final _ProcessDart fn =
        _lib.lookupFunction<_ProcessC, _ProcessDart>('cineva_dsp_process');
    final ffi.Pointer<Pointer<Float>> inPtrs =
        ffi.malloc<Pointer<Float>>(inChannels);
    final ffi.Pointer<Pointer<Float>> outPtrs =
        ffi.malloc<Pointer<Float>>(outChannels);
    final List<ffi.Pointer<Float>> inBufs = <ffi.Pointer<Float>>[];
    final List<ffi.Pointer<Float>> outBufs = <ffi.Pointer<Float>>[];
    try {
      for (int ch = 0; ch < inChannels; ch++) {
        final ffi.Pointer<Float> buf = ffi.malloc<Float>(frames);
        inBufs.add(buf);
        buf.asTypedList(frames).setAll(0, input[ch].sublist(0, frames));
        inPtrs[ch] = buf;
      }
      for (int ch = 0; ch < outChannels; ch++) {
        final ffi.Pointer<Float> buf = ffi.malloc<Float>(frames);
        outBufs.add(buf);
        outPtrs[ch] = buf;
      }
      final int result =
          fn(_handle, inPtrs, inChannels, outPtrs, outChannels, frames);
      for (int ch = 0; ch < outChannels; ch++) {
        final Float32List view = outBufs[ch].asTypedList(frames);
        for (int i = 0; i < frames; i++) {
          output[ch][i] = view[i];
        }
      }
      return result;
    } finally {
      for (final ffi.Pointer<Float> buf in inBufs) {
        ffi.malloc.free(buf);
      }
      for (final ffi.Pointer<Float> buf in outBufs) {
        ffi.malloc.free(buf);
      }
      ffi.malloc.free(inPtrs);
      ffi.malloc.free(outPtrs);
    }
  }

  int reset() {
    final _ResetDart fn =
        _lib.lookupFunction<_ResetC, _ResetDart>('cineva_dsp_reset');
    return fn(_handle);
  }

  Float64List getMetrics() {
    final _GetMetricsDart fn =
        _lib.lookupFunction<_GetMetricsC, _GetMetricsDart>('cineva_dsp_get_metrics');
    final ffi.Pointer<Double> ptr = ffi.malloc<Double>(16);
    try {
      fn(_handle, ptr, 16);
      return Float64List.fromList(ptr.asTypedList(16));
    } finally {
      ffi.malloc.free(ptr);
    }
  }

  String version() {
    final _VersionDart fn =
        _lib.lookupFunction<_VersionC, _VersionDart>('cineva_dsp_version');
    final Pointer<Uint8> ptr = fn();
    return ptr.cast<ffi.Utf8>().toDartString();
  }

  void destroy() {
    final _DestroyDart fn =
        _lib.lookupFunction<_DestroyC, _DestroyDart>('cineva_dsp_destroy');
    fn(_handle);
  }
}
