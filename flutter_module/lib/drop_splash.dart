import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flame/components.dart';

class DropSplash extends FlameGame {
  final Vector2 position;

  DropSplash(this.position) : super();

  @override
  Future<void> onLoad() async {
    final spriteSheet = SpriteSheet(
      image: await images.load('drop_splash.png'),
      srcSize: Vector2(90.0, 90.0),
    );
    final spriteSize = Vector2(90.0, 90.0);

    final animation =
        spriteSheet.createAnimation(row: 0, stepTime: 0.1, to: 12);
    final component1 = SpriteAnimationComponent(
        scale: Vector2(0.5, 0.5),
        animation: animation,
        position: position - Vector2(20, 40),
        size: spriteSize,
        removeOnFinish: true);

    add(component1);

    Future.delayed(const Duration(milliseconds: 1000))
        .then((value) => removeFromParent());
  }
}
