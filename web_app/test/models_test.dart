import 'package:flutter_test/flutter_test.dart';
import 'package:tingyu_web/models.dart';

void main() {
  test('timer formatting covers zero, rounding, hours and limits', () {
    expect(clockText(0), '00:00');
    expect(clockText(9.1), '00:10');
    expect(clockText(1800), '30:00');
    expect(clockText(3600), '01:00:00');
    expect(clockText(-1), '00:00');
    expect(clockText(999999), '12:00:00');
  });
  test('tracks are bounded, unique and validated', () {
    expect(validTracks(null), isEmpty);
    expect(
      validTracks([
        {'id': 'rain', 'volume': 200},
        {'id': 'rain', 'volume': 2},
        {'id': 'pink', 'volume': -5},
        {'id': 4, 'volume': 20},
      ]),
      [
        {'id': 'rain', 'volume': 100},
        {'id': 'pink', 'volume': 0},
      ],
    );
    expect(
      validTracks(List.generate(9, (i) => {'id': '$i', 'volume': 50})).length,
      6,
    );
  });
  test('scene sound IDs exist and all four scenarios are present', () {
    final ids = sounds.map((s) => s.id).toSet();
    expect(ids.length, sounds.length);
    expect(scenes.length, 4);
    for (final scene in scenes) {
      expect(scene.tracks.keys.every(ids.contains), isTrue);
      expect(scene.tracks.length, lessThanOrEqualTo(6));
    }
  });
}
