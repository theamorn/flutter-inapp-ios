import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flame/components.dart';
import 'package:flutter_module/rain_drop.dart';
import 'package:flutter_module/rain_particle.dart';

class RainSplash extends FlameGame {
  final Vector2 location;

  RainSplash(this.location) : super();
  @override
  Future<void> onLoad() async {
    final spriteSheet = SpriteSheet(
      image: await images.load('splash_ground.png'),
      srcSize: Vector2(140.0, 140.0),
    );
    final spriteSize = Vector2(140.0, 140.0);

    final animation =
        spriteSheet.createAnimation(row: 0, stepTime: 0.05, to: 16);
    final component1 = SpriteAnimationComponent(
        scale: Vector2(0.2, 0.2),
        animation: animation,
        position: location - Vector2(16, 25),
        size: spriteSize,
        removeOnFinish: true);

    add(component1);

    Future.delayed(const Duration(milliseconds: 800))
        .then((value) => removeFromParent());
  }
}
