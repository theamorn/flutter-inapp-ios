import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_module/action_button.dart';
import 'package:flutter_module/rain_particle.dart';
import 'package:flutter_module/sprite_sheet.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'dart:ui' as ui;

class RainDropletPainter extends CustomPainter {
  RainDropletPainter({required this.shader});
  ui.FragmentShader shader;

  @override
  void paint(Canvas canvas, Size size) {
    // Use a paint with blend mode for transparency
    final paint = Paint()
      ..shader = shader
      ..blendMode = BlendMode.srcOver;

    canvas.drawRect(
      Offset.zero & size,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Always repaint for animation
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late RainEffect game;
  late AnimationController rainAnimationController;
  double dropletCount = 0;
  bool isRainActive = false;
  late DateTime startTime;

  @override
  void initState() {
    super.initState();
    game = RainEffect();
    startTime = DateTime.now();

    // Animation controller for rain shader
    rainAnimationController = AnimationController(
      duration: const Duration(seconds: 1), // Short duration, will repeat
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    rainAnimationController.dispose();
    super.dispose();
  }

  void _startRainEffect() {
    setState(() {
      isRainActive = true;
      dropletCount = 10.0; // Immediate full rain effect
    });

    // Simply toggle the rain state in the game
    game.isRaining = true;
  }

  void _stopRainEffect() {
    setState(() {
      isRainActive = false;
      dropletCount = 0; // Immediate stop
    });

    game.isRaining = false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: const Text("Flame with game"),
          ),
          body: Column(
            children: [
              Expanded(
                  child: GameWidget<RainEffect>(game: game, overlayBuilderMap: {
                'userArea': (ctx, game) {
                  return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 80),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextField(
                                decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white,
                                    hintText: 'Username')),
                            TextField(
                                decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white,
                                    hintText: 'Password'))
                          ]));
                },
                'container1': (ctx, game) {
                  return ActionButtonWidget(
                      Colors.blueAccent, "Sign in", Alignment.bottomCenter, () {
                    print(
                        "=== This is Flutter widget inside Flutter Flame ===");
                  });
                },
              }, initialActiveOverlays: const [
                'userArea',
                'container1'
              ])),
            ],
          ),
        ),
        SizedBox(
            width: 100,
            height: 100,
            child: Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Align(
                  alignment: Alignment.topCenter,
                  child: GameWidget(game: SpriteSheetWidget())),
            )),
        // Rain Droplet Shader Overlay - Only re-renders this part
        if (dropletCount > 0 || isRainActive)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: rainAnimationController,
                builder: (context, child) {
                  // Calculate elapsed time for shader animation
                  final elapsedTime =
                      DateTime.now().difference(startTime).inMilliseconds /
                          1000.0;

                  return ShaderBuilder(
                    (context, shader, child) {
                      final size = MediaQuery.sizeOf(context);
                      shader.setFloat(0, size.width);
                      shader.setFloat(1, size.height);
                      shader.setFloat(2,
                          elapsedTime); // Use elapsed time for continuous animation
                      shader.setFloat(3, dropletCount);
                      return CustomPaint(
                        size: Size.infinite,
                        painter: RainDropletPainter(shader: shader),
                      );
                    },
                    assetKey: 'shaders/rain_droplets.glsl',
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
          ),
        // Sprite Sheet Animation - Above the rain overlay for visibility

        // Rain Control Buttons
        Positioned(
          top: 100,
          right: 20,
          child: Column(
            children: [
              ElevatedButton(
                onPressed: _startRainEffect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Start Rain'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _stopRainEffect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Stop Rain'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
