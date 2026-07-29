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
