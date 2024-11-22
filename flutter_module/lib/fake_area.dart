import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_module/rain_particle.dart';

class FakeArea extends PositionComponent with HasGameRef<RainEffect> {
  late ShapeHitbox hitbox;
  final _defaultColor = Colors.red;
  late Vector2 velocity;

  FakeArea(Vector2 position, Vector2 size)
      : super(position: position, size: size, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    final defaultPaint = Paint()
      ..color = _defaultColor
      ..style = PaintingStyle.stroke;

    hitbox = RectangleHitbox()
      ..paint = defaultPaint
      ..isSolid = true
      ..renderShape = true;

    add(hitbox);
  }
}
