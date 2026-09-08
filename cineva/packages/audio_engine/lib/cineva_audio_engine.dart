/// Cineva Audio Engine — API publique.
///
/// Chaîne de traitement audio temps réel :
/// ChannelMapper → Loudness → Dialogue → Bass → Spatial → EQ → DRC → Room
/// → Limiter (voir docs/06_audio_engine.md).
library;

export 'src/config/audio_engine_config.dart';
export 'src/config/param_layout.dart';
export 'src/dsp/dsp_pipeline.dart';
export 'dart:typed_data' show Float32List, Float64List;

export 'src/backends/audio_backend.dart';
export 'src/backends/web_audio_backend.dart';
export 'src/engine/audio_engine.dart';
export 'src/native/native_dsp.dart'
    show NativeDspCore, openCinevaDspLibrary;
