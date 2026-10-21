import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

import 'flappy_cat_game.dart';

/// Stable route entry point for the native host's `/game` engine.
class FlappyCatApp extends StatefulWidget {
  const FlappyCatApp({super.key});

  @override
  State<FlappyCatApp> createState() => _FlappyCatAppState();
}

class _FlappyCatAppState extends State<FlappyCatApp> {
  static const _gameChannel = MethodChannel('com.theamorn.hybrid/game');
  late final FlappyCatGame _game;

  @override
  void initState() {
    super.initState();
    _game = FlappyCatGame(onScoreChanged: _reportScore);
  }

  void _reportScore(int score) {
    try {
      _gameChannel.invokeMethod<void>('reportScore', {'score': score});
    } on MissingPluginException {
      // Expected when running standalone without host.
    } on PlatformException {
      // Catch platform exceptions safely.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Native dispatch already selected this app. Build a single home route.
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(builder: _buildHome),
      ],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      onGenerateRoute: (settings) =>
          MaterialPageRoute<void>(settings: settings, builder: _buildHome),
    );
  }

  Widget _buildHome(BuildContext context) {
    _game.topInset = MediaQuery.paddingOf(context).top;
    return _buildBody();
  }

  Widget _buildBody() {
    return Scaffold(
      backgroundColor: const Color(0xFF73C9F4),
      body: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            GameWidget<FlappyCatGame>(
              game: _game,
              loadingBuilder: (_) => const ColoredBox(
                color: Color(0xFF73C9F4),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            IgnorePointer(child: _DeathShader(game: _game)),
          ],
        ),
      ),
    );
  }
}

class _DeathShader extends StatelessWidget {
  const _DeathShader({required this.game});

  final FlappyCatGame game;

  @override
  Widget build(BuildContext context) {
    // Keep the registered program warm from launch so dying never creates a
    // shader-compilation hitch. The overlay is empty until the 620ms burn.
    return ShaderBuilder(
      (context, shader, child) => ValueListenableBuilder<double>(
        valueListenable: game.deathEffect,
        builder: (context, amount, child) {
          if (amount <= 0) {
            return const SizedBox.shrink();
          }
          return CustomPaint(
            painter: _DeathPainter(shader, amount),
            child: const SizedBox.expand(),
          );
        },
      ),
      assetKey: 'shaders/flame.glsl',
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
