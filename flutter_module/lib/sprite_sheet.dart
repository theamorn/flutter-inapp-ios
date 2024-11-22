import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/sprite.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

class SpriteSheetWidget extends FlameGame with TapDetector {
  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    final spriteSheet = SpriteSheet(
      image: await images.load('cat_sprite_long.png'),
      srcSize: Vector2(50.0, 50.0),
    );
    final spriteSize = Vector2(50.0, 50.0);

    final animation =
        spriteSheet.createAnimation(row: 0, stepTime: 0.1, to: 60);
    final component1 = SpriteAnimationComponent(
      animation: animation,
      scale: Vector2(1.5, 1.5),
      position: Vector2(160, -5),
      // scale: Vector2(10.0, 10.0),
      // position: Vector2(-200, 0),
      size: spriteSize,
    );

    add(
      component1
        ..add(
          MoveEffect.to(
            Vector2(250, -5),
            EffectController(
              duration: 10,
              reverseDuration: 10,
              infinite: true,
              curve: Curves.linear,
            ),
          ),
        ),
    );
  }
}
