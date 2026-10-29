import 'package:flutter/material.dart';

/// 全站统一的动效节奏：短促、柔和、有落点。
class NookMotion {
  const NookMotion._();

  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 420);
  static const page = Duration(milliseconds: 340);

  static const enterCurve = Cubic(0.16, 1, 0.3, 1);
  static const standard = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;

  static Duration scale(BuildContext context, Duration value) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : value;
}

/// 给任意可点区域加一点按压与悬停的物理感，不接管点击语义。
class Tactile extends StatefulWidget {
  final Widget child;
  final double pressedScale;
  final double hoverScale;
  final bool hoverLift;
  final bool enabled;

  const Tactile({
    super.key,
    required this.child,
    this.pressedScale = .975,
    this.hoverScale = 1.006,
    this.hoverLift = false,
    this.enabled = true,
  });

  @override
  State<Tactile> createState() => _TactileState();
}

class _TactileState extends State<Tactile> {
  bool _pressed = false;
  bool _hovered = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _setHovered(bool value) {
    if (!widget.enabled || _hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final scale = !widget.enabled
        ? 1.0
        : _pressed
        ? widget.pressedScale
        : _hovered
        ? widget.hoverScale
        : 1.0;
    final duration = reduce
        ? Duration.zero
        : _pressed
        ? NookMotion.fast
        : NookMotion.base;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) {
          _setHovered(false);
          _setPressed(false);
        },
        child: AnimatedScale(
          scale: scale,
          duration: duration,
          curve: NookMotion.enterCurve,
          child: widget.hoverLift && !reduce
              ? AnimatedContainer(
                  duration: NookMotion.base,
                  curve: NookMotion.standard,
                  transform: Matrix4.translationValues(0, _hovered && !_pressed ? -2 : 0, 0),
                  child: widget.child,
                )
              : widget.child,
        ),
      ),
    );
  }
}

/// 页面级切换：淡入 + 轻微位移，并保持两个页面的布局不跳动。
class PageSwap extends StatelessWidget {
  final Object pageKey;
  final Widget child;
  final int direction;
  final bool reduceMotion;

  const PageSwap({
    super.key,
    required this.pageKey,
    required this.child,
    required this.direction,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) return child;
    return AnimatedSwitcher(
      duration: NookMotion.page,
      reverseDuration: const Duration(milliseconds: 220),
      switchInCurve: NookMotion.enterCurve,
      switchOutCurve: NookMotion.exit,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(pageKey);
        final offset = incoming ? 0.035 * direction : -0.012 * direction;
        final curved = CurvedAnimation(
          parent: animation,
          curve: NookMotion.enterCurve,
          reverseCurve: NookMotion.exit,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(offset, .012),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey(pageKey), child: child),
    );
  }
}

/// 给路由跳转（呼吸引导等）统一的进入方式。
class NookPageTransitionsBuilder extends PageTransitionsBuilder {
  const NookPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: NookMotion.enterCurve,
      reverseCurve: NookMotion.exit,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .035),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// 入场时的一次性浮现，用于卡片与列表，避免整页同时弹跳。
class RiseIn extends StatefulWidget {
  final Widget child;
  final int index;
  final bool enabled;
  final double distance;

  const RiseIn({
    super.key,
    required this.child,
    this.index = 0,
    this.enabled = true,
    this.distance = 12,
  });

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NookMotion.slow,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: NookMotion.enterCurve,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) {
      _controller.value = 1;
    } else {
      final delay = Duration(milliseconds: 28 * widget.index.clamp(0, 8));
      Future<void>.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, widget.distance * (1 - _curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
