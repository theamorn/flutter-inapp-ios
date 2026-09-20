import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

/// Solid ground strip. Keeps a hitbox for the cat; no scrolling photo.
class Ground extends PositionComponent {
  Ground() : super(priority: 20);

  final Paint _dirtPaint = Paint()..color = const Color(0xFF5A3A1E);
  final Paint _grassPaint = Paint()..color = const Color(0xFF3D8C3A);

  late final RectangleHitbox _hitbox;

  double get top => position.y;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _hitbox = RectangleHitbox(collisionType: CollisionType.passive);
    await add(_hitbox);
  }

  void layoutFor(Vector2 gameSize) {
    final height = (gameSize.y * 0.16).clamp(92, 132).toDouble();
    position.setValues(0, gameSize.y - height);
    size.setValues(gameSize.x, height);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _dirtPaint);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, 16), _grassPaint);
  }
}
