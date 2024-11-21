import 'dart:async';
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

class _ShaderScreenState extends State<ShaderScreen> {
  late Timer timer;
  double delta = 0;
  ui.Image? image;
  double height = 1.0;

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      setState(() {
        delta += 1 / 60;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          height = math.Random().nextDouble();
        });
      },
      child: ShaderBuilder((context, shader, child) {
        final size = MediaQuery.sizeOf(context);
        shader.setFloat(0, size.width);
        shader.setFloat(1, size.height);
        shader.setFloat(2, delta);
        shader.setFloat(3, height);
        return CustomPaint(
          size: const Size(double.infinity, 600),
          painter: ShaderPainter(shader: shader),
        );
      },
          assetKey: 'shaders/water.glsl',
          child: const Center(
            child: CircularProgressIndicator(),
          )),
    );
  }
}
