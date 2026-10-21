import 'dart:math';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flame/components.dart';
import 'package:flutter_module/fake_area.dart';
import 'package:flutter_module/rain_drop.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';

import 'dynamic_island_button.dart';

class RainEffect extends FlameGame
    with HasCollisionDetection, TapCallbacks {
  late SpriteSheet rainSprite;
  var isRaining = true;
  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    rainSprite = SpriteSheet(
      image: await images.load('rain_effect.png'),
      srcSize: Vector2(1024.0, 60.0),
    );

    add(ScreenHitbox());
    add(DynamicIslandButton()
      ..position = Vector2(size.x / 2, size.y / 2 + 80)
      ..size = Vector2(size.x - 160, 40)
      ..anchor = Anchor.center);

    add(FakeArea(size / 2, Vector2(size.x - 160, 100)));
  }

  @override
  Future<void> onTapDown(TapDownEvent event) async {
    while (isRaining) {
      final randomX = Random();
      final xPos = randomX.nextDouble() * size.x;
      final position = Vector2(xPos, 0);
      add(RainDrop(position));
      await Future.delayed(const Duration(milliseconds: 200));
    }
    super.onTapDown(event);
  }
}
