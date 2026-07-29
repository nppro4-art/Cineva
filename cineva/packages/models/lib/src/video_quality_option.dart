import 'package:equatable/equatable.dart';

enum VideoQualityPreset {
  auto,
  p480,
  p720,
  p1080,
  p1440,
  p4k,
}

extension VideoQualityPresetX on VideoQualityPreset {
  String get label => switch (this) {
        VideoQualityPreset.auto => 'Auto',
        VideoQualityPreset.p480 => '480p',
        VideoQualityPreset.p720 => '720p',
        VideoQualityPreset.p1080 => '1080p',
        VideoQualityPreset.p1440 => '1440p',
        VideoQualityPreset.p4k => '4K',
      };
}

class VideoQualityOption extends Equatable {
  const VideoQualityOption({
    required this.preset,
    required this.bitrateMbps,
    required this.resolutionLabel,
    required this.hdr,
    required this.dolbyVision,
    required this.dolbyAtmos,
    this.available = true,
    this.streamUrl,
    this.mimeType,
  });

  final VideoQualityPreset preset;
  final double bitrateMbps;
  final String resolutionLabel;
  final bool hdr;
  final bool dolbyVision;
  final bool dolbyAtmos;
  final bool available;
  final String? streamUrl;
  final String? mimeType;

  bool get hasDedicatedStream => streamUrl != null && streamUrl!.isNotEmpty;

  @override
  List<Object?> get props => <Object?>[
        preset,
        bitrateMbps,
        resolutionLabel,
        hdr,
        dolbyVision,
        dolbyAtmos,
        available,
        streamUrl,
        mimeType,
      ];
}
