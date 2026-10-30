import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tingyu_web/main.dart';

Future<void> _loadFonts() async {
  final loader = FontLoader('NookFull')
    ..addFont(rootBundle.load('assets/fonts/nook.ttf'));
  await loader.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required bool dark,
  required String golden,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await _loadFonts();
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        brightness: dark ? Brightness.dark : Brightness.light,
        fontFamily: 'NookFull',
      ),
      home: const BreathingPage(reducedMotion: true),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  await expectLater(find.byType(BreathingPage), matchesGoldenFile(golden));
}

void main() {
  testWidgets('breathing phone light', (tester) async {
    await _pump(
      tester,
      size: const Size(393, 852),
      dark: false,
      golden: 'goldens/breathing-phone.png',
    );
  });
  testWidgets('breathing phone dark', (tester) async {
    await _pump(
      tester,
      size: const Size(393, 852),
      dark: true,
      golden: 'goldens/breathing-phone-dark.png',
    );
  });
  testWidgets('breathing small phone', (tester) async {
    await _pump(
      tester,
      size: const Size(320, 568),
      dark: false,
      golden: 'goldens/breathing-small.png',
    );
  });
}
