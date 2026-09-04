import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

/// A repeating crop of the existing street image that acts as parallax ground.
class Ground extends PositionComponent {
  Ground({required Image image})
    : _street = Sprite(
        image,
        srcPosition: Vector2(0, image.height * 0.58),
        srcSize: Vector2(image.width.toDouble(), image.height * 0.42),
      ),
      super(priority: 20);

  final Sprite _street;
  final Vector2 _tilePosition = Vector2.zero();
  final Vector2 _tileSize = Vector2.zero();

  late final RectangleHitbox _hitbox;
  double _scrollOffset = 0;
  double scrollSpeed = 84;
  bool scrolling = true;

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

    final sourceAspect = _street.srcSize.x / _street.srcSize.y;
    _tileSize.setValues(height * sourceAspect, height);
    if (_tileSize.x > 0) {
      _scrollOffset %= _tileSize.x;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (scrolling && _tileSize.x > 0) {
      _scrollOffset = (_scrollOffset + scrollSpeed * dt) % _tileSize.x;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    var x = -_scrollOffset;
    while (x < size.x) {
      _tilePosition.setValues(x, 0);
      _street.render(canvas, position: _tilePosition, size: _tileSize);
      x += _tileSize.x;
    }
  }
}
