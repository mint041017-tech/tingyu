import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tingyu_web/audio/nook_controller.dart';
import 'package:tingyu_web/models.dart';
import 'package:tingyu_web/platform/pomodoro_platform.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native audio, timer and chime pipeline', (tester) async {
    final controller = NookController();
    await controller.bootstrap();
    await controller.initialize();
    expect(controller.ready, isTrue);
    expect(controller.error, isNull);
    for (final sound in sounds) {
      final source = await SoLoud.instance.loadAsset(
        'assets/audio/builtin/${sound.id}.flac',
      );
      expect(
        SoLoud.instance.getLength(source),
        greaterThan(Duration.zero),
        reason: sound.id,
      );
    }
    expect(await controller.send('load', {
      'tracks': [
        {'id': 'rain', 'volume': 65},
        {'id': 'forest', 'volume': 25},
        {'id': 'brown', 'volume': 20},
      ],
      'title': '原生测试',
      'autoplay': false,
    }), isTrue);
    expect(controller.tracks.length, 3);

    expect(await controller.send('play'), isTrue);
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(controller.playing, isTrue);
    expect(controller.error, isNull);

    expect(
      await controller.send('timer', {'seconds': 2, 'fadeSeconds': 1}),
      isTrue,
    );
    await Future<void>.delayed(const Duration(seconds: 4));
    expect(controller.timerStatus, 'expired');
    expect(controller.playing, isFalse);

    expect(controller.saveFavorite('原生测试'), isTrue);
    expect(controller.favorites.length, 1);
    expect(controller.deleteFavorite(controller.favorites.first['id'] as String), isTrue);
    controller.setTheme('dark');
    expect(controller.readValue('theme'), 'dark');
    controller.setTheme('system');

    await PomodoroPlatform.init();
    await PomodoroPlatform.chime('bell', 40);
    await Future<void>.delayed(const Duration(milliseconds: 600));

    // Leave the developer machine with the normal first-run draft, not test data.
    await controller.send('load', {
      'tracks': [
        {'id': 'rain', 'volume': 65},
        {'id': 'forest', 'volume': 25},
        {'id': 'brown', 'volume': 20},
      ],
      'title': '窗边一页',
      'autoplay': false,
    });
    controller.setTheme('system');
    controller.dispose();
  });
}
