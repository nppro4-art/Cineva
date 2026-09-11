import 'package:cineva_models/cineva_models.dart';
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

    test('finds the active skip segment at a position', () {
      const segments = <SkipSegment>[
        SkipSegment(startSeconds: 100, endSeconds: 130),
        SkipSegment(startSeconds: 400, endSeconds: 420),
      ];
      expect(
        PlayerRuntimePolicy.activeSkipSegment(positionSeconds: 99, segments: segments),
        isNull,
      );
      expect(
        PlayerRuntimePolicy.activeSkipSegment(positionSeconds: 110, segments: segments),
        const SkipSegment(startSeconds: 100, endSeconds: 130),
      );
      expect(
        PlayerRuntimePolicy.activeSkipSegment(positionSeconds: 410, segments: segments),
        const SkipSegment(startSeconds: 400, endSeconds: 420),
      );
      expect(
        PlayerRuntimePolicy.activeSkipSegment(positionSeconds: 420, segments: segments),
        isNull,
      );
    });

    test('resolveSeekTarget jumps to the end of a segment, then clamps', () {
      const segments = <SkipSegment>[SkipSegment(startSeconds: 100, endSeconds: 130)];
      expect(
        PlayerRuntimePolicy.resolveSeekTarget(
          targetSeconds: 110,
          durationSeconds: 1000,
          segments: segments,
        ),
        130,
      );
      expect(
        PlayerRuntimePolicy.resolveSeekTarget(
          targetSeconds: 500,
          durationSeconds: 1000,
          segments: segments,
        ),
        500,
      );
      expect(
        PlayerRuntimePolicy.resolveSeekTarget(
          targetSeconds: 5000,
          durationSeconds: 1000,
          segments: segments,
        ),
        1000,
      );
    });
  });
}
