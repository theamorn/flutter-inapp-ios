import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

import 'flappy_cat_game.dart';

/// Stable route entry point for the native host's `/game` engine.
class FlappyCatApp extends StatefulWidget {
  const FlappyCatApp({super.key});

  @override
  State<FlappyCatApp> createState() => _FlappyCatAppState();
}

class _FlappyCatAppState extends State<FlappyCatApp>
    with SingleTickerProviderStateMixin {
  late final FlappyCatGame _game;
  late final AnimationController _skyClock;

  @override
  void initState() {
    super.initState();
    _game = FlappyCatGame();
    _skyClock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _skyClock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              GameWidget<FlappyCatGame>(
                game: _game,
                backgroundBuilder: (_) => _SkyShader(clock: _skyClock),
                loadingBuilder: (_) => const ColoredBox(
                  color: Color(0xFF73C9F4),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              IgnorePointer(child: _DeathShader(game: _game)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkyShader extends StatelessWidget {
  const _SkyShader({required this.clock});

  final Animation<double> clock;

  @override
  Widget build(BuildContext context) {
    return ShaderBuilder(
      (context, shader, child) => AnimatedBuilder(
        animation: clock,
        builder: (context, child) => CustomPaint(
          painter: _SkyPainter(shader, clock.value * 60),
          child: const SizedBox.expand(),
        ),
      ),
      assetKey: 'shaders/sky.glsl',
      child: const ColoredBox(color: Color(0xFF73C9F4)),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.shader, this.elapsed);

  final ui.FragmentShader shader;
  final double elapsed;
  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, elapsed);
    _paint.shader = shader;

    // Fragment coordinates are bottom-up; rotate the existing shader so its
    // lighter horizon sits next to the ground.
    canvas
      ..save()
      ..translate(size.width, size.height)
      ..rotate(math.pi)
      ..drawRect(Offset.zero & size, _paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) => oldDelegate.elapsed != elapsed;
}

class _DeathShader extends StatelessWidget {
  const _DeathShader({required this.game});

  final FlappyCatGame game;

  @override
  Widget build(BuildContext context) {
    // Keep the registered program warm from launch so dying never creates a
    // shader-compilation hitch. The layer only repaints during the 620ms burn.
    return ShaderBuilder(
      (context, shader, child) => ValueListenableBuilder<double>(
        valueListenable: game.deathEffect,
        builder: (context, amount, child) => CustomPaint(
          painter: _DeathPainter(shader, amount),
          child: const SizedBox.expand(),
        ),
      ),
      assetKey: 'shaders/flame.glsl',
      child: const SizedBox.expand(),
    );
  }
}

class _DeathPainter extends CustomPainter {
  _DeathPainter(this.shader, this.amount);

  final ui.FragmentShader shader;
  final double amount;
  final Paint _shaderPaint = Paint();
  final Paint _flashPaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    if (amount <= 0) {
      return;
    }
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, amount * 2.4);

    final dissolveOpacity = math.sin(amount * math.pi).clamp(0, 1).toDouble();
    _shaderPaint
      ..shader = shader
      ..colorFilter = ColorFilter.mode(
        Colors.white.withValues(alpha: dissolveOpacity),
        BlendMode.modulate,
      );
    _flashPaint.color = Colors.black.withValues(alpha: amount * 0.16);
    canvas
      ..drawRect(Offset.zero & size, _flashPaint)
      ..drawRect(Offset.zero & size, _shaderPaint);
  }

  @override
  bool shouldRepaint(_DeathPainter oldDelegate) => oldDelegate.amount != amount;
}
