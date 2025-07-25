import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

class ShaderPainter extends CustomPainter {
  ShaderPainter({required this.shader});
  ui.FragmentShader shader;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..translate(size.width, size.height)
      ..rotate(180 * math.pi / 180.0)
      ..drawRect(
        Offset.zero & size,
        Paint()..shader = shader,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate != this;
  }
}

class ShaderScreen extends StatefulWidget {
  const ShaderScreen({super.key});

  @override
  State<ShaderScreen> createState() => _ShaderScreenState();
}

class _ShaderScreenState extends State<ShaderScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  ui.Image? image;
  double height = 1.0;
  bool showOnlyWater = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(seconds: 60), // Longer duration for continuous animation
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shader Effects'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                showOnlyWater = !showOnlyWater;
              });
            },
            icon: Icon(
              showOnlyWater ? Icons.water : Icons.layers,
              color: showOnlyWater ? Colors.blue : null,
            ),
            tooltip: showOnlyWater ? 'Show Both Shaders' : 'Show Only Water',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final double delta = _animationController.value * 60; // Convert to time-like value
          
          return showOnlyWater
              ? Center(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          height = math.Random().nextDouble();
                        });
                      },
                      child: ShaderBuilder((context, shader, child) {
                        final size = MediaQuery.sizeOf(context);
                        shader.setFloat(0, size.width);
                        shader.setFloat(1, MediaQuery.of(context).size.height * 0.5);
                        shader.setFloat(2, delta);
                        shader.setFloat(3, height);
                        return CustomPaint(
                          size: Size.infinite,
                          painter: ShaderPainter(shader: shader),
                        );
                      },
                          assetKey: 'shaders/water.glsl',
                          child: const Center(
                            child: CircularProgressIndicator(),
                          )),
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Top half - Sky Shader
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            height = math.Random().nextDouble();
                          });
                        },
                        child: ShaderBuilder((context, shader, child) {
                          final size = MediaQuery.sizeOf(context);
                          shader.setFloat(0, size.width);
                          shader.setFloat(1, size.height / 2);
                          shader.setFloat(2, delta);
                          return CustomPaint(
                            size: Size.infinite,
                            painter: ShaderPainter(shader: shader),
                          );
                        },
                            assetKey: 'shaders/sky.glsl',
                            child: const Center(
                              child: CircularProgressIndicator(),
                            )),
                      ),
                    ),
                    // Bottom half - Water Shader
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            height = math.Random().nextDouble();
                          });
                        },
                        child: ShaderBuilder((context, shader, child) {
                          final size = MediaQuery.sizeOf(context);
                          shader.setFloat(0, size.width);
                          shader.setFloat(1, size.height / 2);
                          shader.setFloat(2, delta);
                          shader.setFloat(3, height);
                          return CustomPaint(
                            size: Size.infinite,
                            painter: ShaderPainter(shader: shader),
                          );
                        },
                            assetKey: 'shaders/water.glsl',
                            child: const Center(
                              child: CircularProgressIndicator(),
                            )),
                      ),
                    ),
                  ],
                );
        },
      ),
    );
  }
}
