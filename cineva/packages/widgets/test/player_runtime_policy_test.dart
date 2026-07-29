import 'package:cineva_widgets/src/player/player_runtime_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlayerRuntimePolicy', () {
    test('shows skip intro only within intro window', () {
      expect(
        PlayerRuntimePolicy.shouldShowSkipIntro(
          positionSeconds: 8,
          introEndSeconds: 60,
        ),
        isTrue,
      );
      expect(
        PlayerRuntimePolicy.shouldShowSkipIntro(
          positionSeconds: 61,
          introEndSeconds: 60,
        ),
        isFalse,
      );
    });

    test('shows skip credits after threshold', () {
      expect(
        PlayerRuntimePolicy.shouldShowSkipCredits(
          positionSeconds: 1500,
          creditsStartSeconds: 1490,
        ),
        isTrue,
      );
    });

    test('queues next episode only in final countdown', () {
      expect(
        PlayerRuntimePolicy.shouldQueueNextEpisode(
          remainingSeconds: 8,
          nextContentId: 'ep_2',
          dismissed: false,
        ),
        isTrue,
      );
      expect(
        PlayerRuntimePolicy.shouldQueueNextEpisode(
          remainingSeconds: 0,
          nextContentId: 'ep_2',
          dismissed: false,
        ),
        isFalse,
      );
    });

    test('clamps seek target within duration', () {
      expect(
        PlayerRuntimePolicy.clampSeekTarget(
          currentSeconds: 100,
          durationSeconds: 120,
          deltaSeconds: 40,
        ),
        120,
      );
      expect(
        PlayerRuntimePolicy.clampSeekTarget(
          currentSeconds: 10,
          durationSeconds: 120,
          deltaSeconds: -40,
        ),
        0,
      );
    });
  });
}
