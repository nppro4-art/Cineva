import 'package:cineva_models/cineva_models.dart';

abstract final class PlayerRuntimePolicy {
  static bool shouldShowSkipIntro({
    required int positionSeconds,
    required int? introEndSeconds,
  }) {
    return introEndSeconds != null && positionSeconds > 3 && positionSeconds < introEndSeconds;
  }

  static bool shouldShowSkipCredits({
    required int positionSeconds,
    required int? creditsStartSeconds,
  }) {
    return creditsStartSeconds != null && positionSeconds >= creditsStartSeconds;
  }

  /// Segment actif à [positionSeconds] (premier qui contient la position),
  /// ou `null` si la position est hors de tout segment.
  static SkipSegment? activeSkipSegment({
    required int positionSeconds,
    required List<SkipSegment> segments,
  }) {
    for (final segment in segments) {
      if (segment.containsPosition(positionSeconds)) return segment;
    }
    return null;
  }

  /// Cible de seek « intelligente » : si la cible tombe dans un segment à
  /// passer, on atterrit à sa fin. C'est aussi ce qui évite de repartir
  /// dedans lors d'une reprise de lecture sauvegardée en cours de segment.
  static int resolveSeekTarget({
    required int targetSeconds,
    required int durationSeconds,
    required List<SkipSegment> segments,
  }) {
    final clamped = targetSeconds.clamp(0, durationSeconds).toInt();
    for (final segment in segments) {
      if (segment.containsPosition(clamped)) {
        return segment.endSeconds.clamp(0, durationSeconds).toInt();
      }
    }
    return clamped;
  }

  static bool shouldQueueNextEpisode({
    required int remainingSeconds,
    required String? nextContentId,
    required bool dismissed,
  }) {
    return !dismissed && nextContentId != null && remainingSeconds <= 10 && remainingSeconds > 0;
  }

  static int clampSeekTarget({
    required int currentSeconds,
    required int durationSeconds,
    required int deltaSeconds,
  }) {
    return (currentSeconds + deltaSeconds).clamp(0, durationSeconds).toInt();
  }
}
