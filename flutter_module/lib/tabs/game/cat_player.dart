import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'ground.dart';
import 'pipe_pair.dart';

/// The player's animated cat, including its lightweight flight physics.
class CatPlayer extends SpriteAnimationComponent with CollisionCallbacks {
  CatPlayer({required SpriteAnimation animation, required this.onHit})
    : super(
        animation: animation,
        size: Vector2.all(58),
        anchor: Anchor.center,
        priority: 30,
      );

  final void Function() onHit;

  static const double _gravity = 1080;
  static const double _flapImpulse = -390;
  static const double _maximumFallSpeed = 680;

  late final RectangleHitbox _hitbox;
  double _verticalVelocity = 0;
  double _physicsScale = 1;
  bool _physicsEnabled = false;
  bool _acceptsCollisions = true;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _hitbox = RectangleHitbox(
      position: Vector2(13, 9),
      size: Vector2(32, 40),
      collisionType: CollisionType.active,
    );
    await add(_hitbox);
  }

  void reset(Vector2 gameSize) {
    position.setValues(gameSize.x * 0.27, gameSize.y * 0.42);
    angle = 0;
    _verticalVelocity = 0;
    _physicsScale = (gameSize.y / 800).clamp(0.78, 1.18).toDouble();
    _physicsEnabled = false;
    _acceptsCollisions = true;
    _hitbox.collisionType = CollisionType.active;
    animationTicker?.reset();
  }

  void flap() {
    if (!_acceptsCollisions) {
      return;
    }
    _physicsEnabled = true;
    _verticalVelocity = _flapImpulse * _physicsScale;
  }

  void beginDeathFall() {
    _acceptsCollisions = false;
    _physicsEnabled = true;
    _hitbox.collisionType = CollisionType.inactive;
    _verticalVelocity = math.max(_verticalVelocity, -80 * _physicsScale);
  }

  void freeze() {
    _physicsEnabled = false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_physicsEnabled) {
      return;
    }

    // Avoid a single long frame tunnelling the cat through a pipe.
    final step = math.min(dt, 1 / 30);
    _verticalVelocity = math.min(
      _verticalVelocity + _gravity * _physicsScale * step,
      _maximumFallSpeed * _physicsScale,
    );
    position.y += _verticalVelocity * step;

    final targetAngle = (_verticalVelocity / (520 * _physicsScale))
        .clamp(-0.48, 1.08)
        .toDouble();
    angle += (targetAngle - angle) * math.min(1, step * 9);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (_acceptsCollisions && (other is PipeSegment || other is Ground)) {
      onHit();
    }
  }
}
