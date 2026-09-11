import 'package:cineva_models/cineva_models.dart';
import 'package:test/test.dart';

void main() {
  test('SkipSegment.fromJson parses list payloads', () {
    final segment = SkipSegment.fromJson(<Object>[120, 180]);
    expect(segment.startSeconds, 120);
    expect(segment.endSeconds, 180);
    expect(segment.isValid, isTrue);
  });

  test('SkipSegment.fromJson parses map payloads', () {
    final segment = SkipSegment.fromJson(<String, dynamic>{'start': 120, 'end': 180});
    expect(segment.startSeconds, 120);
    expect(segment.endSeconds, 180);

    final typed = SkipSegment.fromJson(<String, dynamic>{
      'startSeconds': '30',
      'endSeconds': 90,
    });
    expect(typed.isValid, isTrue);
    expect(typed.durationSeconds, 60);
  });

  test('SkipSegment.fromJson degrades to an invalid segment on garbage', () {
    expect(SkipSegment.fromJson('pas un segment').isValid, isFalse);
    expect(SkipSegment.fromJson(<Object>[10]).isValid, isFalse);
  });

  test('SkipSegment rejects inverted or empty segments', () {
    expect(const SkipSegment(startSeconds: 10, endSeconds: 10).isValid, isFalse);
    expect(const SkipSegment(startSeconds: 20, endSeconds: 10).isValid, isFalse);
    expect(const SkipSegment(startSeconds: -1, endSeconds: 10).isValid, isFalse);
  });

  test('SkipSegment.containsPosition uses [start, end)', () {
    const segment = SkipSegment(startSeconds: 100, endSeconds: 130);
    expect(segment.containsPosition(99), isFalse);
    expect(segment.containsPosition(100), isTrue);
    expect(segment.containsPosition(129), isTrue);
    expect(segment.containsPosition(130), isFalse);
  });

  test('SkipSegment round-trips through json and list forms', () {
    const segment = SkipSegment(startSeconds: 5, endSeconds: 15);
    expect(SkipSegment.fromJson(segment.toJson()).props, segment.props);
    expect(SkipSegment.fromJson(segment.toList()).props, segment.props);
  });
}
