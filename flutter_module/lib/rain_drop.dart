
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter_module/drop_splash.dart';
import 'package:flutter_module/fake_area.dart';
import 'package:flutter_module/rain_particle.dart';
import 'package:flutter_module/rain_splash.dart';
import 'package:flutter/material.dart';

class RainDrop extends PositionComponent
    with HasGameReference<RainEffect>, CollisionCallbacks {
  late Vector2 velocity;
  late ShapeHitbox hitbox;
  final _defaultColor = Colors.blueAccent.shade100;
  final gravity = 9.8;

  RainDrop(Vector2 position)
      : super(
          position: position,
          size: Vector2.all(5),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    final defaultPaint = Paint()
      ..color = _defaultColor
      ..style = PaintingStyle.fill;

    hitbox = CircleHitbox()
      ..paint = defaultPaint
      ..renderShape = true;

    add(hitbox);

    final center = game.size / 2;
    velocity = (center - position);
  }

  @override
  void update(double dt) {
    super.update(dt);
    velocity.y += gravity;
    position.y += velocity.y * dt;
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is ScreenHitbox) {
      final collisionPoint = intersectionPoints.first;
      if (collisionPoint.x == 0) {
        velocity.x = -velocity.x;
        velocity.y = velocity.y;
      }

      if (collisionPoint.x.floor() == game.size.x.floor()) {
        removeFromParent();
        return;
      }

      if (collisionPoint.y == 0) {
        removeFromParent();
        return;
      }

      if (collisionPoint.y.floor() == game.size.y.floor()) {
        removeFromParent();
        game.add(DropSplash(collisionPoint));

        return;
      }
    } else if (other is FakeArea) {
      removeFromParent();
      final collisionPoint = intersectionPoints.first;
      game.add(RainSplash(collisionPoint));
      return;
    }
  }
}
