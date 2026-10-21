import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

/// A rounded glass surface that refracts a live snapshot of [child].
///
/// [overlay] is deliberately painted after the sampler. This keeps controls
/// crisp and, importantly, keeps the glass out of its own sampled subtree.
class LiquidGlass extends StatefulWidget {
  const LiquidGlass({
    required this.overlay,
    required this.dayNight,
    required this.refractionStrength,
    required this.thickness,
    required this.child,
    this.borderRadius = 30,
    super.key,
  });

  final Widget child;
  final Widget overlay;
  final double dayNight;
  final double refractionStrength;
  final double thickness;
  final double borderRadius;

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass>
    with SingleTickerProviderStateMixin {
  static const _shaderAsset = 'shaders/liquid_glass.glsl';

  late final AnimationController _frameClock;
  final Stopwatch _elapsed = Stopwatch();
  final Paint _shaderPaint = Paint();

  Offset _touchPosition = const Offset(-10000, -10000);
  Offset? _lastPulsePosition;
  double _rippleStartedAt = -100;
  double _lastPulseAt = -100;

  double get _elapsedSeconds => _elapsed.elapsedMicroseconds / 1000000;

  @override
  void initState() {
    super.initState();
    _elapsed.start();
    _frameClock = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _frameClock.dispose();
    _elapsed.stop();
    super.dispose();
  }

  void _startRipple(PointerEvent event, {required bool force}) {
    final now = _elapsedSeconds;
    final movedFarEnough =
        _lastPulsePosition == null ||
        (event.localPosition - _lastPulsePosition!).distance >= 22;
    final enoughTimePassed = now - _lastPulseAt >= 0.16;
    if (!force && (!movedFarEnough || !enoughTimePassed)) {
      return;
    }

    _touchPosition = event.localPosition;
    _lastPulsePosition = event.localPosition;
    _rippleStartedAt = now;
    _lastPulseAt = now;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final shadowColor = Color.lerp(
      const Color(0x420E4972),
      const Color(0xA8000618),
      widget.dayNight,
    )!;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 34,
            spreadRadius: -8,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.13),
            blurRadius: 2,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => _startRipple(event, force: true),
          onPointerMove: (event) => _startRipple(event, force: false),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ShaderBuilder(
                (context, shader, sampledChild) {
                  return AnimatedBuilder(
                    animation: _frameClock,
                    child: sampledChild,
                    builder: (context, child) {
                      final elapsed = _elapsedSeconds;
                      return AnimatedSampler((image, size, canvas) {
                        shader
                          ..setFloat(0, size.width)
                          ..setFloat(1, size.height)
                          ..setFloat(2, elapsed)
                          ..setFloat(3, _touchPosition.dx)
                          ..setFloat(4, _touchPosition.dy)
                          ..setFloat(5, _rippleStartedAt)
                          ..setFloat(6, widget.refractionStrength)
                          ..setFloat(7, widget.thickness)
                          ..setFloat(8, widget.dayNight)
                          ..setImageSampler(0, image);
                        _shaderPaint.shader = shader;
                        canvas.drawRect(Offset.zero & size, _shaderPaint);
                      }, child: child!);
                    },
                  );
                },
                assetKey: _shaderAsset,
                child: widget.child,
              ),
              widget.overlay,
            ],
          ),
        ),
      ),
    );
  }
}
