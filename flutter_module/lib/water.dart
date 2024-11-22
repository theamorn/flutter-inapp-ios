import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:ui' as ui;

class Water extends Game {
  late final devicePixelRatio = MediaQuery.of(buildContext!).devicePixelRatio;

  late final FragmentProgram _program;
  late final FragmentShader shader;

  double time = 0;

  double seaHeight = 0.2;

  void dispose() {
    shader.dispose();
  }

  @override
  Future<void>? onLoad() async {
    _program = await FragmentProgram.fromAsset('shaders/water.glsl');
    shader = _program.fragmentShader();
  }

  @override
  void render(ui.Canvas canvas) {
    shader
      ..setFloat(0, size.x)
      ..setFloat(1, size.y)
      ..setFloat(2, time)
      ..setFloat(3, seaHeight.clamp(0, 1));

    canvas
      ..translate(size.x, size.y)
      ..rotate(180 * degrees2Radians)
      ..drawRect(
        Offset.zero & size.toSize(),
        Paint()..shader = shader,
      );
  }

  @override
  void update(double dt) {
    time += dt;
  }
}
