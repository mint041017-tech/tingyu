import 'package:flutter/material.dart';

/// 听隅的品牌标记：一枚叶片，三条叶脉化作声波。
/// 全部使用 1024 坐标系绘制，随尺寸无损缩放，不依赖图片资源。
class NookLogo extends StatelessWidget {
  final double size;
  final Color? background;
  final Color? foreground;
  final bool flat;
  final String? semanticLabel;

  const NookLogo({
    super.key,
    this.size = 40,
    this.background,
    this.foreground,
    this.flat = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = background ?? scheme.primary;
    final fg = foreground ?? scheme.onPrimary;
    return Semantics(
      label: semanticLabel ?? '听隅',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _NookMarkPainter(background: bg, foreground: fg, flat: flat),
        ),
      ),
    );
  }
}

class _NookMarkPainter extends CustomPainter {
  final Color background;
  final Color foreground;
  final bool flat;

  const _NookMarkPainter({
    required this.background,
    required this.foreground,
    required this.flat,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 1024;
    canvas.save();
    canvas.scale(s);

    final squircle = Path()
      ..moveTo(512, 24)
      ..cubicTo(846, 24, 1000, 178, 1000, 512)
      ..cubicTo(1000, 846, 846, 1000, 512, 1000)
      ..cubicTo(178, 1000, 24, 846, 24, 512)
      ..cubicTo(24, 178, 178, 24, 512, 24)
      ..close();

    final paint = Paint()..isAntiAlias = true;
    if (!flat) {
      paint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(background, Colors.white, .14)!,
          background,
          Color.lerp(background, Colors.black, .14)!,
        ],
        stops: const [0, .55, 1],
      ).createShader(const Rect.fromLTWH(0, 0, 1024, 1024));
    } else {
      paint.color = background;
    }
    canvas.drawPath(squircle, paint);

    canvas.drawPath(
      squircle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = foreground.withValues(alpha: .10),
    );

    final leaf = Path()
      ..moveTo(512, 184)
      ..cubicTo(666, 280, 732, 424, 688, 574)
      ..cubicTo(658, 678, 576, 752, 512, 792)
      ..cubicTo(448, 752, 366, 678, 336, 574)
      ..cubicTo(292, 424, 358, 280, 512, 184)
      ..close();
    canvas.drawPath(leaf, Paint()..color = foreground);

    final vein = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = background.withValues(alpha: .30);
    canvas.drawLine(
      const Offset(512, 268),
      const Offset(512, 720),
      vein
        ..strokeWidth = 18
        ..color = background.withValues(alpha: .26),
    );

    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 30
      ..color = background.withValues(alpha: .90);

    canvas.drawPath(
      Path()
        ..moveTo(420, 456)
        ..cubicTo(474, 422, 554, 418, 614, 446),
      wave,
    );
    canvas.drawPath(
      Path()
        ..moveTo(404, 558)
        ..cubicTo(466, 522, 550, 520, 616, 550),
      wave,
    );
    canvas.drawPath(
      Path()
        ..moveTo(424, 658)
        ..cubicTo(472, 630, 540, 628, 596, 654),
      wave,
    );

    if (!flat) {
      canvas.drawCircle(
        const Offset(512, 248),
        14,
        Paint()..color = background.withValues(alpha: .30),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NookMarkPainter oldDelegate) =>
      oldDelegate.background != background ||
      oldDelegate.foreground != foreground ||
      oldDelegate.flat != flat;
}

/// 原生端启动动画：原生 LaunchScreen 之后、首屏之前的一段品牌过渡。
class NativeLaunchOverlay extends StatelessWidget {
  const NativeLaunchOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    const cream = Color(0xfff4f1e8);
    const muted = Color(0xffa8b5a6);
    return ColoredBox(
      color: const Color(0xff223027),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 760),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 10 * (1 - value)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: .88 + .12 * value,
                    child: const NookLogo(
                      size: 92,
                      background: Color(0xff4f6957),
                      foreground: cream,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '听隅',
                    style: TextStyle(
                      color: cream,
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 9,
                      decoration: TextDecoration.none,
                      decorationColor: Colors.transparent,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'QUIET NOOK',
                    style: TextStyle(
                      color: muted,
                      fontSize: 10,
                      letterSpacing: 4.5,
                      decoration: TextDecoration.none,
                      decorationColor: Colors.transparent,
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: 120 * value,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: muted.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
